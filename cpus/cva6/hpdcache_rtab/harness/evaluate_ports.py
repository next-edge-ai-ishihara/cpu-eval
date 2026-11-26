#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check replay ordering and rollback payload at replay-table ports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools/cva6"))
from port_work_directory import port_work_root
from replace_module import MissingModule, module_span
from candidate_error import candidate_error, missing_module

CPU_REV = "6348e9e684678f83b40d0520028513d06b36e7b2"
CAPACITY = 64 * 1024 * 1024
COMPLETION = (
    "PASS linked same-line FIFO and commit",
    "PASS older retained request precedes fence after write buffer becomes empty",
    "PASS rollback retains order and updates shared request input way_fetch",
    "PASS two resource releases retire both waiting heads without fixed release-count condition",
)

def limits():
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 * 1024,) * 2)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

def size(path):
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())

def execute(command, timeout, work):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True, preexec_fn=limits)
    deadline = time.monotonic() + timeout
    try:
        while True:
            if size(work) > CAPACITY:
                raise ValueError("port build exceeds 64 MiB temporary storage capacity")
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout)
            try:
                output, _ = process.communicate(timeout=min(0.25, remaining))
                return subprocess.CompletedProcess(command, process.returncode, output)
            except subprocess.TimeoutExpired:
                pass
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    repo = Path(os.environ["CVA6_REPO"])
    submodule = "core/cache_subsystem/hpdcache"
    revision = "f404e7ebbda8baa4af3729535f520a6b12a06d03"
    entry = subprocess.check_output(["git", "-C", str(repo), "ls-tree", CPU_REV, submodule]).decode().split()
    if entry[:3] != ["160000", "commit", revision]:
        raise ValueError("HPDcache Git link differs from the selected revision")
    source_repo = repo / submodule
    if subprocess.check_output(["git", "-C", str(source_repo), "rev-parse", "HEAD"]).decode().strip() != revision:
        raise ValueError("HPDcache checkout is not at the selected revision")
    source_paths = {"hpdcache_pkg.sv": "rtl/src/hpdcache_pkg.sv",
                    "hpdcache_typedef.svh": "rtl/include/hpdcache_typedef.svh",
                    **{"hpdcache_" + name + ".sv": "rtl/src/common/hpdcache_" + name + ".sv"
                       for name in ("prio_1hot_encoder", "rrarb", "fxarb", "mux", "1hot_to_binary")}}
    files = {name: subprocess.check_output(["git", "-C", str(source_repo), "show", revision + ":" + path])
             for name, path in source_paths.items()}
    submission = args.candidate.read_text()
    start, end = module_span(submission, "hpdcache_rtab")
    files["candidate.sv"] = submission[start:end].encode()
    files["rtab_ports_tb.sv"] = Path(__file__).with_name("rtab_ports_tb.sv").read_bytes()
    if sum(map(len, files.values())) >= CAPACITY:
        raise ValueError("port input exceeds temporary storage capacity")
    ram_root = port_work_root()
    if shutil.disk_usage(ram_root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"]) / "hpdcache_rtab"
    log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix="rtab-ports-", dir=log_root))
    result = {"module": "hpdcache_rtab", "cpu_revision": CPU_REV,
              "source_paths": source_paths, "submodule_revision": revision,
              "input_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
    with tempfile.TemporaryDirectory(prefix="cpu-eval-rtab-ports-", dir=ram_root) as temporary:
        work = Path(temporary)
        for name, data in files.items():
            (work / name).write_bytes(data)
        command = ["verilator", "--binary", "--timing", "--assert", "-Wno-fatal",
                   "-I" + str(work),
                   "--top-module", "testbench", "--Mdir", str(work / "obj")]
        command += [str(work / name) for name in files if name.endswith(".sv")]
        result["build_argv"] = command
        build = execute(command, 120, work)
        (log_dir / "build.log").write_bytes(build.stdout)
        result["build_exit_code"] = build.returncode
        result["ram_bytes"] = size(work)
        if result["ram_bytes"] > CAPACITY or build.returncode:
            result["exit_code"] = 2
            if result["ram_bytes"] <= CAPACITY and build.returncode not in (0, 124, 137, 143, -9, -15):
                if candidate_error(build.stdout.decode(errors="replace"), work / "candidate.sv", work,
                                   submitted=work / "candidate.sv"):
                    (log_dir / "candidate-compile-error.txt").write_bytes(build.stdout)
                    (log_dir / "exit-code.txt").write_text("1\n")
                    print("FAIL_CANDIDATE_COMPILE: compiler error identifies the submitted RTAB module")
                    print("PORT_INPUT_SHA256=" + result["input_sha256"]["candidate.sv"])
                    print("PORT_RESULT=" + str(log_dir))
                    return 1
            runtime = b"INVALID: rtab port build did not complete\n"
        else:
            outputs = []
            runs = []
            for mode in range(4):
                run = execute([str(work / "obj/Vtestbench"), "+mode=" + str(mode)], 10, work)
                outputs.append(run.stdout)
                runs.append({"mode": mode, "exit_code": run.returncode,
                             "completion_count": run.stdout.decode(errors="replace").splitlines().count(COMPLETION[mode])})
            runtime = b"".join(outputs)
            result["runtime_results"] = runs
            text = runtime.decode(errors="replace")
            result["exit_code"] = (2 if any(r["exit_code"] in (124, 137, 143, -9, -15) for r in runs)
                                   else 1 if "FAIL " in text or "FAIL:" in text
                                   or any(r["exit_code"] for r in runs)
                                   or any(r["completion_count"] != 1 for r in runs) else 0)
        (log_dir / "runtime.log").write_bytes(runtime)
    (log_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    (log_dir / "exit-code.txt").write_text(str(result["exit_code"]) + "\n")
    print(runtime.decode(errors="replace"), end="")
    print("PORT_RESULT=" + str(log_dir))
    return result["exit_code"]

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MissingModule as error:
        raise SystemExit(missing_module("hpdcache_rtab", error))
    except Exception as error:
        print("INVALID: " + str(error))
        raise SystemExit(2)
