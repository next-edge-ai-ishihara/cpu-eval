#!/usr/bin/env python3
"""Evaluate submitted BOOM HDL files using their assigned tests."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--problems", required=True, type=Path)
    parser.add_argument("--samples", required=True, type=int)
    parser.add_argument("--submissions", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--worktree", required=True, type=Path)
    parser.add_argument("--chisel-source", required=True, type=Path)
    parser.add_argument("--ivy-home", required=True, type=Path)
    parser.add_argument("--riscv-tools", required=True, type=Path)
    parser.add_argument("--test-root", required=True, type=Path)
    parser.add_argument("--ccache-dir", required=True, type=Path)
    parser.add_argument("--build-jobs", type=int, default=32)
    parser.add_argument("--test-parallelism", type=int, default=8)
    parser.add_argument(
        "--invocation-timeout-sec",
        type=int,
        default=43200,
        help="maximum wall time for one candidate evaluation; it exceeds the per-test cycle limits",
    )
    parser.add_argument("--resume", action="store_true")
    return parser.parse_args()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


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
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def load_policy_module(repo: Path):
    path = repo / "cpus/boom/_shared/evaluation_policy.py"
    spec = importlib.util.spec_from_file_location("boom_evaluation_policy", path)
    module = importlib.util.module_from_spec(spec)
    if spec.loader is None:
        raise ImportError(f"cannot load {path}")
    spec.loader.exec_module(module)
    return module


def submission_candidate(root: Path, problem: str, sample: int) -> Path | None:
    directory = root / problem / f"sample-{sample:02d}"
    candidate = directory / "submission.scala"
    return candidate if candidate.is_file() else None


def problem_source_unit(repo: Path, problem: str) -> str:
    definition_path = repo / "cpus/boom" / problem / "problem.yaml"
    definition = yaml.safe_load(definition_path.read_text(encoding="utf-8"))
    target = definition.get("target")
    target = target if isinstance(target, dict) else {}
    unit = (
        target.get("module") or target.get("class")
        or target.get("source_class") or definition.get("name")
    )
    if not isinstance(unit, str) or not unit.strip():
        raise ValueError(f"BOOM problem lacks a source-unit identity: {problem}")
    with (repo / "cpus/boom/SOURCE_UNITS.tsv").open(encoding="utf-8", newline="") as stream:
        matches = [
            row for row in csv.DictReader(stream, delimiter="\t")
            if row["source_unit"] == unit
        ]
    if len(matches) != 1:
        raise ValueError(f"expected one BOOM source-unit record for {problem}/{unit}, found {len(matches)}")
    return unit


def apply_problem_configuration(repo: Path, worktree: Path, problem: str) -> str:
    configurations = {
        "btb_branch_predictor_bank": (
            "LargeBoomCommitTraceConfig",
            [(worktree / "generators/boom", repo / "cpus/boom/btb_branch_predictor_bank/patches/0001-flush-jal-correction-mask.patch")],
        ),
        "nbdtlb": (
            "LargeBoomCommitTraceConfig",
            [(worktree / "generators/boom", repo / "cpus/boom/nbdtlb/patches/0001-discard-invalidated-refills.patch")],
        ),
        "pred_rename_stage": (
            "LargeBoomSFBTestConfig",
            [(worktree, repo / "cpus/boom/pred_rename_stage/patches/0001-add-sfb-test-config.patch")],
        ),
        "tage_branch_predictor_bank": (
            "LargeBoomTageObservableConfig",
            [(worktree, repo / "cpus/boom/tage_branch_predictor_bank/patches/0001-add-tage-observable-config.patch")],
        ),
        "tage_table": (
            "LargeBoomTageObservableConfig",
            [(worktree, repo / "cpus/boom/tage_table/patches/0001-add-tage-observable-config.patch")],
        ),
        "null_local_branch_predictor_bank": (
            "LargeBoomNullLocalObservableConfig",
            [
                (worktree, repo / "cpus/boom/null_local_branch_predictor_bank/patches/0001-add-null-local-observable-config.patch"),
                (worktree / "generators/boom", repo / "cpus/boom/null_local_branch_predictor_bank/patches/0002-select-null-local-provider.patch"),
            ],
        ),
    }
    config, patches = configurations.get(problem, ("LargeBoomCommitTraceConfig", []))
    for checkout, patch in patches:
        pending = subprocess.run(
            ["git", "-C", str(checkout), "apply", "--check", str(patch)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if pending.returncode == 0:
            subprocess.run(["git", "-C", str(checkout), "apply", str(patch)], check=True)
            continue
        applied = subprocess.run(
            ["git", "-C", str(checkout), "apply", "--reverse", "--check", str(patch)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if applied.returncode != 0:
            raise ValueError(f"configuration patch is neither applicable nor already applied: {patch}")
    return config


def base_environment(args: argparse.Namespace, config: str) -> dict[str, str]:
    env = {key: value for key, value in os.environ.items() if not key.startswith("BOOM_")}
    env.update({
        "LC_ALL": "C",
        "LANG": "C",
        "LD_LIBRARY_PATH": str((args.riscv_tools / "lib").resolve()),
        "BOOM_WORKTREE": str(args.worktree.resolve()),
        "BOOM_INVENTORY": str((args.repo / "cpus/boom/SOURCE_UNITS.tsv").resolve()),
        "BOOM_BLOCK_TOOL": str((args.repo / "cpus/boom/_shared/source_unit_blocks.py").resolve()),
        "BOOM_CHISEL_SOURCE": str(args.chisel_source.resolve()),
        "BOOM_CHISEL_SBT": str((args.worktree / "generators/rocket-chip/sbt-launch.jar").resolve()),
        "BOOM_JAVA_BIN": "/usr/lib/jvm/java-17-openjdk-amd64/bin",
        "BOOM_SBT_IVY_HOME": str(args.ivy_home.resolve()),
        "BOOM_RISCV_TOOLS": str(args.riscv_tools.resolve()),
        "BOOM_VERILATOR_BIN": "/opt/toolchain/verilator-install/bin",
        "BOOM_DTC_BIN": "/usr/bin",
        "BOOM_TRACE_COMPARATOR": str((args.repo / "cpus/boom/_shared/compare_instruction_traces.py").resolve()),
        "BOOM_CCACHE_DIR": str(args.ccache_dir.resolve()),
        "BOOM_BUILD_JOBS": str(args.build_jobs),
        "BOOM_TEST_PARALLELISM": str(args.test_parallelism),
        "BOOM_CONFIG": config,
    })
    return env


FAILURES = {
    "FAIL": "FAIL_FUNCTIONAL_MISMATCH",
    "FAIL_CANDIDATE_COMPILE": "FAIL_CANDIDATE_COMPILE",
    "FAIL_ELABORATION": "FAIL_ELABORATION",
    "FAIL_INCOMPLETE_EXECUTION": "FAIL_INCOMPLETE_EXECUTION",
}


def normalized_verdict(evidence: Path, evaluator_exit_code: int) -> tuple[str, str]:
    """Any answer failure is FAIL; INVALID remains only for evaluator, tool or resource failures."""
    if evaluator_exit_code in {124, 137, 143, -9, -15}:
        return "INVALID_EVALUATION", "evaluator_interrupted"
    if evaluator_exit_code == 125:
        return "INVALID_EVALUATION", "fixed_source_not_restored"
    rows = []
    direct = evidence / "verdict.tsv"
    if direct.is_file():
        fields = (direct.read_text(encoding="utf-8").splitlines() or [""])[0].split("\t")
        rows.append((fields[0], fields[1] if len(fields) > 1 else "", "1"))
    summary = evidence / "summary.tsv"
    if summary.is_file():
        with summary.open(encoding="utf-8", newline="") as stream:
            rows.extend((row.get("verdict") or "", row.get("test") or "", row.get("exit_code"))
                        for row in csv.DictReader(stream, delimiter="\t"))
    if not rows:
        return "INVALID_EVALUATION", "evaluator_verdict_missing"
    if evaluator_exit_code == 0 and all(raw == "PASS" for raw, _, _ in rows):
        return "PASS", rows[0][1] if direct.is_file() else "full_suite_passed"
    if evaluator_exit_code != 0:
        for raw, detail, code in rows:
            if raw in FAILURES and code == "1":
                return FAILURES[raw], detail
    if direct.is_file() and rows[0][0] != "PASS":
        return "INVALID_EVALUATION", rows[0][1] or "evaluator_verdict_invalid"
    return "INVALID_EVALUATION", "full_suite_incomplete"


def main() -> int:
    args = parse_args()
    if (
        args.samples < 1
        or args.build_jobs < 1
        or args.test_parallelism < 1
        or args.invocation_timeout_sec < 1
    ):
        raise ValueError("samples, build jobs, test parallelism, and timeout must be positive")
    if args.output.exists() and not args.resume:
        raise FileExistsError(args.output)
    args.output.mkdir(parents=True, exist_ok=args.resume)
    policy_module = load_policy_module(args.repo.resolve())
    problems = [
        row["problem"]
        for row in csv.DictReader(args.problems.open(encoding="utf-8"), delimiter="\t")
    ]
    if len(problems) != 1:
        raise ValueError("BOOM evaluation requires one problem per chunk")
    problem = problems[0]
    evaluation = policy_module.evaluation_row(args.repo / "cpus/boom", problem)
    source_unit = problem_source_unit(args.repo, problem)
    config = apply_problem_configuration(args.repo.resolve(), args.worktree.resolve(), problem)
    run_path = args.output / "run.json"
    immutable = {
        "schema_version": 1,
        "cpu": "BOOM",
        "problem": problem,
        "samples_per_problem": args.samples,
        "submissions": str(args.submissions.resolve()),
        "configuration": config,
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

    completed = 0
    for sample in range(args.samples):
        result = args.output / f"{problem}__sample-{sample:02d}"
        if args.resume and (result / "exit-code.txt").is_file():
            continue
        candidate = submission_candidate(args.submissions, problem, sample)
        if candidate is None:
            raise FileNotFoundError(f"missing terminal BOOM candidate: {problem} sample-{sample:02d}")
        result.mkdir(parents=True, exist_ok=True)
        evidence = result / "evaluator"
        environment = base_environment(args, config)
        if evaluation["method"] == "directed_module_external":
            source, test_class = policy_module.external_test(args.repo / "cpus/boom", problem)
            command = [
                str(args.repo / "cpus/boom/_shared/evaluate_directed_source_test.sh"),
                source_unit, str(candidate.resolve()), str(source.resolve()), test_class, str(evidence.resolve()),
            ]
        else:
            tests, policy = policy_module.write_policy(args.repo / "cpus/boom", problem, result / "policy")
            environment["BOOM_TEST_POLICY"] = str(policy.resolve())
            command = [
                str(args.repo / "cpus/boom/_shared/evaluate_source_candidate_suite.sh"),
                source_unit, str(candidate.resolve()), str(tests.resolve()), str(args.test_root.resolve()),
                str(evidence.resolve()),
            ]
        started = now()
        dedicated = args.repo / "cpus/boom" / problem / "evaluate_candidate.sh"
        if dedicated.is_file():
            command[0] = str(dedicated)
        exit_code, stdout, stderr, timed_out = run_isolated(
            command,
            timeout=args.invocation_timeout_sec,
            cwd=args.worktree,
            env=environment,
            text=True,
        )
        (result / "stdout.log").write_text(stdout, encoding="utf-8")
        (result / "stderr.log").write_text(stderr, encoding="utf-8")
        (result / "exit-code.txt").write_text(f"{exit_code}\n", encoding="utf-8")
        write_json(result / "command.json", command)
        if timed_out:
            verdict, detail = "INVALID_EVALUATION", "candidate_evaluation_timeout"
        else:
            verdict, detail = normalized_verdict(evidence, exit_code)
        write_json(evidence / "evaluation-verdict.json", {
            "schema_version": 1,
            "problem": problem,
            "sample_index": sample,
            "candidate_sha256": sha256(candidate),
            "started_at_utc": started,
            "finished_at_utc": now(),
            "evaluator_exit_code": exit_code,
            "timed_out": timed_out,
            "invocation_timeout_sec": args.invocation_timeout_sec,
            "verdict": verdict,
            "detail": detail,
        })
        files = sorted(path for path in result.rglob("*") if path.is_file() and path.name != "files.sha256")
        with (result / "files.sha256").open("w", encoding="utf-8") as stream:
            for path in files:
                stream.write(f"{sha256(path)}  {path.relative_to(result)}\n")
        print(f"{problem} sample-{sample:02d} {verdict}", flush=True)
        completed += 1
    run["finished_at"] = now()
    run["terminal_jobs"] = sum(
        (args.output / f"{problem}__sample-{sample:02d}" / "exit-code.txt").is_file()
        for sample in range(args.samples)
    )
    run["evaluated_jobs_this_invocation"] = completed
    write_json(run_path, run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
