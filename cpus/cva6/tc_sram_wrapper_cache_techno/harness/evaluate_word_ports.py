#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the SRAM wrapper at the instruction-cache word width."""

from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory, mkdtemp


HERE = Path(__file__).resolve().parent
CVA6 = HERE.parents[1]
sys.path.insert(0, str(CVA6 / "instr_scan/harness"))
from evaluate_ports import CAPACITY, CPU_REV, execute, port_work_root, size

sys.path.insert(0, str(CVA6 / "harness"))
from candidate_error import EXTERNAL_STOP, candidate_error, missing_module
from replace_module import MissingModule, module_span


MODULE = "tc_sram_wrapper_cache_techno"
SOURCES = {
    "common/local/util/tc_sram_wrapper_cache_techno.sv":
        "c10b2faf922c2d7c49a52f93087bb545077d9c82399c985c2bfdaead0a03b220",
    "vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv":
        "32e9cb89cf89902e9fa566a66f931f6fe00a616cd426ba440b1e634d0caeb607",
}


def check(candidate, checkout, log_root):
    log_root.mkdir(parents=True, exist_ok=True)
    evidence = Path(mkdtemp(prefix="sram-wrapper-word-ports-", dir=log_root.parent))
    receipt = {"revision": CPU_REV, "sources": SOURCES, "candidate_sha256": sha256(candidate.read_bytes()).hexdigest()}
    result = 2
    try:
        ram_root = port_work_root()
        if shutil.disk_usage(ram_root).free < CAPACITY:
            raise ValueError("64 MiB free temporary storage required")
        with TemporaryDirectory(prefix="cpu-eval-sram-wrapper-word-ports-", dir=ram_root) as temporary:
            work = Path(temporary)
            paths = []
            for name, digest in SOURCES.items():
                raw = subprocess.check_output(["git", "-C", str(checkout), "show", f"{CPU_REV}:{name}"], timeout=30)
                if sha256(raw).hexdigest() != digest:
                    raise ValueError("Pinned source SHA mismatch: " + name)
                path = work / Path(name).name
                path.write_bytes(raw)
                paths.append(path)
            replacement = candidate.read_text(errors="replace")
            try:
                start, stop = module_span(replacement, MODULE)
            except MissingModule as error:
                result = missing_module(MODULE, error)
                return result
            model = paths[0].read_text()
            first, last = module_span(model, MODULE)
            paths[0].write_text(model[:first] + replacement[start:stop] + model[last:])
            bench = HERE / "word_ports_tb.sv"
            receipt["bench_sha256"] = sha256(bench.read_bytes()).hexdigest()
            receipt["target_sha256"] = sha256(paths[0].read_bytes()).hexdigest()
            obj = work / "obj"
            build = execute(["verilator", "--binary", "--timing", "-Wno-fatal", "-j", "2",
                             "--top-module", "testbench", "--Mdir", str(obj),
                             *map(str, paths), str(bench)], 120, work)
            (evidence / "build.log").write_bytes(build.stdout)
            receipt["build_exit_code"] = build.returncode
            if size(work) > CAPACITY:
                raise ValueError("Wrapper model exceeds 64 MiB temporary storage capacity")
            if build.returncode not in (0, *EXTERNAL_STOP) and candidate_error(build.stdout.decode(errors="replace"), paths[0], work, candidate):
                scope = log_root / MODULE
                scope.mkdir(parents=True, exist_ok=True)
                marker = Path(mkdtemp(prefix="word-compile-", dir=scope))
                for name in ("candidate-compile-error.txt", "build.log"):
                    (marker / name).write_bytes(build.stdout)
                (marker / "exit-code.txt").write_text("1\n")
                result = 1
                print("FAIL_CANDIDATE_COMPILE: compiler error identifies submitted SRAM wrapper")
            if build.returncode == 0:
                run = execute([str(obj / "Vtestbench")], 30, work)
                (evidence / "runtime.log").write_bytes(run.stdout)
                receipt["runtime_exit_code"] = run.returncode
                text = run.stdout.decode(errors="replace")
                print(text, end="")
                outcomes = [line for line in text.splitlines() if line.startswith(("PASS: ", "FAIL: "))]
                if run.returncode == 0 and outcomes == ["PASS: selected SRAM words"]:
                    result = 0
                elif run.returncode not in EXTERNAL_STOP:
                    result = 1
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        receipt["error"] = str(error)
    finally:
        receipt["exit_code"] = result
        (evidence / "result.json").write_text(json.dumps(receipt, indent=2) + "\n")
        if result == 2:
            print("INVALID: SRAM wrapper port check did not complete")
    return result


if __name__ == "__main__":
    raise SystemExit(check(Path(sys.argv[1]), Path(os.environ["CVA6_REPO"]),
                           Path(os.environ["CPU_EVAL_LOG_ROOT"])))
