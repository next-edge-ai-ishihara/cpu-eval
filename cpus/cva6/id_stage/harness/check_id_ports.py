#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise ID-stage ports with the pinned CV32A60X design and child modules."""

from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[4]
CPU = ROOT / "cpus/cva6"
sys.path.insert(0, str(CPU / "instr_scan/harness"))
from evaluate_ports import CAPACITY, CPU_REV, execute, port_work_root, size
sys.path.insert(0, str(CPU / "harness"))
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP, record_compile_failure


SUCCESS = "PASS: ID transport, flush, and CV-X-IF stall"
TYPE_NAMES = ("branchpredict_sbe_t", "exception_t", "fetch_entry_t", "jvt_t",
              "scoreboard_entry_t", "irq_ctrl_t", "interrupts_t")


def native_types(parent):
    definitions = []
    for name in TYPE_NAMES:
        [body] = re.findall(rf"(?ms)^\s*(?:localparam|parameter) type {name} = struct packed \{{\n"
                            r"(.*?)^\s*\},?;?[ \t]*$", parent)
        definitions.append(f"typedef struct packed {{\n{body}}} {name};\n")
    return "".join(definitions)


def run_ports(candidate):
    repo = Path(os.environ["CVA6_REPO"]).resolve()
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    log_root.mkdir(parents=True, exist_ok=True)
    log = Path(tempfile.mkdtemp(prefix="id-stage-ports-", dir=log_root))
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")

    def pinned(path):
        return subprocess.check_output(["git", "-C", str(repo), "show", f"{CPU_REV}:{path}"])

    base = pinned("core/id_stage.sv")
    parent = pinned("core/cva6.sv")
    native_flist = pinned("core/Flist.cva6")
    bench = Path(__file__).with_name("id_stage_ports_tb.sv")
    receipt = {"configuration": "cv32a60x", "cpu_revision": CPU_REV,
               "native_sha256": {"id_stage": sha256(base).hexdigest(), "parent": sha256(parent).hexdigest(),
                                 "filelist": sha256(native_flist).hexdigest()},
               "candidate_sha256": sha256(candidate.read_bytes()).hexdigest(),
               "testbench_sha256": sha256(bench.read_bytes()).hexdigest()}
    code = 2
    runtime = b"INVALID: bounded ID-stage port test did not complete\n"
    with tempfile.TemporaryDirectory(prefix="cpu-eval-id-stage-ports-", dir=root) as temporary:
        work = Path(temporary)
        native_source = work / "native.sv"
        native_source.write_bytes(base)
        integrated = work / "id_stage.sv"
        integration = subprocess.run([sys.executable, ROOT / "tools/cva6/replace_module.py", "--module",
                                      "id_stage", "--base", native_source, "--candidate", candidate,
                                      "--output", integrated], capture_output=True)
        if integration.returncode == 1:
            return record_compile_failure("id_stage", integration.stderr,
                                          "the submission does not define id_stage")
        integration.check_returncode()
        (work / "parent_types.svh").write_text(native_types(parent.decode()))
        receipt["integrated_sha256"] = sha256(integrated.read_bytes()).hexdigest()
        receipt["parent_types_sha256"] = sha256((work / "parent_types.svh").read_bytes()).hexdigest()
        marker = b"${CVA6_REPO_DIR}/core/id_stage.sv"
        if native_flist.splitlines().count(marker) != 1:
            raise ValueError("expected one ID-stage source in the pinned CVA6 file list")
        flist = work / "Flist.cva6"
        flist.write_bytes(native_flist.replace(marker, os.fsencode(integrated)))
        os.environ.update(CVA6_REPO_DIR=str(repo), TARGET_CFG="cv32a60x",
                          HPDCACHE_DIR=str(repo / "core/cache_subsystem/hpdcache"))
        argv = ["verilator", "--binary", "--timing", "-Wno-fatal", "--top-module", "id_stage_ports_tb",
                "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--Mdir", str(work / "obj"), "-I" + str(work),
                "-f", str(flist), str(bench)]
        receipt["build_argv"] = argv
        try:
            build = execute(argv, 120, work)
            (log / "build.log").write_bytes(build.stdout)
            receipt["build_exit_code"] = build.returncode
            if build.returncode not in (0, *EXTERNAL_STOP) and size(work) <= CAPACITY and not (
                    ENVIRONMENT_ERROR.search(build.stdout.decode(errors="replace"))):
                return record_compile_failure("id_stage", build.stdout,
                                              "the ID-stage port testbench did not build with the submission")
            if build.returncode == 0 and size(work) <= CAPACITY:
                simulation = execute([str(work / "obj/Vid_stage_ports_tb")], 30, work)
                runtime = simulation.stdout
                receipt["runtime_exit_code"] = simulation.returncode
                lines = runtime.decode(errors="replace").splitlines()
                failures = sum(line.startswith("FAIL: ") for line in lines)
                if simulation.returncode == 0 and lines.count(SUCCESS) == 1 and not failures:
                    code = 0
                elif simulation.returncode not in EXTERNAL_STOP:
                    code = 1
        except (ValueError, OSError, subprocess.TimeoutExpired) as error:
            receipt["error"] = str(error)
    receipt["exit_code"] = code
    (log / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")
    (log / "runtime.log").write_bytes(runtime)
    print(runtime.decode(errors="replace"), end="")
    print("PORT_RESULT=" + str(log))
    return code


if __name__ == "__main__":
    try:
        raise SystemExit(run_ports(Path(sys.argv[1]).resolve()))
    except (IndexError, KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print("INVALID: " + str(error))
        raise SystemExit(2)
