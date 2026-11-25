#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the public upsizer ports in the cv32a60x instruction-cache refill configuration."""

from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import runpy
from tempfile import TemporaryDirectory, mkdtemp


HARNESS = Path(__file__).resolve().parent
sys.path.insert(0, str(HARNESS.parents[3] / "tools/cva6"))
from replace_module import MissingModule, module_text
sys.path.insert(0, str(HARNESS.parents[1] / "harness"))
from candidate_error import EXTERNAL_STOP, ENVIRONMENT_ERROR, missing_module, record_compile_failure
tools = runpy.run_path(str(HARNESS.parents[1] / "instr_scan/harness/evaluate_ports.py"))
CAPACITY, CPU_REV, execute, port_work_root = (
    tools[name] for name in ("CAPACITY", "CPU_REV", "execute", "port_work_root"))


SUBMODULE = "f404e7ebbda8baa4af3729535f520a6b12a06d03"
PACKAGE = "hpdcache_pkg.sv"
PACKAGE_SHA256 = "14761c94905390d548215dc19aed3f80332dbaa7e617fef4c700f47a3dd8bdbf"
PASS = b"PASS: two accepted beats and one early-last beat are ordered"


def evaluate(candidate):
    repo = Path(os.environ["CVA6_REPO"]) / "core/cache_subsystem/hpdcache"
    package = subprocess.check_output(
        ["git", "-C", str(repo), "show", f"{SUBMODULE}:rtl/src/{PACKAGE}"])
    if sha256(package).hexdigest() != PACKAGE_SHA256:
        raise ValueError("HPDcache package differs from the pinned source")
    bench = HARNESS / "upsize_ports_tb.sv"
    inputs = {PACKAGE: package, "candidate.sv": module_text(candidate.read_text(), "hpdcache_data_upsize").encode(), bench.name: bench.read_bytes()}
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY or sum(map(len, inputs.values())) >= CAPACITY:
        raise ValueError("insufficient bounded temporary storage for the upsizer port test")
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    log_root.mkdir(parents=True, exist_ok=True)
    log = Path(mkdtemp(prefix="upsizer-ports-", dir=log_root))
    result = {"cpu_revision": CPU_REV, "source_submodule_revision": SUBMODULE,
              "input_sha256": {name: sha256(data).hexdigest() for name, data in inputs.items()}}
    status = 2
    runtime = b""
    with TemporaryDirectory(prefix="upsizer-ports-", dir=root) as temporary:
        work = Path(temporary)
        for name, data in inputs.items():
            (work / name).write_bytes(data)
        build = execute(["verilator", "--binary", "--timing", "-Wno-fatal", "--top-module", "upsize_ports_tb",
                         "--Mdir", str(work / "obj"), *(str(work / name) for name in inputs)], 120, work)
        (log / "build.log").write_bytes(build.stdout)
        result["build_exit_code"] = build.returncode
        if build.returncode not in (0, *EXTERNAL_STOP) and not ENVIRONMENT_ERROR.search(
                build.stdout.decode(errors="replace")):
            return record_compile_failure("hpdcache_data_upsize", build.stdout,
                                          "the upsizer port testbench did not build with the submission")
        if build.returncode == 0:
            run = execute([str(work / "obj/Vupsize_ports_tb")], 30, work)
            runtime = run.stdout
            result["runtime_exit_code"] = run.returncode
            markers = [line for line in runtime.splitlines() if line.startswith((b"PASS:", b"FAIL:"))]
            if run.returncode == 0 and markers == [PASS]:
                status = 0
            elif run.returncode not in EXTERNAL_STOP:
                status = 1
    (log / "runtime.log").write_bytes(runtime)
    (log / "result.json").write_text(json.dumps(result | {"exit_code": status}, indent=2) + "\n")
    print(runtime.decode(errors="replace"), end="")
    if status == 2:
        print("INVALID: the upsizer port test did not complete", file=sys.stderr)
    return status


if __name__ == "__main__":
    try:
        raise SystemExit(evaluate(Path(sys.argv[1])))
    except MissingModule as error:
        raise SystemExit(missing_module("hpdcache_data_upsize", error))
    except (IndexError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"INVALID: {error}", file=sys.stderr)
        raise SystemExit(2) from error
