#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise issue-stage ports with the pinned CV32A60X design and child modules."""

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
from candidate_error import EXTERNAL_STOP


SUCCESS = "PASS: issue and scoreboard port contract"
TYPE_NAMES = ("branchpredict_sbe_t", "exception_t", "scoreboard_entry_t", "writeback_t",
              "bp_resolve_t", "fu_data_t")
SOURCES = (
    "core/include/config_pkg.sv",
    "core/include/cv32a60x_config_pkg.sv",
    "core/include/build_config_pkg.sv",
    "core/include/riscv_pkg.sv",
    "core/include/ariane_pkg.sv",
    "core/include/cvxif_types.svh",
    "core/ariane_regfile_ff.sv",
    "core/cvxif_issue_register_commit_if_driver.sv",
    "core/raw_checker.sv",
    "core/scoreboard.sv",
    "core/issue_read_operands.sv",
)


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
    log = Path(tempfile.mkdtemp(prefix="issue-stage-ports-", dir=log_root))
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")

    def pinned(path):
        return subprocess.check_output(["git", "-C", str(repo), "show", f"{CPU_REV}:{path}"])

    parent = pinned("core/cva6.sv")
    bench = Path(__file__).with_name("issue_stage_ports_tb.sv")
    sources = {name: pinned(name) for name in SOURCES}
    receipt = {"configuration": "cv32a60x", "cpu_revision": CPU_REV,
               "native_sha256": {name: sha256(body).hexdigest()
                                 for name, body in {"core/cva6.sv": parent, **sources}.items()},
               "candidate_sha256": sha256(candidate.read_bytes()).hexdigest(),
               "testbench_sha256": sha256(bench.read_bytes()).hexdigest()}
    code = 2
    runtime = b"INVALID: bounded issue-stage port test did not complete\n"
    with tempfile.TemporaryDirectory(prefix="cpu-eval-issue-stage-ports-", dir=root) as temporary:
        work = Path(temporary)
        submitted = work / "issue_stage.sv"
        shutil.copyfile(candidate, submitted)
        for name, body in sources.items():
            (work / Path(name).name).write_bytes(body)
        (work / "parent_types.svh").write_text(native_types(parent.decode()))
        receipt["parent_types_sha256"] = sha256((work / "parent_types.svh").read_bytes()).hexdigest()
        argv = ["verilator", "--binary", "--timing", "-Wno-fatal", "--top-module", "issue_stage_ports_tb",
                "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--Mdir", str(work / "obj"), "-I" + str(work),
                *[Path(name).name for name in sources if name.endswith(".sv")],
                str(submitted), str(bench)]
        receipt["build_argv"] = argv
        try:
            build = execute(argv, 120, work)
            (log / "build.log").write_bytes(build.stdout)
            receipt["build_exit_code"] = build.returncode
            if build.returncode not in (0, *EXTERNAL_STOP):
                result = subprocess.run([sys.executable, CPU / "harness/candidate_error.py",
                                         log / "build.log", submitted, "--directory", work,
                                         "--submitted", candidate], check=False)
                if result.returncode == 1:
                    compile_root = log_root / "issue_stage"
                    compile_root.mkdir(exist_ok=True)
                    compile_log = Path(tempfile.mkdtemp(prefix="issue-stage-ports-", dir=compile_root))
                    for filename in ("build.log", "candidate-compile-error.txt"):
                        (compile_log / filename).write_bytes(build.stdout)
                    (compile_log / "exit-code.txt").write_text("1\n")
                    shutil.rmtree(log)
                    print("issue-stage compile-error logs: " + str(compile_log))
                    return 1
            elif build.returncode == 0 and size(work) <= CAPACITY:
                simulation = execute([str(work / "obj/Vissue_stage_ports_tb")], 30, work)
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
