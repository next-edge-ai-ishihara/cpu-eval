#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check division cancellation with the fixed CVA6 arithmetic units."""

from hashlib import sha256
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory, mkdtemp


HERE = Path(__file__).resolve().parent
CPU = HERE.parents[1]
SHARED = CPU / "harness"
sys.path.insert(0, str(SHARED))
from port_work_directory import port_work_root
from candidate_error import EXTERNAL_STOP

REVISION = "6348e9e684678f83b40d0520028513d06b36e7b2"
SOURCES = (
    "core/include/config_pkg.sv",
    "core/include/cv32a60x_config_pkg.sv",
    "core/include/build_config_pkg.sv",
    "core/include/riscv_pkg.sv",
    "core/include/ariane_pkg.sv",
    "vendor/pulp-platform/common_cells/src/cf_math_pkg.sv",
    "vendor/pulp-platform/common_cells/src/lzc.sv",
    "core/multiplier.sv",
    "core/serdiv.sv",
)
TESTBENCH = HERE / "mult_flush_tb.sv"
PASS = b"PASS: flushed division does not produce a result"


def run(candidate):
    helpers = runpy.run_path(CPU / "instr_scan/harness/evaluate_ports.py")
    execute, capacity = helpers["execute"], helpers["CAPACITY"]
    checkout = os.environ["CVA6_REPO"]
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"]).resolve()
    diagnostics = log_root.parent if log_root.name == "runs" else log_root
    diagnostics.mkdir(parents=True, exist_ok=True)
    evidence = Path(mkdtemp(prefix="mult-ports-", dir=diagnostics))
    inputs = {Path(path).name: subprocess.check_output(["git", "-C", checkout, "show", f"{REVISION}:{path}"])
              for path in SOURCES}
    inputs.update({"candidate.sv":candidate.read_bytes(), TESTBENCH.name:TESTBENCH.read_bytes()})
    scratch = port_work_root()
    if sum(map(len, inputs.values())) >= capacity or shutil.disk_usage(scratch).free < capacity:
        raise ValueError("insufficient executable scratch for the mult port test")
    record = {"cpu_revision":REVISION, "source_paths":list(SOURCES),
              "input_sha256":{name:sha256(raw).hexdigest() for name, raw in inputs.items()}}
    with TemporaryDirectory(prefix="cpu-eval-mult-ports-", dir=scratch) as temporary:
        work = Path(temporary)
        for name, raw in inputs.items():
            (work / name).write_bytes(raw)
        command = ["verilator", "--binary", "--timing", "-Wno-fatal", "--top-module", "testbench",
                   "--Mdir", str(work / "obj"), *[str(work / name) for name in inputs]]
        record["build_argv"] = command
        compiled = execute(command, 120, work)
        (evidence / "build.log").write_bytes(compiled.stdout)
        record["build_exit_code"] = compiled.returncode
        if compiled.returncode:
            classified = subprocess.run([sys.executable, str(SHARED / "candidate_error.py"),
                                         str(evidence / "build.log"), str(work / "candidate.sv"),
                                         "--directory", str(work), "--submitted", str(candidate)],
                                        capture_output=True, check=False)
            status, output = 2, classified.stdout + classified.stderr
            if compiled.returncode not in EXTERNAL_STOP and classified.returncode == 1:
                receipts = log_root / "mult" / evidence.name
                receipts.mkdir(parents=True)
                (receipts / "build.log").write_bytes(compiled.stdout)
                (receipts / "candidate-compile-error.txt").write_bytes(compiled.stdout)
                (receipts / "exit-code.txt").write_text("1\n")
                status = 1
        else:
            simulated = execute([str(work / "obj/Vtestbench")], 30, work)
            output = simulated.stdout
            record["runtime_exit_code"] = simulated.returncode
            if simulated.returncode == 0 and PASS in output:
                status = 0
            elif simulated.returncode not in EXTERNAL_STOP:
                status = 1
            else:
                status = 2
    record["exit_code"] = status
    (evidence / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    (evidence / "runtime.log").write_bytes(output)
    print(output.decode(errors="replace"), end="")
    print(f"PORT_RESULT={evidence}")
    return status


if __name__ == "__main__":
    try:
        raise SystemExit(run(Path(sys.argv[1]).resolve()))
    except (OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2) from error
