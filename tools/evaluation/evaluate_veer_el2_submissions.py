#!/usr/bin/env python3
"""Evaluate submitted VeeR EL2 HDL files using their assigned tests."""

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
    parser.add_argument("--checkout", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--verilator-bin", required=True, type=Path)
    parser.add_argument("--spike-bin", required=True, type=Path)
    parser.add_argument("--riscv-dv-venv", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--resume", action="store_true")
    return parser.parse_args()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def worker_environment(verilator_bin: Path, spike_bin: Path, venv: Path) -> dict[str, str]:
    env = os.environ.copy()
    env["PATH"] = (
        f"{verilator_bin.resolve()}:{spike_bin.resolve()}:{venv.resolve() / 'bin'}:{env.get('PATH', '')}"
    )
    return env

def classify(exit_code: int, execution_path: Path) -> str:
    if exit_code in (3, 4) and execution_path.is_file():
        execution = json.loads(execution_path.read_text())
        failure = {3: "compile", 4: "incomplete"}[exit_code]
        if execution.get("answer_failure") == failure and not execution.get("timed_out"):
            return {3: "FAIL_CANDIDATE_COMPILE", 4: "FAIL_INCOMPLETE_EXECUTION"}[exit_code]
    return {0: "PASS", 1: "FAIL_FUNCTIONAL_MISMATCH"}.get(exit_code, "INVALID_EVALUATION")


def main() -> int:
    args = parse_args()
    if args.samples < 1:
        raise ValueError("samples must be positive")
    if args.output.exists() and not args.resume:
        raise FileExistsError(args.output)
    args.output.mkdir(parents=True, exist_ok=args.resume)

    rows = list(csv.DictReader(args.problems.open(encoding="utf-8"), delimiter="\t"))
    problems = [row["problem"] for row in rows]

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
            candidate = directory / "submission.v"
            if not candidate.is_file():
                candidate = directory / "submission.sv"
            if candidate.is_file():
                jobs.append((problem, sample, candidate))

    run_path = args.output / "run.json"
    immutable_run = {
        "schema_version": 1,
        "cpu": "VeeR EL2",
        "problems_sha256": sha256(args.problems),
        "samples_per_problem": args.samples,
        "submission_root": str(args.submissions.resolve()),
        "checkout": str(args.checkout.resolve()),
        "verilator_bin": str(args.verilator_bin.resolve()),
        "verilator_version": subprocess.check_output(
            [str(args.verilator_bin.resolve() / "verilator"), "--version"], text=True
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
    evaluator = args.repo / "cpus/veer_el2/harness/evaluate_source_unit.py"

    statuses: list[int] = []
    env = worker_environment(args.verilator_bin, args.spike_bin, args.riscv_dv_venv)
    for problem, sample, candidate in jobs:
        result = args.output / f"{problem}__sample-{sample:02d}"
        result.mkdir(exist_ok=True)
        command = [
            "python3", str(evaluator),
            "--checkout", str(args.checkout),
            "--repo", str(args.repo),
            "--problem", problem,
            "--candidate", str(candidate),
            "--results", str(result / "evaluator"),
            "--timeout", str(args.timeout),
        ]
        started = datetime.now(timezone.utc)
        completed = subprocess.run(command, text=True, capture_output=True, env=env)
        elapsed = (datetime.now(timezone.utc) - started).total_seconds()
        write_json(result / "command.json", command)
        (result / "stdout.log").write_text(completed.stdout, encoding="utf-8")
        (result / "stderr.log").write_text(completed.stderr, encoding="utf-8")
        (result / "exit-code.txt").write_text(f"{completed.returncode}\n", encoding="utf-8")
        verdict = classify(completed.returncode, result / "evaluator" / "execution.json")
        write_json(result / "evaluator" / "verdict.json", {
            "schema_version": 1,
            "problem": problem,
            "sample_index": sample,
            "candidate_sha256": sha256(candidate),
            "verdict": verdict,
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
