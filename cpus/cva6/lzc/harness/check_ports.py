#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check all two-bit lzc inputs in trailing-zero mode."""

from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CPU = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(CPU / "instr_scan/harness"))
from evaluate_ports import CAPACITY, CPU_REV, execute, port_work_root
sys.path.insert(0, str(CPU / "harness"))
from candidate_error import EXTERNAL_STOP


PACKAGE = "vendor/pulp-platform/common_cells/src/cf_math_pkg.sv"
SUCCESS = "PASS: trailing-zero mode at WIDTH=2"


def check(candidate):
    repo = os.environ["CVA6_REPO"]
    root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    root.mkdir(parents=True, exist_ok=True)
    # The driver interprets a runs directory with only the compiler marker as a compile rejection.
    evidence_root = root.parent if root.name == "runs" else root
    evidence = Path(tempfile.mkdtemp(prefix="lzc-ports-", dir=evidence_root))
    bench = Path(__file__).with_name("lzc_ports_tb.sv")
    package = subprocess.check_output(["git", "-C", repo, "show", f"{CPU_REV}:{PACKAGE}"])
    files = {"cf_math_pkg.sv": package, "lzc.sv": candidate.read_bytes(), bench.name: bench.read_bytes()}
    receipt = {"cpu_revision": CPU_REV, "source_path": PACKAGE,
               "input_sha256": {name: sha256(raw).hexdigest() for name, raw in files.items()}}
    work_root = port_work_root()
    if shutil.disk_usage(work_root).free < CAPACITY or sum(map(len, files.values())) >= CAPACITY:
        raise ValueError("LZC port build requires 64 MiB of temporary storage")
    status = 2
    runtime = b"INVALID: bounded LZC port build did not complete\n"
    with tempfile.TemporaryDirectory(prefix="cpu-eval-lzc-ports-", dir=work_root) as temporary:
        work = Path(temporary)
        for name, raw in files.items():
            (work / name).write_bytes(raw)
        argv = ["verilator", "--binary", "--timing", "-Wno-fatal", "--top-module", "lzc_ports_tb",
                "--Mdir", str(work / "obj"), *[str(work / name) for name in files]]
        receipt["build_argv"] = argv
        build = execute(argv, 120, work)
        (evidence / "build.log").write_bytes(build.stdout)
        receipt["build_exit_code"] = build.returncode
        if build.returncode == 0:
            simulation = execute([str(work / "obj/Vlzc_ports_tb")], 30, work)
            runtime = simulation.stdout
            receipt["runtime_exit_code"] = simulation.returncode
            text = runtime.decode(errors="replace")
            if simulation.returncode == 0 and SUCCESS in text:
                status = 0
            elif simulation.returncode not in EXTERNAL_STOP:
                status = 1
        elif build.returncode not in (124, 137, 143, -9, -15):
            classifier = subprocess.run(
                [sys.executable, CPU / "harness/candidate_error.py", evidence / "build.log",
                 work / "lzc.sv", "--directory", work, "--submitted", candidate],
                capture_output=True, check=False,
            )
            if classifier.returncode == 1:
                compile_root = root / "lzc"
                compile_root.mkdir(exist_ok=True)
                compile_log = Path(tempfile.mkdtemp(prefix="lzc-ports-", dir=compile_root))
                for filename in ("build.log", "candidate-compile-error.txt"):
                    (compile_log / filename).write_bytes(build.stdout)
                (compile_log / "exit-code.txt").write_text("1\n")
                status = 1
                runtime = b"FAIL_CANDIDATE_COMPILE: compiler error identifies the submitted lzc\n"
    receipt["exit_code"] = status
    (evidence / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")
    (evidence / "runtime.log").write_bytes(runtime)
    print(runtime.decode(errors="replace"), end="")
    return status


if __name__ == "__main__":
    try:
        raise SystemExit(check(Path(sys.argv[1]).resolve()))
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        print("INVALID: " + str(error))
        raise SystemExit(2)
