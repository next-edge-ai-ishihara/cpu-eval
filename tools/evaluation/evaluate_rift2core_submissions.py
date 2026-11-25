#!/usr/bin/env python3
"""Evaluate submitted Rift2Core HDL files using their assigned tests."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import signal
import shutil
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import yaml

CPU_RELATIVE = "cpus/rift2core"

TOOL_ENVIRONMENT = {
    "REPO": "rift2core_repo",
    "DROMAJO_DIR": "dromajo_dir",
    "VERILATOR": "verilator",
    "MILLW": "millw",
    "JAVA_HOME": "java_home",
    "FIRTOOL_DIR": "firtool_dir",
    "TEST_IMAGE_DIR": "test_image_dir",
    "ARBITER_PRISTINE": "arbiter_pristine",
    "ARBITER_SHIM_TEMPLATE": "arbiter_shim_template",
    "ARBITER_CACHE_TEMPLATE": "arbiter_cache_template",
    "PRISTINE_COURSIER_CACHE": "pristine_coursier_cache",
}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--problems", required=True, type=Path)
    parser.add_argument("--samples", required=True, type=int)
    parser.add_argument("--submissions", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--repo",
        required=True,
        type=Path,
        help="CPU-Eval repository tree the evaluators are read from",
    )
    parser.add_argument("--eval-root", required=True, type=Path, help="private EVAL_ROOT for the evaluators")
    parser.add_argument("--rift2core-repo", type=Path)
    parser.add_argument("--dromajo-dir", type=Path)
    parser.add_argument("--verilator", type=Path)
    parser.add_argument("--millw", type=Path)
    parser.add_argument("--java-home", type=Path)
    parser.add_argument("--firtool-dir", type=Path)
    parser.add_argument("--test-image-dir", type=Path)
    parser.add_argument(
        "--arbiter-pristine",
        type=Path,
        help="arbiter/harness/evaluate.sh: pinned chisel3/util/Arbiter.scala the "
        "candidate class is spliced into (Arbiter.scala.pristine)",
    )
    parser.add_argument(
        "--arbiter-shim-template",
        type=Path,
        help="arbiter/harness/evaluate.sh: throwaway mill module template the "
        "spliced Arbiter.scala is compiled in",
    )
    parser.add_argument(
        "--arbiter-cache-template",
        type=Path,
        help="arbiter/harness/evaluate.sh: pristine Coursier cache mirror holding "
        "the released chisel jar to be patched",
    )
    parser.add_argument(
        "--pristine-coursier-cache",
        type=Path,
        help="queue/harness/evaluate.sh: pristine Coursier cache mirror holding "
        "the released chisel jar to be patched (queue's own copy)",
    )
    parser.add_argument(
        "--path-prepend",
        action="append",
        default=[],
        type=Path,
        help="directories prepended to PATH, for evaluators that shell out to a "
        "cross compiler (io_lsu rebuilds its test image with make)",
    )
    parser.add_argument("--verilator-jobs", type=int, default=8)
    parser.add_argument(
        "--test-parallelism",
        type=int,
        default=8,
        help="TEST_PARALLELISM used by shared evaluators for independent programs",
    )
    parser.add_argument(
        "--test-timeout-sec",
        type=int,
        default=600,
        help="TIMEOUT_SEC, the per-program wall-clock limit; the simulator cycle limit is reached first",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=14400,
        help="wall-clock limit for one evaluator invocation, build included",
    )
    parser.add_argument("--resume", action="store_true")
    return parser.parse_args(argv)

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

def evaluator_argument_form(evaluator: Path) -> str:
    text = evaluator.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"usage: evaluate\.sh (.*)", text)
    if not match:
        raise ValueError(f"evaluator states no usage line: {evaluator}")
    usage = match.group(1)
    if "<problem-directory>" in usage:
        return "problem_directory_and_candidate"
    if "<candidate" in usage:
        return "candidate_only"
    raise ValueError(f"unrecognized evaluator usage line: {evaluator}: {usage}")


def load_contracts(cpu_directory: Path, problems: list[str]) -> dict[str, dict[str, str]]:
    contracts: dict[str, dict[str, str]] = {}
    failures: list[str] = []
    for problem in problems:
        directory = cpu_directory / problem
        definition_path = directory / "problem.yaml"
        if not definition_path.is_file():
            failures.append(f"{problem}: missing problem.yaml")
            continue
        definition = yaml.safe_load(definition_path.read_text(encoding="utf-8")) or {}
        declared = (definition.get("evaluation") or {}).get("evaluator")
        if not declared:
            failures.append(f"{problem}: problem.yaml declares no evaluation.evaluator")
            continue
        evaluator = (directory / str(declared)).resolve()
        if not evaluator.is_file():
            failures.append(f"{problem}: declared evaluator is missing: {declared}")
            continue
        try:
            form = evaluator_argument_form(evaluator)
        except ValueError as error:
            failures.append(str(error))
            continue
        contracts[problem] = {
            "problem_directory": str(directory.resolve()),
            "declared_evaluator": str(declared),
            "evaluator": str(evaluator),
            "evaluator_sha256": sha256(evaluator),
            "argument_form": form,
        }
    if failures:
        raise ValueError("Rift2Core evaluator contracts are not resolvable:\n" + "\n".join(failures))
    return contracts


def build_command(contract: dict[str, str], candidate: Path) -> list[str]:
    evaluator = contract["evaluator"]
    if contract["argument_form"] == "problem_directory_and_candidate":
        return ["bash", evaluator, contract["problem_directory"], str(candidate)]
    return ["bash", evaluator, str(candidate)]


def classify(exit_code: int, stdout: str, stderr: str, timed_out: bool) -> str:
    if timed_out or exit_code in {124, 137, 143, -9, -15}:
        return "INVALID_HARNESS_TIMEOUT"
    if exit_code == 0:
        return "PASS"
    combined = stdout + "\n" + stderr
    if exit_code == 1:
        lines = [line.removeprefix("[evaluate] ") for line in stdout.splitlines()]
        for name in ("FAIL_CANDIDATE_DEFINITION", "FAIL_CANDIDATE_COMPILE", "FAIL_ELABORATION"):
            if any(line.startswith(name + ":") for line in lines):
                return name
        if "FUNCTIONAL FAIL: program did not complete" in lines:
            return "FAIL_INCOMPLETE_EXECUTION"
        if "FUNCTIONAL FAIL: observation mismatch" in lines or "FAIL: public output observation mismatch" in lines:
            return "FAIL_OBSERVATION_MISMATCH"
        if "FUNCTIONAL FAIL: trace mismatch" in lines:
            return "FAIL_TRACE_MISMATCH"
        # A shell error such as an unbound variable also exits 1 without a verdict line.
        return "INVALID_OTHER"
    if "at least one test was interrupted" in combined or "test was interrupted" in combined:
        return "INVALID_TEST_INTERRUPTED"
    if "elaboration environment failed" in combined:
        return "INVALID_ELABORATION"
    if "Verilator build failed" in combined or "build environment failed" in combined:
        return "INVALID_VERILATOR_BUILD"
    if "no test images" in combined:
        return "INVALID_NO_TEST_IMAGES"
    if ("revision mismatch" in combined or "does not apply" in combined or "missing dependency" in combined
            or "required dependency missing" in combined or "unexpected hash" in combined
            or "hash mismatch" in combined or "fixed test inputs could not be used" in combined):
        return "INVALID_ENVIRONMENT"
    return "INVALID_OTHER"


def summarize_evaluator_logs(eval_root: Path, before: set[str], result: Path) -> dict[str, object]:
    runs = eval_root / "runs"
    if not runs.is_dir():
        return {"log_directories": [], "timeout_suspected": False}
    directories = [path for path in runs.iterdir() if path.is_dir() and path.name not in before]
    summary: list[dict[str, object]] = []
    timeout_suspected = False
    preserved_root = result / "evaluator-logs"
    for directory in sorted(directories):
        preserved = preserved_root / directory.name
        shutil.copytree(directory, preserved)
        results = directory / "results.tsv"
        if results.is_file():
            (result / "evaluator-results.tsv").write_bytes(results.read_bytes())
        logs = []
        for log in sorted(directory.glob("run_*.log")):
            size = log.stat().st_size
            last = ""
            with log.open("rb") as stream:
                stream.seek(max(0, size - 4096))
                tail = stream.read().decode("utf-8", errors="replace").strip().splitlines()
                if tail:
                    last = tail[-1]
            if "Timeout" in last or "timeout" in last or size > (32 << 20):
                timeout_suspected = True
            logs.append({"log": log.name, "bytes": size, "last_line": last[:500]})
        summary.append({
            "directory": str(directory),
            "preserved_directory": str(preserved.relative_to(result)),
            "test_logs": logs,
        })
    return {"log_directories": summary, "timeout_suspected": timeout_suspected}


def terminate_evaluator_session(session_id: int) -> None:
    while True:
        groups = set()
        for path in Path("/proc").iterdir():
            if not path.name.isdecimal():
                continue
            try:
                fields = (path / "stat").read_text().rsplit(")", 1)[1].split()
            except (FileNotFoundError, ProcessLookupError):
                continue
            if fields[0] not in ("Z", "X") and int(fields[3]) == session_id:
                groups.add(int(fields[2]))
        if not groups:
            return
        for group in groups:
            try:
                os.killpg(group, signal.SIGKILL)
            except ProcessLookupError:
                pass


def worker_environment(args: argparse.Namespace, eval_root: Path) -> dict[str, str]:
    env = {key: value for key, value in os.environ.items() if key not in {"TEST_NAME_PATTERN", "DROMAJO_RIFT_ACLINT_MAP", "STOP_AFTER_FUNCTIONAL_FAIL"}}
    env["EVAL_ROOT"] = str(eval_root.resolve())
    env["VERILATOR_JOBS"] = str(args.verilator_jobs)
    env["TIMEOUT_SEC"] = str(args.test_timeout_sec)
    env["TEST_PARALLELISM"] = str(args.test_parallelism)
    for name, attribute in TOOL_ENVIRONMENT.items():
        value = getattr(args, attribute)
        if value is not None:
            env[name] = str(Path(value).resolve())
    if args.path_prepend:
        prefix = ":".join(str(Path(path).resolve()) for path in args.path_prepend)
        env["PATH"] = f"{prefix}:{env.get('PATH', '')}"
    return env

def main() -> int:
    args = parse_args()
    if args.samples < 1:
        raise ValueError("samples must be positive")
    cpu_directory = (args.repo / CPU_RELATIVE).resolve()
    if not cpu_directory.is_dir():
        raise FileNotFoundError(cpu_directory)
    if args.output.exists() and not args.resume:
        raise FileExistsError(args.output)
    args.output.mkdir(parents=True, exist_ok=args.resume)

    rows = list(csv.DictReader(args.problems.open(encoding="utf-8"), delimiter="\t"))
    problems = [row["problem"] for row in rows]
    contracts = load_contracts(cpu_directory, problems)

    completed_keys: set[tuple[str, int]] = set()
    if args.resume:
        for directory in args.output.glob("*__sample-*"):
            if not (directory / "exit-code.txt").is_file():
                continue
            problem, sample = directory.name.rsplit("__sample-", 1)
            completed_keys.add((problem, int(sample)))

    jobs: list[tuple[str, int, Path]] = []
    for problem in problems:
        for sample in range(args.samples):
            directory = args.submissions / problem / f"sample-{sample:02d}"
            if not directory.is_dir() or (problem, sample) in completed_keys:
                continue
            candidate = directory / "submission.scala"
            if candidate.is_file():
                jobs.append((problem, sample, candidate))
            else:
                raise FileNotFoundError(f"candidate submission is missing: {candidate}")

    run_path = args.output / "run.json"
    immutable_run = {
        "schema_version": 1,
        "cpu": "Rift2Core",
        "evaluator_repository": str(args.repo.resolve()),
        "shared_evaluator_sha256": sha256(cpu_directory / "_shared/evaluate.sh"),
        "replacer_sha256": sha256(cpu_directory / "_shared/replace_class.py"),
        "evaluation_driver_sha256": sha256(Path(__file__).resolve()),
        "problems_sha256": sha256(args.problems),
        "samples_per_problem": args.samples,
        "submission_root": str(args.submissions.resolve()),
        "eval_root": str(args.eval_root.resolve()),
        "verilator_jobs": args.verilator_jobs,
        "test_timeout_sec": args.test_timeout_sec,
        "test_parallelism": args.test_parallelism,
        "invocation_timeout_sec": args.timeout,
        "evaluator_contracts": contracts,
    }
    if args.resume:
        if not run_path.is_file():
            raise FileNotFoundError("resume requires run.json")
        run = json.loads(run_path.read_text(encoding="utf-8"))
        mismatches = {
            key: (run.get(key), value)
            for key, value in immutable_run.items()
            if run.get(key) != value
        }
        if mismatches:
            raise ValueError(f"resume metadata mismatch: {sorted(mismatches)}")
        run["resumed_at"] = now()
        run.pop("finished_at", None)
    else:
        run = {"started_at": now(), **immutable_run}
    run["job_count_this_invocation"] = len(jobs)
    run["terminal_jobs_before_invocation"] = len(completed_keys)
    write_json(run_path, run)

    progress = args.output / "progress.tsv"
    if not progress.is_file():
        progress.write_text(
            "finished_at\tproblem\tsample_index\texit_code\tverdict\twall_seconds\n",
            encoding="utf-8",
        )

    eval_root = args.eval_root.resolve()
    eval_root.mkdir(parents=True, exist_ok=True)
    env = worker_environment(args, eval_root)
    produced: list[str] = []
    for problem, sample, candidate in jobs:
        result = args.output / f"{problem}__sample-{sample:02d}"
        result.mkdir(exist_ok=True)
        command = build_command(contracts[problem], candidate)
        runs_directory = eval_root / "runs"
        before = {
            path.name for path in runs_directory.iterdir() if path.is_dir()
        } if runs_directory.is_dir() else set()
        started = datetime.now(timezone.utc)
        timed_out = False
        try:
            evaluator_process = subprocess.Popen(
                command,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                cwd=str(cpu_directory),
                start_new_session=True,
            )
            stdout, stderr = evaluator_process.communicate(timeout=args.timeout)
            exit_code = evaluator_process.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            exit_code = 124
            terminate_evaluator_session(evaluator_process.pid)
            stdout, stderr = evaluator_process.communicate()
        elapsed = (datetime.now(timezone.utc) - started).total_seconds()
        verdict = classify(exit_code, stdout, stderr, timed_out)
        logs = summarize_evaluator_logs(eval_root, before, result)
        write_json(result / "command.json", command)
        (result / "stdout.log").write_text(stdout, encoding="utf-8")
        (result / "stderr.log").write_text(stderr, encoding="utf-8")
        (result / "exit-code.txt").write_text(f"{exit_code}\n", encoding="utf-8")
        write_json(result / "verdict.json", {
            "schema_version": 1,
            "problem": problem,
            "sample_index": sample,
            "verdict": verdict,
            "exit_code": exit_code,
            "timed_out": timed_out,
            "started_at": started.isoformat(),
            "finished_at": now(),
            "wall_seconds": elapsed,
            "candidate": str(candidate.resolve()),
            "candidate_sha256": sha256(candidate),
            "evaluator": contracts[problem]["evaluator"],
            "evaluator_sha256": contracts[problem]["evaluator_sha256"],
            "argument_form": contracts[problem]["argument_form"],
            "eval_root": str(eval_root),
            **logs,
        })
        files = sorted(
            path for path in result.rglob("*")
            if path.is_file() and path.name != "files.sha256"
        )
        with (result / "files.sha256").open("w", encoding="utf-8") as stream:
            for path in files:
                stream.write(f"{sha256(path)}  {path.relative_to(result)}\n")
        with progress.open("a", encoding="utf-8") as stream:
            stream.write(
                f"{now()}\t{problem}\t{sample}\t{exit_code}\t{verdict}\t{elapsed:.3f}\n"
            )
        print(f"{problem} sample-{sample:02d} exit={exit_code} {verdict}", flush=True)
        produced.append(verdict)

    terminal: list[tuple[str, int, str, int]] = []
    for problem in problems:
        for sample in range(args.samples):
            directory = args.output / f"{problem}__sample-{sample:02d}"
            exit_file = directory / "exit-code.txt"
            verdict_file = directory / "verdict.json"
            if not exit_file.is_file():
                continue
            exit_code = int(exit_file.read_text(encoding="utf-8").strip())
            verdict = "UNRECORDED"
            if verdict_file.is_file():
                verdict = json.loads(verdict_file.read_text(encoding="utf-8"))["verdict"]
            terminal.append((problem, sample, verdict, exit_code))
    with (args.output / "verdicts.tsv").open("w", encoding="utf-8") as stream:
        stream.write("problem\tsample_index\tverdict\texit_code\n")
        for problem, sample, verdict, exit_code in terminal:
            stream.write(f"{problem}\t{sample}\t{verdict}\t{exit_code}\n")

    histogram = Counter(verdict for _, _, verdict, _ in terminal)
    run["finished_at"] = now()
    run["evaluated_jobs_this_invocation"] = len(produced)
    run["terminal_jobs"] = len(terminal)
    run["passing_jobs"] = histogram["PASS"]
    run["verdict_histogram"] = dict(sorted(histogram.items()))
    write_json(run_path, run)
    print(json.dumps({"terminal_jobs": len(terminal), "verdicts": dict(sorted(histogram.items()))},
                     indent=2), flush=True)
    invalid_definition = histogram["FAIL_CANDIDATE_DEFINITION"]
    if terminal and invalid_definition >= len(terminal) / 2:
        print(
            "WARNING: at least half of the terminal records were rejected before the "
            "candidate reached the CPU. Inspect the candidate rejection logs.",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
