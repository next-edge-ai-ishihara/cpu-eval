#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check selected CVA6 module outputs with the pinned configuration."""
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
from port_work_directory import port_work_root

CPU_REV = "6348e9e684678f83b40d0520028513d06b36e7b2"
CAPACITY = 64 * 1024 * 1024

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
    parser.add_argument("--module", choices=("instr_scan", "ras", "bht", "lfsr"), default="instr_scan")
    args = parser.parse_args()
    repo = Path(os.environ["CVA6_REPO"])
    source_paths = {
        "config_pkg.sv": "core/include/config_pkg.sv",
        "cv32a60x_config_pkg.sv": "core/include/cv32a60x_config_pkg.sv",
        "build_config_pkg.sv": "core/include/build_config_pkg.sv",
        "riscv_pkg.sv": "core/include/riscv_pkg.sv",
        "ariane_pkg.sv": "core/include/ariane_pkg.sv",
    }
    files = {name: subprocess.check_output(["git", "-C", str(repo), "show", CPU_REV + ":" + path])
             for name, path in source_paths.items()}
    files["candidate.sv"] = args.candidate.read_bytes()
    bench_name, success = {
        "ras": ("ras_ports_tb.sv", "PASS: nested calls, coroutine pop then push, and returns"),
        "bht": ("bht_ports_tb.sv", "PASS: both fetch slots and all branch counter states"),
        "lfsr": ("lfsr_ports_tb.sv", "PASS: selected eight-bit LFSR reset, update, and hold"),
        "instr_scan": ("scanner_ports_tb.sv", "PASS: scanner control transfers and signed offsets;"),
    }[args.module]
    bench = Path(__file__).parents[2] / args.module / "harness" / bench_name
    files[bench.name] = bench.read_bytes()
    if sum(map(len, files.values())) >= CAPACITY:
        raise ValueError("port input exceeds temporary storage capacity")
    ram_root = port_work_root()
    if shutil.disk_usage(ram_root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix=f"{args.module}-ports-", dir=log_root))
    result = {"module": args.module, "cpu_revision": CPU_REV,
              "source_paths": source_paths,
              "input_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
    with tempfile.TemporaryDirectory(prefix=f"cpu-eval-{args.module}-ports-", dir=ram_root) as temporary:
        work = Path(temporary)
        for name, data in files.items():
            (work / name).write_bytes(data)
        command = ["verilator", "--binary", "--timing", "-Wno-fatal",
                   "--top-module", "testbench", "--Mdir", str(work / "obj")]
        command += [str(work / name) for name in files]
        result["build_argv"] = command
        build = execute(command, 120, work)
        (log_dir / "build.log").write_bytes(build.stdout)
        result["build_exit_code"] = build.returncode
        result["ram_bytes"] = size(work)
        if result["ram_bytes"] > CAPACITY or build.returncode:
            result["exit_code"] = 2
            if result["ram_bytes"] <= CAPACITY and build.returncode not in (0, 124, 137, 143, -9, -15):
                classification = subprocess.run(["python3", str(Path(__file__).parents[2] / "harness/candidate_error.py"),
                    str(log_dir / "build.log"), str(work / "candidate.sv"), "--directory", str(work),
                    "--submitted", str(args.candidate)],
                    capture_output=True, check=False)
                if classification.returncode == 1:
                    result["exit_code"] = 1
            runtime = b"INVALID: bounded port build did not complete\n"
        else:
            run = execute([str(work / "obj/Vtestbench")], 30, work)
            runtime = run.stdout
            result["runtime_exit_code"] = run.returncode
            text = runtime.decode(errors="replace")
            result["exit_code"] = (2 if run.returncode in (124, 137, 143, -9, -15) else
                                  0 if not run.returncode and "FAIL:" not in text and success in text
                                  else 1)
        if result["exit_code"] == 1 and runtime.startswith(b"INVALID:"):
            runtime = b"FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv\n"
        (log_dir / "runtime.log").write_bytes(runtime)
    (log_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    (log_dir / "exit-code.txt").write_text(str(result["exit_code"]) + "\n")
    print(runtime.decode(errors="replace"), end="")
    print("PORT_RESULT=" + str(log_dir))
    return result["exit_code"]

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print("INVALID: " + str(error))
        raise SystemExit(2)
