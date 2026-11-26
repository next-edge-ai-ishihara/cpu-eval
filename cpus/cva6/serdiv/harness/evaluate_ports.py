#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the CV32A60X serdiv using the pinned CV32A60X configuration."""

import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile

HARNESS = Path(__file__).resolve().parent
COMMON = HARNESS.parents[1] / "harness"
sys.path.insert(0, str(COMMON))
from port_work_directory import port_work_root
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP

CPU_REV = "6348e9e684678f83b40d0520028513d06b36e7b2"
SOURCE_NAMES = ("config_pkg", "cv32a60x_config_pkg", "build_config_pkg", "riscv_pkg", "ariane_pkg")
VENDOR_SOURCES = ("cf_math_pkg", "lzc")
PASS_LINE = "PASS: unaccepted division result and ID retained"
tools = runpy.run_path(str(HARNESS.parents[1] / "instr_scan/harness/evaluate_ports.py"))
execute = tools["execute"]
CAPACITY = tools["CAPACITY"]


def read_source(path):
    return subprocess.check_output([
        "git", "-C", os.environ["CVA6_REPO"], "show", f"{CPU_REV}:{path}",
    ], timeout=10)


def main(submitted):
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")
    with tempfile.TemporaryDirectory(prefix="serdiv-ports-", dir=root) as folder:
        work = Path(folder)
        files = {f"{name}.sv": read_source(f"core/include/{name}.sv") for name in SOURCE_NAMES}
        files.update({f"{name}.sv": read_source(f"vendor/pulp-platform/common_cells/src/{name}.sv") for name in VENDOR_SOURCES})
        files["candidate.sv"] = submitted.read_bytes()
        bench = "serdiv_ports_tb.sv"
        files[bench] = (HARNESS / bench).read_bytes()
        for name, contents in files.items():
            (work / name).write_bytes(contents)

        log_dir = Path(tempfile.mkdtemp(prefix="serdiv-ports-", dir=os.environ["CPU_EVAL_LOG_ROOT"]))
        build_log = log_dir / "build.log"
        build = execute(["verilator", "--binary", "--timing", "-Wno-fatal",
                         "--top-module", "testbench", "--Mdir", str(work / "obj"),
                         "-I" + str(work), *(str(work / name) for name in files)], 120, work)
        build_log.write_bytes(build.stdout)
        if build.returncode in EXTERNAL_STOP or ENVIRONMENT_ERROR.search(build.stdout.decode(errors="replace")):
            print(f"INVALID: serdiv port simulator build was stopped ({build.returncode}); see {build_log}")
            return 2
        if build.returncode != 0:
            print(f"FAIL: serdiv port simulator did not build with the submission; see {build_log}")
            return 1
        runtime = execute([str(work / "obj/Vtestbench")], 30, work)
        (log_dir / "runtime.log").write_bytes(runtime.stdout)
        output = runtime.stdout.decode(errors="replace")
        print(output, end="")
        if runtime.returncode == 0 and PASS_LINE in output.splitlines():
            return 0
        if runtime.returncode not in EXTERNAL_STOP:
            return 1
        print(f"INVALID: serdiv port simulator was stopped ({runtime.returncode})")
        return 2


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1])))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
