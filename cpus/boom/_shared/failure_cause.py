#!/usr/bin/env python3
"""Classify a failed BOOM build, simulation or directed test as FAIL or INVALID.

The fixed tree builds and runs with the reference unit, so a failure after only the
candidate was integrated is the candidate's unless the integrated source differs from
the submission, the log shows a resource or tool failure, or the run was interrupted.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys


ENVIRONMENT_ERROR = re.compile(
    r"command not found|error while loading shared libraries|failed to download|error downloading|"
    r"unresolved dependency|out of memory|outofmemoryerror|java heap space|gc overhead limit exceeded|"
    r"cannot allocate memory|virtual memory exhausted|no space left on device|"
    r"disk quota exceeded|input/output error|killed signal terminated program|permission denied|"
    r"operation not permitted|address already in use|too many open files", re.I)
INTERRUPTED = {124, 137, 143}
COMPLETION = re.compile(r"\*\*\* (PASSED|FAILED) \*\*\*.*after [0-9]+ cycles")
CYCLE_LIMIT = "*** FAILED *** via trace_count (timeout"
LARGE_LOG_BYTES = 64 << 20


def read(path: Path) -> str:
    return path.read_text(errors="replace") if path.is_file() else ""


def target_matches(region: Path, candidate: Path) -> bool:
    try:
        record = json.loads(region.read_text())
        source = Path(record["source"])
        return (record["candidate_sha256"] == hashlib.sha256(candidate.read_bytes()).hexdigest()
                and record["source_sha256"] == hashlib.sha256(source.read_bytes()).hexdigest())
    except (OSError, KeyError, TypeError, ValueError):
        return False


def build(log: str, code: int, region: Path, candidate: Path, publication: bool) -> tuple[str, str]:
    if code in INTERRUPTED:
        return "INVALID", f"build_interrupted_{code}"
    if not target_matches(region, candidate):
        return "INVALID", "target_differs_from_submission"
    if ENVIRONMENT_ERROR.search(log):
        return "INVALID", "build_environment"
    if publication or "Compilation failed" in log:
        return "FAIL_CANDIDATE_COMPILE", "candidate_scala_compile_error"
    return "FAIL_ELABORATION", "candidate_elaboration_or_model_build_error"


def run(log: str, code: int) -> tuple[str, str] | None:
    """Return None when the program reached its own PASSED or FAILED end."""
    if code in INTERRUPTED:
        return "INVALID", f"simulator_interrupted_{code}"
    if ENVIRONMENT_ERROR.search(log):
        return "INVALID", "simulator_environment"
    if CYCLE_LIMIT in log:
        return "FAIL_INCOMPLETE_EXECUTION", "cycle_limit_reached"
    if not COMPLETION.search(log):
        return "FAIL_INCOMPLETE_EXECUTION", f"program_did_not_complete_exit_{code}"
    return None


def directed(log: str, code: int, region: Path, candidate: Path) -> tuple[str, str]:
    if code in INTERRUPTED:
        return "INVALID", f"directed_test_interrupted_{code}"
    if code == 0 and "All tests passed" in log:
        return "PASS", "directed_public_output_match"
    if ENVIRONMENT_ERROR.search(log):
        return "INVALID", "directed_test_environment"
    if not target_matches(region, candidate):
        return "INVALID", "target_differs_from_submission"
    if "Compilation failed" in log:
        return "FAIL_CANDIDATE_COMPILE", "candidate_scala_compile_error"
    if re.search(r"Tests: succeeded [0-9]+, failed [1-9][0-9]*", log):
        return "FAIL", "directed_public_output_mismatch"
    if code != 0:
        return "FAIL_ELABORATION", "directed_test_aborted"
    return "INVALID", "directed_test_did_not_run"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("build", "directed"):
        command = commands.add_parser(name)
        command.add_argument("log", type=Path)
        command.add_argument("code", type=int)
        command.add_argument("region", type=Path)
        command.add_argument("candidate", type=Path)
        if name == "build":
            command.add_argument("--publication", action="store_true")
    command = commands.add_parser("run")
    command.add_argument("log", type=Path)
    command.add_argument("code", type=int)
    args = parser.parse_args()
    log = read(args.log)
    if args.command == "build":
        verdict = build(log, args.code, args.region, args.candidate, args.publication)
    elif args.command == "directed":
        verdict = directed(log, args.code, args.region, args.candidate)
    else:
        verdict = run(log, args.code)
        if verdict is None:
            return 0
        if verdict[0] != "INVALID" and args.log.stat().st_size > LARGE_LOG_BYTES:
            # A trace of up to 2.5M cycles is evidence only, so it is kept compressed.
            with args.log.open("rb") as source, gzip.open(f"{args.log}.gz", "wb") as target:
                target.writelines(source)
            args.log.unlink()
    print("\t".join(verdict))
    return {"PASS": 0, "INVALID": 2}.get(verdict[0], 1)


if __name__ == "__main__":
    sys.exit(main())
