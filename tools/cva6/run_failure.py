#!/usr/bin/env python3
"""Exit 1 when a stopped CVA6 regression stopped at the RTL simulation of a fixed program.

The fixed programs complete on the reference RTL, so a failing RTL simulation, or a
driver crash while it reads the RTL trace, is the answer's fault unless the output shows
a tool, resource or kill failure. A stop in any other step or a wall-clock stop exits 2.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

FAILED_COMMAND = re.compile(r"ERROR return code: \w+/(-?\d+), cmd:\s*(.*)$")
RTL_COMMAND = re.compile(r"make veri-testharness\b")
ENVIRONMENT_ERROR = re.compile(
    r"command not found|: not found|no such file or directory|error while loading shared libraries|"
    r"out of memory|cannot allocate memory|no space left on device|input/output error|"
    r"\bKilled\b|\bTerminated\b", re.I)


def rtl_failure(run_log: str, simulation_directory: Path) -> bool:
    if "Timeout[" in run_log:
        return False
    traceback = run_log.rfind("Traceback (most recent call last):")
    if traceback >= 0:
        text = run_log[traceback:]
        return ("MemoryError" not in text and re.search(
            r"\bin (?:process_verilator_sim_log|read_verilator_trace)\b", text) is not None)
    commands = [FAILED_COMMAND.search(line) for line in run_log.splitlines()]
    commands = [match for match in commands if match]
    if not commands:
        return False
    command = commands[-1][2]
    # The prebuilt runner exits nonzero only for a missing tool or an external kill.
    if not RTL_COMMAND.match(command):
        return False
    output = re.search(r"&>\s*(\S+)\s*$", command)
    if output is None:
        return False
    path = Path(output[1])
    path = path if path.is_absolute() else simulation_directory / path
    return not ENVIRONMENT_ERROR.search(path.read_text(errors="replace"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_log", type=Path)
    parser.add_argument("simulation_directory", type=Path)
    args = parser.parse_args()
    try:
        failed = rtl_failure(args.run_log.read_text(errors="replace"), args.simulation_directory)
    except OSError as error:
        print(f"cannot read the regression output: {error}", file=sys.stderr)
        return 2
    print("RTL_RUN_FAILURE" if failed else "NOT_AN_RTL_RUN_FAILURE")
    return 1 if failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
