#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Run the CSR buffer's flush test with the pinned CVA6 packages."""

from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory, mkdtemp


HARNESS = Path(__file__).resolve().parent
sys.path.insert(0, str(HARNESS.parents[1] / "instr_scan/harness"))
from evaluate_ports import CAPACITY, CPU_REV, execute, port_work_root
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools/cva6"))
from replace_module import MissingModule, module_text
sys.path.insert(0, str(HARNESS.parents[1] / "harness"))
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP, missing_module


def evaluate(candidate):
    repo = Path(os.environ["CVA6_REPO"])
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")
    packages = (
        "config_pkg.sv", "cv32a60x_config_pkg.sv", "build_config_pkg.sv",
        "riscv_pkg.sv", "ariane_pkg.sv",
    )
    inputs = {package: subprocess.check_output(
        ["git", "-C", str(repo), "show", f"{CPU_REV}:core/include/{package}"]
    ) for package in packages}
    bench = HARNESS / "flush_ports_tb.sv"
    inputs.update({"candidate.sv": module_text(candidate.read_text(), "csr_buffer").encode(), bench.name: bench.read_bytes()})
    if sum(map(len, inputs.values())) >= CAPACITY:
        raise ValueError("port test inputs exceed temporary storage capacity")
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    log_root.mkdir(parents=True, exist_ok=True)
    log = Path(mkdtemp(prefix="csr-buffer-flush-", dir=log_root))
    result = {"cpu_revision": CPU_REV,
              "input_sha256": {name: sha256(data).hexdigest() for name, data in inputs.items()}}
    runtime = b""
    with TemporaryDirectory(prefix="csr-buffer-flush-", dir=root) as directory:
        work = Path(directory)
        for name, data in inputs.items():
            (work / name).write_bytes(data)
        build = execute(["verilator", "--binary", "--timing", "-Wno-fatal", "--top-module", "testbench",
                         "--Mdir", str(work / "obj"), *(str(work / name) for name in inputs)], 120, work)
        (log / "build.log").write_bytes(build.stdout)
        result["build_exit_code"] = build.returncode
        status = 2
        if build.returncode not in (0, *EXTERNAL_STOP) and not ENVIRONMENT_ERROR.search(
                build.stdout.decode(errors="replace")):
            status = 1
            runtime = b"FAIL: the CSR buffer flush testbench did not build with the submission\n"
        if build.returncode == 0:
            run = execute([str(work / "obj/Vtestbench")], 30, work)
            runtime = run.stdout
            result["runtime_exit_code"] = run.returncode
            markers = [line for line in runtime.splitlines() if line.startswith((b"PASS:", b"FAIL:"))]
            if run.returncode == 0 and markers == [b"PASS: flush without commit released the CSR buffer"]:
                status = 0
            elif run.returncode not in EXTERNAL_STOP:
                status = 1
    (log / "runtime.log").write_bytes(runtime)
    (log / "result.json").write_text(json.dumps(result | {"exit_code": status}, indent=2) + "\n")
    print(runtime.decode(errors="replace"), end="")
    if status == 2:
        print("INVALID: the CSR buffer flush test did not complete", file=sys.stderr)
    return status


if __name__ == "__main__":
    try:
        raise SystemExit(evaluate(Path(sys.argv[1])))
    except MissingModule as error:
        raise SystemExit(missing_module("csr_buffer", error))
    except (IndexError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"INVALID: {error}", file=sys.stderr)
        raise SystemExit(2) from error
