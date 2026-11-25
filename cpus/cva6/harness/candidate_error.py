#!/usr/bin/env python3
"""Decide whether a failed build is the submitted answer's fault.

The fixed tree builds with the reference module, so a build that fails after only
the target module was replaced is the answer's fault unless the compiled source
does not hold the submission or the log shows a resource or tool failure.
"""
import argparse
import os
from pathlib import Path
import re
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools/cva6"))
from replace_module import MissingModule, module_span


# A fixed source given by path, unlike a module named by the answer, is reported as an unquoted path.
ENVIRONMENT_ERROR = re.compile(
    r"command not found|failed to download|out of memory|cannot allocate memory|"
    r"no space left on device|virtual memory exhausted|input/output error|"
    r"\bKilled\b|signal terminated program|error while loading shared libraries|"
    r"Cannot find file containing module: /|Cannot open -f command file|can't open file '", re.I)


# Exit statuses of a start failure or an external kill, including Python's negative signals.
EXTERNAL_STOP = frozenset({124, 126, 127, 137, 143, -9, -15})


def runtime_error(returncode: int, log: str) -> bool:
    """A fixed testbench that ends abnormally is the answer's fault unless it was stopped from outside."""
    return returncode not in EXTERNAL_STOP and not ENVIRONMENT_ERROR.search(log)


def write_compile_receipt(directory: Path, log: bytes) -> None:
    """Write the receipt that the CVA6 driver reads as FAIL_CANDIDATE_COMPILE."""
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "build.log").write_bytes(log)
    (directory / "candidate-compile-error.txt").write_bytes(log)
    (directory / "exit-code.txt").write_text("1\n")


def record_compile_failure(problem: str, log: bytes, message: str) -> int:
    """Write a compile receipt under CPU_EVAL_LOG_ROOT/<problem> and return 1."""
    print("FAIL_CANDIDATE_COMPILE: " + message)
    root = os.environ.get("CPU_EVAL_LOG_ROOT")
    if root:
        directory = Path(root) / problem
        directory.mkdir(parents=True, exist_ok=True)
        write_compile_receipt(Path(tempfile.mkdtemp(prefix="candidate-compile-", dir=directory)), log)
    return 1


def missing_module(problem: str, error: MissingModule) -> int:
    return record_compile_failure(problem, f"candidate: {error}\n".encode(),
                                  f"the submission does not define the target module: {error}")


def holds_submission(integrated: str, submitted: str) -> bool:
    if integrated == submitted:
        return True
    for name in dict.fromkeys(re.findall(r"(?m)^\s*module\s+(\w+)\b", submitted)):
        try:
            start, end = module_span(submitted, name)
        except ValueError:
            continue
        if submitted[start:end] in integrated:
            return True
    return False


def candidate_error(log: str, candidate: Path, directory: Path | None = None,
                    submitted: Path | None = None) -> bool:
    if submitted is None or ENVIRONMENT_ERROR.search(log):
        return False
    return holds_submission(candidate.read_text(errors="replace"), submitted.read_text(errors="replace"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--submitted", type=Path, required=True)
    args = parser.parse_args()
    try:
        identified = candidate_error(args.log.read_text(errors="replace"), args.candidate,
                                     args.directory, args.submitted)
    except OSError as error:
        print("INVALID_BUILD: cannot inspect compiler inputs: " + " ".join(str(error).split()))
        return 2
    if identified:
        print("FAIL_CANDIDATE_COMPILE: compiler error identifies the submitted source")
        return 1
    print("INVALID_BUILD: the build log shows a tool or resource failure, "
          "or the compiled source does not hold the submission")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
