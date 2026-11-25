#!/usr/bin/env python3
"""Build only the submitted predictor and compare its public ports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evaluate(cpu_root, results, tool=None):
    cpu_root = Path(cpu_root).resolve()
    results = Path(results).resolve()
    results.mkdir(parents=True, exist_ok=True)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    record = {"status": 2, "scope": "prediction public-port unit; no whole CPU build"}
    tool = tool or shutil.which("verilator")
    try:
        if not tool:
            raise ValueError("verilator is not on PATH")
        version = subprocess.check_output([tool, "--version"], text=True).strip()
        if "Verilator 5.036 " not in version:
            raise ValueError("Verilator 5.036 is required")
        include = cpu_root / "tools/riscv-dv/work"
        names = ["tools/riscv-dv/work/common_defines.vh",
                 "tools/riscv-dv/work/el2_param.vh", "tools/riscv-dv/work/el2_pdef.vh",
                 "design/include/el2_def.sv", "design/lib/beh_lib.sv",
                 "design/lib/el2_lib.sv",
                 "design/ifu/el2_ifu_bp_ctl.sv"]
        inputs = {name: sha(cpu_root / name) for name in names}
        tb = Path(__file__).with_name("test_prediction_ports.sv")
        inputs["test_prediction_ports.sv"] = sha(tb)
        build_dir = results / "build"
        command = [tool, "--binary", "--timing", "--top-module", "cpu_eval_prediction_ports",
                   "-Wno-fatal", "-j", "1", "--threads", "1", "-I" + str(include),
                   "--Mdir", str(build_dir),
                   str(include / "common_defines.vh"),
                   *[str(cpu_root / name) for name in names[3:]], str(tb)]
        record.update(tool=tool, version=version, inputs=inputs, build_command=command)
        with (results / "build.log").open("wb") as log:
            built = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        record["build_exit"] = built.returncode
        if built.returncode:
            sys.stderr.write((results / "build.log").read_text(errors="replace"))
            record["reason"] = "unit elaboration or compilation failed"
        else:
            binary = build_dir / "Vcpu_eval_prediction_ports"
            record["binary_sha256"] = sha(binary)
            run = subprocess.run([str(binary)], capture_output=True, timeout=10)
            output = run.stdout + run.stderr
            (results / "run.log").write_bytes(output)
            record.update(run_exit=run.returncode, run_log_sha256=hashlib.sha256(output).hexdigest())
            if run.returncode in (124, 137, 143, -9, -15):
                record.update(invalid=True, reason="unit execution was interrupted")
            elif run.returncode == 0 and b"PASS prediction public ports" in output:
                record.update(status=0, reason="all directed public-port observations passed")
            elif (b"PREDICTION_FUNCTION_MISMATCH " in output
                  and b"test_prediction_ports.sv:" in output
                  and b"Assertion failed in cpu_eval_prediction_ports" in output):
                record.update(status=1, reason="explicit public-port functional assertion failed")
            elif (b"test_prediction_ports.sv:" in output
                  and b"Assertion failed in cpu_eval_prediction_ports" in output
                  and any(message in output for message in (
                      b"learned lookup was not observed within diagnostic budget",
                      b"history restoration was not observed within diagnostic budget",
                      b"retired branch repair was not observed within diagnostic budget"))):
                record.update(status=1, reason="public-port observation reached its cycle limit")
            else:
                record["reason"] = "unit did not complete valid directed observations"
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        record.update(invalid=True, reason=str(error))
    (results / "prediction_ports.json").write_text(json.dumps(record, indent=2) + "\n")
    (results / "prediction_ports.status").write_text(str(record["status"]) + "\n")
    print(json.dumps(record))
    if record.get("invalid"):
        print("CPU_EVAL_INVALID: " + record["reason"])
    return record


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu-root", type=Path, default=Path.cwd())
    parser.add_argument("--results", type=Path,
                        default=Path(os.environ.get("CPU_EVAL_RESULTS_DIR", "cpu-eval-results")) / "prediction_ports")
    args = parser.parse_args()
    try:
        status = evaluate(args.cpu_root, args.results)["status"]
    except (OSError, ValueError) as error:
        print("CPU_EVAL_INVALID: prediction unit environment error: " + str(error), file=sys.stderr)
        status = 2
    raise SystemExit(status)
