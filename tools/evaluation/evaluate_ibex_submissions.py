#!/usr/bin/env python3
"""Evaluate Ibex HDL submissions using the CPU's test programs."""

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def classify_verdict(returncode: int, raw: list[str]) -> str:
    if returncode == 0 and raw[:1] == ["PASS"]:
        return "PASS"
    if returncode == 1 and raw[:1] == ["FAIL"]:
        if raw[1:2] == ["candidate compile diagnostic"]:
            return "FAIL_CANDIDATE_COMPILE"
        if raw[1:2] in (["directed primitive output mismatch"], ["directed public output mismatch"]):
            return "FAIL_DIRECTED_PUBLIC_OUTPUT_MISMATCH"
        if raw[1:2] == ["program did not complete"]:
            return "FAIL_INCOMPLETE_EXECUTION"
        return "FAIL_TRACE_MISMATCH"
    reason = raw[2] if len(raw) > 2 else raw[1] if len(raw) > 1 else f"exit-{returncode}"
    return "INVALID_" + reason.upper().replace(" ", "_")


def candidate_path(root: Path, problem: str, sample: int) -> Path | None:
    directory = root / problem / f"sample-{sample:02d}"
    for name in ("submission.sv", "submission.v"):
        candidate = directory / name
        if candidate.is_file():
            return candidate
    return None


def write_file_ledger(output: Path) -> None:
    files = sorted(path for path in output.rglob("*") if path.is_file() and path != output / "files.sha256")
    temporary = output / f"files.sha256.{os.getpid()}.tmp"
    temporary.write_text("".join(f"{sha256(path)}  {path.relative_to(output)}\n" for path in files), encoding="utf-8")
    temporary.replace(output / "files.sha256")


def completed_sample(output: Path, expected: dict[str, object]) -> bool:
    try:
        verdict_path = output / "evaluator/verdict.json"
        record = json.loads(verdict_path.read_text(encoding="utf-8"))
        if any(record.get(key) != value for key, value in expected.items()):
            return False
        exit_code = int((output / "exit-code.txt").read_text(encoding="utf-8").strip())
        raw_path = output / "evaluator/verdict.tsv"
        raw = raw_path.read_text(encoding="utf-8").strip().split("\t") if raw_path.is_file() else []
        if (record.get("evaluator_exit_code") != exit_code or record.get("raw_verdict") != raw
                or record.get("verdict") != classify_verdict(exit_code, raw)):
            return False
        ledger = {}
        for line in (output / "files.sha256").read_text(encoding="utf-8").splitlines():
            digest, relative = line.split("  ", 1)
            path = Path(relative)
            if path.is_absolute() or ".." in path.parts or relative in ledger:
                return False
            ledger[relative] = digest
        files = {str(path.relative_to(output)): path for path in output.rglob("*")
                 if path.is_file() and path != output / "files.sha256"}
        return (set(ledger) == set(files) and all(not path.is_symlink() and sha256(path) == ledger[name]
                                                for name, path in files.items()))
    except (OSError, ValueError, KeyError, TypeError):
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--problems", required=True, type=Path)
    parser.add_argument("--samples", required=True, type=int)
    parser.add_argument("--submissions", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--ibex-checkout", required=True, type=Path)
    parser.add_argument("--spike-install", required=True, type=Path)
    parser.add_argument("--program-root", required=True, type=Path)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    if args.samples < 1:
        raise ValueError("samples must be positive")

    with args.problems.open(encoding="utf-8", newline="") as stream:
        problems = [row["problem"] for row in csv.DictReader(stream, delimiter="\t")]
    if len(problems) != len(set(problems)) or any(not re.fullmatch(r"[A-Za-z0-9_-]+", problem) for problem in problems):
        raise ValueError("problem identifiers must be unique and contain only letters, digits, underscores or hyphens")
    args.output.mkdir(parents=True, exist_ok=True)
    run_problem = args.repo / "cpus/ibex/harness/run_problem.sh"
    with (args.repo / "cpus/ibex/PROBLEMS.tsv").open(encoding="utf-8", newline="") as stream:
        directories = {row["problem"]: row["directory"] for row in csv.DictReader(stream, delimiter="\t")}
    jobs = []
    for problem in problems:
        recipe_path = args.repo / "cpus/ibex" / directories[problem] / "TEST_RECIPE.json"
        recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
        programs = [args.program_root / problem / f"{name}.elf" for name in recipe["assigned_programs"]]
        for sample in range(args.samples):
            candidate = candidate_path(args.submissions, problem, sample)
            output = args.output / f"{problem}__sample-{sample:02d}"
            if candidate is None:
                continue
            expected = {
                "problem": problem,
                "sample_index": sample,
                "candidate_sha256": sha256(candidate),
                "test_recipe_sha256": sha256(recipe_path),
                "program_sha256": {str(path.resolve()): sha256(path) for path in programs},
            }
            jobs.append((problem, sample, candidate, output, programs, expected))

    immutable = {
        "schema_version": 2,
        "problems": problems,
        "samples": args.samples,
        "problems_sha256": sha256(args.problems),
        "submissions": str(args.submissions.resolve()),
        "checkout": str(args.ibex_checkout.resolve()),
        "spike_install": str(args.spike_install.resolve()),
        "driver_sha256": sha256(Path(__file__)),
        "evaluator_files": {str(path.relative_to(args.repo)): sha256(path)
                            for path in sorted((args.repo / "cpus/ibex").rglob("*"))
                            if path.is_file() and path.suffix in {".py", ".sh", ".sv", ".cpp", ".patch"}},
        "jobs": [expected for *_, expected in jobs],
    }
    run_path = args.output / "run.json"
    if args.resume:
        previous = json.loads(run_path.read_text(encoding="utf-8"))
        if previous.get("inputs") != immutable:
            raise ValueError("resume inputs differ from the recorded run")
    elif run_path.exists() or any(output.exists() for _, _, _, output, _, _ in jobs):
        raise FileExistsError("evaluation records already exist; use --resume with unchanged inputs")
    run = {"inputs": immutable, "completed_samples": 0, "evaluated_samples_this_invocation": 0,
           "skipped_samples_this_invocation": 0}
    write_json(run_path, run)
    for problem, sample, candidate, output, programs, expected in jobs:
        if args.resume and completed_sample(output, expected):
            run["completed_samples"] += 1
            run["skipped_samples_this_invocation"] += 1
            continue
        if output.is_symlink():
            raise ValueError(f"sample output must not be a symlink: {output}")
        if output.exists():
            shutil.rmtree(output)
        command = [
            str(run_problem), str(args.ibex_checkout), str(args.spike_install), problem,
            str(candidate), str(output), *(str(path) for path in programs),
        ]
        completed = subprocess.run(command)
        verdict_tsv = output / "evaluator/verdict.tsv"
        raw = verdict_tsv.read_text(encoding="utf-8").strip().split("\t") if verdict_tsv.is_file() else []
        verdict = classify_verdict(completed.returncode, raw)
        verdict_json = output / "evaluator/verdict.json"
        output.mkdir(parents=True, exist_ok=True)
        (output / "exit-code.txt").write_text(str(completed.returncode) + "\n", encoding="utf-8")
        write_json(verdict_json, {
            "schema_version": 1,
            **expected,
            "verdict": verdict,
            "evaluator_exit_code": completed.returncode,
            "raw_verdict": raw,
        })
        write_file_ledger(output)
        run["completed_samples"] += 1
        run["evaluated_samples_this_invocation"] += 1
        write_json(run_path, run)
    write_json(run_path, run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
