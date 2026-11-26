#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the population count at the input widths that cv32a60x instantiates."""

import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile

HARNESS = Path(__file__).resolve().parent
CPU = HARNESS.parents[1]
sys.path.insert(0, str(CPU / "harness"))
from port_work_directory import port_work_root
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP

tools = runpy.run_path(str(CPU / "instr_scan/harness/evaluate_ports.py"))
execute = tools["execute"]
CAPACITY = tools["CAPACITY"]
PASS_LINE = "PASS: population count at the instantiated widths"


def main(submitted):
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")
    with tempfile.TemporaryDirectory(prefix="popcount-ports-", dir=root) as folder:
        work = Path(folder)
        candidate = work / "candidate.sv"
        candidate.write_bytes(submitted.read_bytes())
        bench = HARNESS / "popcount_ports_tb.sv"
        log_dir = Path(tempfile.mkdtemp(prefix="popcount-ports-", dir=os.environ["CPU_EVAL_LOG_ROOT"]))
        build_log = log_dir / "build.log"
        build = execute(["verilator", "--binary", "--timing", "-Wno-fatal",
                         "--top-module", "testbench", "--Mdir", str(work / "obj"),
                         str(candidate), str(bench)], 120, work)
        build_log.write_bytes(build.stdout)
        if build.returncode in EXTERNAL_STOP or ENVIRONMENT_ERROR.search(build.stdout.decode(errors="replace")):
            print(f"INVALID: popcount port simulator build was stopped ({build.returncode}); see {build_log}")
            return 2
        if build.returncode != 0:
            print(f"FAIL: popcount port simulator did not build with the submission; see {build_log}")
            return 1
        runtime = execute([str(work / "obj/Vtestbench")], 30, work)
        (log_dir / "runtime.log").write_bytes(runtime.stdout)
        output = runtime.stdout.decode(errors="replace")
        print(output, end="")
        if runtime.returncode == 0 and PASS_LINE in output.splitlines():
            return 0
        if runtime.returncode not in EXTERNAL_STOP:
            return 1
        print(f"INVALID: popcount port simulator was stopped ({runtime.returncode})")
        return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1])))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
