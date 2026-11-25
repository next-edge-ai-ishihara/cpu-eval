#!/usr/bin/env python3
"""Evaluate submitted CVA6 HDL files using their assigned tests."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import shutil
from pathlib import Path
import signal
import subprocess


CVXIF_PROBLEMS = {
    "ariane",
    "cva6",
    "compressed_instr_decoder",
    "copro_alu",
    "instr_decoder",
    "cvxif_compressed_if_driver",
    "cvxif_example_coprocessor",
    "cvxif_fu",
    "cvxif_issue_register_commit_if_driver",
    "issue_stage",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--problems", required=True, type=Path)
    parser.add_argument("--samples", required=True, type=int)
    parser.add_argument("--submissions", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--checkout", required=True, type=Path)
    parser.add_argument("--riscv-prefix", required=True, type=Path)
    parser.add_argument("--cvxif-spike-prefix", type=Path)
    parser.add_argument("--invocation-timeout-sec", required=True, type=int)
    parser.add_argument("--resume", action="store_true")
    return parser.parse_args()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def changed_checkout_inputs(repo: Path, checkout: Path, present: set[str]) -> list[dict[str, str]]:
    manifest = json.loads((repo / "cpus/cva6/MODULES.json").read_text())
    changed = []
    for record in manifest["modules"] + manifest["temporary_input_files"]:
        relative = record["source_path"]
        path = checkout / relative
        if not path.exists():
            if relative in present:
                changed.append({"path": relative, "expected_sha256": record["source_sha256"],
                                "actual_sha256": "missing"})
            continue
        present.add(relative)
        try:
            actual = sha256(path)
        except OSError:
            actual = "unreadable"
        if actual != record["source_sha256"]:
            changed.append({"path": relative, "expected_sha256": record["source_sha256"],
                            "actual_sha256": actual})
    return changed


def run_isolated(
    command: list[str], *, timeout: int, **kwargs
) -> tuple[int, str, str, bool]:
    process = subprocess.Popen(
        command,
        start_new_session=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        **kwargs,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        return process.returncode, stdout, stderr, False
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            stdout, stderr = process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            stdout, stderr = process.communicate()
        return 124, stdout, stderr, True


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def csr_regfile_port_compile_error(runs: Path, entries: tuple[Path, ...], candidate_digest: str | None) -> bool:
    receipts = [path for path in entries if path.name == "result.json"]
    if candidate_digest is None or len(receipts) != 1:
        return False
    receipt = receipts[0]
    run = receipt.parent
    if run.parent != runs / "csr_regfile" or not run.name.startswith("wfi-ports-"):
        return False
    build = run / "build.log"
    bench = run / "testbench.sv"
    if set(entries) != {run.parent, run, receipt, build, bench}:
        return False
    recipe = Path(__file__).resolve().parents[2] / "cpus/cva6/csr_regfile/TEST_RECIPE.json"
    try:
        record = json.loads(receipt.read_text(encoding="utf-8"))
        fixture = json.loads(recipe.read_text(encoding="utf-8"))["public_port_test"]
        return (record["candidate_sha256"] == candidate_digest
                and record["candidate_compile_error"] is True
                and type(record["build_exit_code"]) is int and record["build_exit_code"] > 0
                and record["exit_code"] == 1
                and "simulation_exit_code" not in record
                and record["cpu_revision"] == fixture["source_revision"]
                and record["runner_sha256"] == fixture["runner_sha256"]
                and record["template_sha256"] == fixture["template_sha256"]
                and record["testbench_sha256"] == sha256(bench)
                and build.is_file() and build.stat().st_size > 0)
    except (OSError, ValueError, TypeError, KeyError):
        return False


def normalized_verdict(evidence: Path, problem: str, exit_code: int, timed_out: bool,
                       *, candidate_digest: str | None = None) -> str:
    if timed_out or exit_code not in (0, 1):
        return "INVALID_EVALUATION"
    if exit_code == 0:
        return "PASS"

    runs = evidence / "runs"
    entries = tuple(runs.rglob("*"))
    if runs.is_symlink() or any(path.is_symlink() for path in entries):
        return "FAIL_FUNCTIONAL_MISMATCH"
    if problem == "csr_regfile" and csr_regfile_port_compile_error(runs, entries, candidate_digest):
        return "FAIL_CANDIDATE_COMPILE"
    markers = [
        path for path in entries
        if path.name == "candidate-compile-error.txt" and path.parent.parent.name == problem
    ]
    if not markers:
        if any(path.name == "incomplete-execution.txt" and path.is_file() and path.stat().st_size > 0
               and (path.parent / "exit-code.txt").is_file()
               and (path.parent / "exit-code.txt").read_bytes().strip() == b"1" for path in entries):
            return "FAIL_INCOMPLETE_EXECUTION"
        return "FAIL_FUNCTIONAL_MISMATCH"
    # The harness copies the build log only after attributing a compiler error
    # to the integrated submission, then exits before it creates any test logs.
    required = {marker.parent / name for marker in markers
                for name in ("candidate-compile-error.txt", "build.log", "exit-code.txt")}
    files = {path for path in entries if path.is_file()}
    if problem == "compressed_instr_decoder":
        reconstruction_logs = {marker.parent / "test-reconstruction.log" for marker in markers}
        files -= {path for path in files & reconstruction_logs if path.stat().st_size == 0}
    if files != required:
        return "FAIL_FUNCTIONAL_MISMATCH"
    if all(marker.stat().st_size > 0
           and marker.read_bytes() == (marker.parent / "build.log").read_bytes()
           and (marker.parent / "exit-code.txt").read_bytes().strip() == b"1"
           for marker in markers):
        return "FAIL_CANDIDATE_COMPILE"
    return "FAIL_FUNCTIONAL_MISMATCH"


def completed_sample(result: Path, candidate: Path, problem: str, sample: int) -> bool:
    try:
        record = json.loads((result / "evaluator/verdict.json").read_text())
        candidate_digest = sha256(candidate)
        if (record.get("candidate_sha256") != candidate_digest
                or record.get("problem") != problem or record.get("sample_index") != sample):
            return False
        exit_code = int((result / "exit-code.txt").read_text().strip())
        expected = normalized_verdict(result / "evaluator", problem, exit_code, record.get("timed_out"),
                                      candidate_digest=candidate_digest)
        if record.get("evaluator_exit_code") != exit_code or record.get("verdict") != expected:
            return False
        ledger = {}
        for line in (result / "files.sha256").read_text().splitlines():
            digest, relative = line.split("  ", 1)
            if Path(relative).is_absolute() or ".." in Path(relative).parts or relative in ledger:
                return False
            ledger[relative] = digest
        actual = {str(p.relative_to(result)): p for p in result.rglob("*")
                  if p.is_file() and p != result / "files.sha256"}
        return (bool(ledger) and set(ledger) == set(actual)
                and all(not p.is_symlink() and sha256(p) == ledger[n] for n, p in actual.items()))
    except (OSError, ValueError, KeyError, TypeError):
        return False


def submission_candidate(root: Path, problem: str, sample: int) -> Path | None:
    directory = root / problem / f"sample-{sample:02d}"
    for name in ("submission.sv", "submission.v"):
        candidate = directory / name
        if candidate.is_file():
            return candidate
    return None


def problem_directory(repo: Path, problem: str) -> Path:
    with (repo / "cpus/cva6/PROBLEMS.tsv").open(encoding="utf-8", newline="") as stream:
        rows = [row for row in csv.DictReader(stream, delimiter="\t") if row["problem"] == problem]
    if len(rows) != 1:
        raise ValueError(f"expected one CVA6 problem row for {problem}, found {len(rows)}")
    return repo / "cpus/cva6" / rows[0]["directory"]


def evaluator_command(repo: Path, problem: str, candidate: Path) -> list[str]:
    directory = problem_directory(repo, problem)
    dedicated = directory / "harness/evaluate.sh"
    if dedicated.is_file():
        return [str(dedicated), str(candidate)]
    return [str(repo / "cpus/cva6/harness/evaluate_parallel.sh"), problem, str(candidate)]


def problem_test_list(repo: Path, problem: str) -> Path:
    directory = problem_directory(repo, problem)
    recipe_path = directory / "TEST_RECIPE.json"
    recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
    record = recipe.get("test_list")
    if isinstance(record, dict):
        relative = record.get("path")
        expected_sha256 = record.get("sha256")
    else:
        relative = record
        expected_sha256 = recipe.get("test_list_sha256")
    if not relative or not expected_sha256:
        raise ValueError(f"{problem} TEST_RECIPE.json lacks a hashed test list")
    test_list = (directory / str(relative)).resolve()
    if not test_list.is_file():
        raise FileNotFoundError(f"{problem} test list is missing: {test_list}")
    actual_sha256 = sha256(test_list)
    if actual_sha256 != expected_sha256:
        raise ValueError(
            f"{problem} test-list hash mismatch: "
            f"recorded={expected_sha256} actual={actual_sha256}"
        )
    return test_list


def environment(
    args: argparse.Namespace, problem: str, evidence: Path, test_list: Path | None
) -> dict[str, str]:
    env = os.environ.copy()
    for name in list(env):
        if name.startswith(("CPU_EVAL_EXPECTED_", "CVA6_")) or name in {
            "CPU_EVAL_SPIKE_INSTALL_DIR", "CPU_EVAL_RTL_TRACE_BASENAME",
            "CPU_EVAL_MODULE", "CPU_EVAL_SOURCE"
        }:
            del env[name]
    env.update({
        "LC_ALL": "C",
        "LANG": "C",
        "CVA6_REPO": str(args.checkout.resolve()),
        "CVA6_ENVFILE": str((args.checkout / "verif/sim/setup-env.sh").resolve()),
        "RISCV": str(args.riscv_prefix.resolve()),
        "RISCV_CC": str((args.riscv_prefix / "bin/riscv64-unknown-elf-gcc").resolve()),
        "RISCV_OBJCOPY": str((args.riscv_prefix / "bin/riscv64-unknown-elf-objcopy").resolve()),
        "TB_PATH": str((args.checkout / "verif/tb/core").resolve()),
        "CVA6_TEST_JOBS": "4",
        "CVA6_TARGET": "cv32a60x",
        "CPU_EVAL_LOG_ROOT": str((evidence / "runs").resolve()),
    })
    if test_list is not None:
        env["CVA6_TESTLIST"] = str(test_list)
    if problem in CVXIF_PROBLEMS:
        if args.cvxif_spike_prefix is None:
            raise ValueError(f"{problem} requires --cvxif-spike-prefix")
        env["CPU_EVAL_SPIKE_INSTALL_DIR"] = str(args.cvxif_spike_prefix.resolve())
    return env


def main() -> int:
    args = parse_args()
    if args.samples < 1:
        raise ValueError("samples must be positive")
    if args.invocation_timeout_sec < 1:
        raise ValueError("invocation timeout must be positive")
    if args.output.exists() and not args.resume:
        raise FileExistsError(args.output)
    args.output.mkdir(parents=True, exist_ok=args.resume)
    problems = [
        row["problem"]
        for row in csv.DictReader(args.problems.open(encoding="utf-8"), delimiter="\t")
    ]
    if len(problems) != len(set(problems)) or any(not re.fullmatch(r"[A-Za-z0-9_-]+", p) for p in problems):
        raise ValueError("problem identifiers must be unique and contain only letters, digits, underscores or hyphens")
    run_path = args.output / "run.json"
    immutable = {
        "schema_version": 1,
        "cpu": "CVA6",
        "problems_sha256": sha256(args.problems),
        "samples_per_problem": args.samples,
        "submissions": str(args.submissions.resolve()),
        "checkout": str(args.checkout.resolve()),
        "invocation_timeout_sec": args.invocation_timeout_sec,
    }
    if args.resume:
        prior = json.loads(run_path.read_text(encoding="utf-8"))
        mismatches = {key: (prior.get(key), value) for key, value in immutable.items() if prior.get(key) != value}
        if mismatches:
            raise ValueError(f"resume metadata mismatch: {mismatches}")
        run = prior
    else:
        run = {"started_at": now(), **immutable}
    write_json(run_path, run)

    present_inputs: set[str] = set()
    completed = 0
    for problem in problems:
        for sample in range(args.samples):
            result = args.output / f"{problem}__sample-{sample:02d}"
            candidate = submission_candidate(args.submissions, problem, sample)
            if candidate is None:
                raise FileNotFoundError(f"missing terminal CVA6 candidate: {problem} sample-{sample:02d}")
            if args.resume and completed_sample(result, candidate, problem, sample):
                continue
            if args.resume and result.exists():
                shutil.rmtree(result)
            result.mkdir(parents=True, exist_ok=True)
            evidence = result / "evaluator"
            evidence.mkdir(exist_ok=args.resume)
            command = evaluator_command(args.repo.resolve(), problem, candidate.resolve())
            shared_evaluator = args.repo.resolve() / "cpus/cva6/harness/evaluate_parallel.sh"
            test_list = (
                problem_test_list(args.repo.resolve(), problem)
                if Path(command[0]) == shared_evaluator
                else None
            )
            started = now()
            before = changed_checkout_inputs(args.repo, args.checkout, present_inputs)
            process_exit_code = None
            if before:
                exit_code, stdout, stderr, timed_out = 2, "", "fixed checkout inputs are not restored\n", False
            else:
                exit_code, stdout, stderr, timed_out = run_isolated(
                    command,
                    timeout=args.invocation_timeout_sec,
                    cwd=args.checkout,
                    env=environment(args, problem, evidence, test_list),
                    text=True,
                )
                process_exit_code = exit_code
            after = changed_checkout_inputs(args.repo, args.checkout, present_inputs)
            setup_file = str((args.checkout / "verif/sim/setup-env.sh").resolve())
            setup_unbound = re.search(
                re.escape(setup_file) + r": line \d+: [A-Za-z_][A-Za-z0-9_]*: unbound variable",
                stderr,
            )
            if after or setup_unbound:
                exit_code = 2
            write_json(evidence / "checkout-inputs.json", {"before": before, "after": after})
            (result / "stdout.log").write_text(stdout, encoding="utf-8")
            (result / "stderr.log").write_text(stderr, encoding="utf-8")
            write_json(result / "command.json", command)
            candidate_digest = sha256(candidate)
            verdict = normalized_verdict(evidence, problem, exit_code, timed_out, candidate_digest=candidate_digest)
            write_json(evidence / "verdict.json", {
                "schema_version": 1,
                "problem": problem,
                "sample_index": sample,
                "candidate_sha256": candidate_digest,
                "started_at_utc": started,
                "finished_at_utc": now(),
                "evaluator_exit_code": exit_code,
                "process_exit_code": process_exit_code,
                "timed_out": timed_out,
                "invocation_timeout_sec": args.invocation_timeout_sec,
                "verdict": verdict,
            })
            (result / "exit-code.txt").write_text(f"{exit_code}\n", encoding="utf-8")
            files = sorted(path for path in result.rglob("*") if path.is_file() and path.name != "files.sha256")
            temporary_ledger = result / f"files.sha256.{os.getpid()}.tmp"
            with temporary_ledger.open("w", encoding="utf-8") as stream:
                for path in files:
                    stream.write(f"{sha256(path)}  {path.relative_to(result)}\n")
            temporary_ledger.replace(result / "files.sha256")
            print(f"{problem} sample-{sample:02d} exit={exit_code}", flush=True)
            completed += 1
    run["finished_at"] = now()
    run["terminal_jobs"] = sum(
        (args.output / f"{problem}__sample-{sample:02d}" / "exit-code.txt").is_file()
        for problem in problems for sample in range(args.samples)
    )
    run["evaluated_jobs_this_invocation"] = completed
    write_json(run_path, run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
