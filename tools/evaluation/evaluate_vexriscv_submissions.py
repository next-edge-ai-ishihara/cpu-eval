#!/usr/bin/env python3
"""Evaluate submitted VexRiscv HDL files using their assigned tests."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--problems", required=True, type=Path)
    parser.add_argument("--samples", required=True, type=int)
    parser.add_argument("--submissions", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--spinal-checkout", required=True, type=Path)
    parser.add_argument("--vex-standard-checkout", required=True, type=Path)
    parser.add_argument("--debug-checkout", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--evaluator-revision")
    parser.add_argument("--sbt", required=True, type=Path)
    parser.add_argument("--java-home", required=True, type=Path)
    parser.add_argument("--spinal-source-checkout", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=3600)
    parser.add_argument("--resume", action="store_true")
    return parser.parse_args()

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def git(repo: Path, *arguments: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *arguments], text=True
    ).strip()


def profile_for(problem: str, repositories: dict[str, str]) -> str:
    if repositories[problem] == "spinalhdl":
        return "spinal"
    return "debug" if problem == "debug_plugin" else "vex-standard"


def worker_environment(java_home: Path, checkout: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["JAVA_HOME"] = str(java_home.resolve())
    env["PATH"] = f"{java_home.resolve() / 'bin'}:{env.get('PATH', '')}"
    env["CPU_EVAL_VEX_EXECUTION_LOCK"] = str(
        checkout.resolve() / ".cpu-eval-execution.lock"
    )
    return env

def main() -> int:
    args = parse_args()
    if args.samples < 1:
        raise ValueError("samples must be positive")
    if args.output.exists() and not args.resume:
        raise FileExistsError(args.output)
    args.output.mkdir(parents=True, exist_ok=args.resume)

    rows = list(csv.DictReader(args.problems.open(encoding="utf-8"), delimiter="\t"))
    problems = [row["problem"] for row in rows]
    population = json.loads((args.repo / "cpus/vexriscv/SOURCE_UNITS.json").read_text())
    repositories = {unit["id"]: unit["repository"] for unit in population["units"]}
    if any(problem not in repositories for problem in problems):
        raise ValueError("problem manifest contains an unknown VexRiscv source unit")
    checkouts = {"spinal": args.spinal_checkout, "vex-standard": args.vex_standard_checkout,
                 "debug": args.debug_checkout}

    completed_keys: set[tuple[str, int]] = set()
    if args.resume:
        for directory in args.output.glob("*__sample-*"):
            exit_file = directory / "exit-code.txt"
            if not exit_file.is_file():
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

    run_path = args.output / "run.json"
    immutable_run = {
        "schema_version": 1,
        "evaluator_repository": str(args.repo.resolve()),
        "evaluator_revision": args.evaluator_revision or git(args.repo.resolve(), "rev-parse", "HEAD"),
        "evaluator_sha256": sha256(
            args.repo.resolve() / "cpus/vexriscv/harness/evaluate_source_unit.py"
        ),
        "evaluation_driver_sha256": sha256(Path(__file__).resolve()),
        "problems_sha256": sha256(args.problems),
        "samples_per_problem": args.samples,
        "submission_root": str(args.submissions.resolve()),
        "checkouts": {profile: str(path.resolve()) for profile, path in checkouts.items()},
        "java_home": str(args.java_home.resolve()),
        "java_version": subprocess.check_output(
            [str(args.java_home.resolve() / "bin/java"), "-version"],
            text=True,
            stderr=subprocess.STDOUT,
        ).strip(),
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
            raise ValueError(f"resume metadata mismatch: {mismatches}")
        run["resumed_at"] = now()
        run.pop("finished_at", None)
    else:
        run = {"started_at": now(), **immutable_run}
    run["job_count_this_invocation"] = len(jobs)
    run["terminal_jobs_before_invocation"] = len(completed_keys)
    write_json(run_path, run)
    progress = args.output / "progress.tsv"
    if not args.resume:
        progress.write_text("finished_at\tproblem\tsample_index\texit_code\twall_seconds\n", encoding="utf-8")
    evaluator = args.repo / "cpus/vexriscv/harness/evaluate_source_unit.py"

    statuses: list[int] = []
    for problem, sample, candidate in jobs:
        checkout = checkouts[profile_for(problem, repositories)]
        result = args.output / f"{problem}__sample-{sample:02d}"
        result.mkdir(exist_ok=True)
        command = [
            "python3", str(evaluator),
            "--checkout", str(checkout),
            "--repo", str(args.repo),
            "--problem", problem,
            "--candidate", str(candidate),
            "--results", str(result / "evaluator"),
            "--sbt", str(args.sbt),
            "--timeout", str(args.timeout),
            "--spinal-checkout", str(args.spinal_source_checkout),
        ]
        started = datetime.now(timezone.utc)
        env = worker_environment(args.java_home, checkout)
        completed = subprocess.run(command, text=True, capture_output=True, env=env)
        elapsed = (datetime.now(timezone.utc) - started).total_seconds()
        write_json(result / "command.json", command)
        (result / "stdout.log").write_text(completed.stdout, encoding="utf-8")
        (result / "stderr.log").write_text(completed.stderr, encoding="utf-8")
        (result / "exit-code.txt").write_text(f"{completed.returncode}\n", encoding="utf-8")
        verdict_path = result / "evaluator/verdict.json"
        if not verdict_path.is_file():
            verdict_path.parent.mkdir(parents=True, exist_ok=True)
            write_json(verdict_path, {
                "schema_version": 1,
                "problem": problem,
                "sample_index": sample,
                "candidate_sha256": sha256(candidate),
                "verdict": "INVALID_EVALUATOR_NO_VERDICT",
                "evaluator_exit_code": completed.returncode,
            })
        files = sorted(path for path in result.rglob("*") if path.is_file() and path.name != "files.sha256")
        with (result / "files.sha256").open("w", encoding="utf-8") as stream:
            for path in files:
                stream.write(f"{sha256(path)}  {path.relative_to(result)}\n")
        with progress.open("a", encoding="utf-8") as stream:
            stream.write(f"{now()}\t{problem}\t{sample}\t{completed.returncode}\t{elapsed:.3f}\n")
        print(f"{problem} sample-{sample:02d} exit={completed.returncode}", flush=True)
        statuses.append(completed.returncode)

    terminal_statuses = []
    for problem in problems:
        for sample in range(args.samples):
            exit_file = args.output / f"{problem}__sample-{sample:02d}" / "exit-code.txt"
            if exit_file.is_file():
                terminal_statuses.append(int(exit_file.read_text(encoding="utf-8").strip()))
    run["finished_at"] = now()
    run["evaluated_jobs_this_invocation"] = len(statuses)
    run["terminal_jobs"] = len(terminal_statuses)
    run["passing_jobs"] = terminal_statuses.count(0)
    write_json(run_path, run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
