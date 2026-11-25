#!/usr/bin/env python3
"""Check prefetch request sequence, pending transfer stability and engine throttling."""
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

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from port_work_directory import port_work_root

CPU_REV = "6348e9e684678f83b40d0520028513d06b36e7b2"
HPD_REV = "f404e7ebbda8baa4af3729535f520a6b12a06d03"
CAPACITY = 64 * 1024 * 1024

def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args])

def file_limit():
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 * 1024,) * 2)

def execute(command, timeout, limit_files=False):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True,
                               preexec_fn=file_limit if limit_files else None)
    try:
        output, _ = process.communicate(timeout=timeout)
        return subprocess.CompletedProcess(command, process.returncode, output)
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--module", choices=("hwpf_stride", "hwpf_stride_wrapper"), default="hwpf_stride")
    args = parser.parse_args()
    repo = Path(os.environ["CVA6_REPO"])
    entry = git(repo, "ls-tree", CPU_REV, "core/cache_subsystem/hpdcache").decode().split()
    if entry[:3] != ["160000", "commit", HPD_REV]:
        raise ValueError("recorded CVA6 HPDcache Git link differs")
    hpd = Path(os.environ.get("CVA6_HPDCACHE_REPO", str(repo / "core/cache_subsystem/hpdcache")))
    candidate = args.candidate.read_bytes()
    tb = Path(__file__).with_name("stride_ports_tb.sv").read_bytes()
    sources = {
        "hpdcache_pkg.sv": "rtl/src/hpdcache_pkg.sv",
        "hpdcache_typedef.svh": "rtl/include/hpdcache_typedef.svh",
        "hwpf_stride_pkg.sv": "rtl/src/hwpf_stride/hwpf_stride_pkg.sv",
    }
    if args.module == "hwpf_stride_wrapper":
        sources.update({
            "hwpf_stride.sv": "rtl/src/hwpf_stride/hwpf_stride.sv",
            "hpdcache_prio_1hot_encoder.sv": "rtl/src/common/hpdcache_prio_1hot_encoder.sv",
            "hpdcache_rrarb.sv": "rtl/src/common/hpdcache_rrarb.sv",
            "hpdcache_mux.sv": "rtl/src/common/hpdcache_mux.sv",
            "hwpf_stride_arb.sv": "rtl/src/hwpf_stride/hwpf_stride_arb.sv",
        })
    files = {name: git(hpd, "show", HPD_REV + ":" + path) for name, path in sources.items()}
    files.update({"candidate.sv": candidate, "stride_ports_tb.sv": tb})
    if sum(map(len, files.values())) >= CAPACITY:
        raise ValueError("port input exceeds temporary storage capacity")
    ram_root = port_work_root()
    if shutil.disk_usage(ram_root).free < CAPACITY:
        raise ValueError("64 MiB free temporary storage required")
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix=args.module + "-ports-", dir=log_root))
    result = {"module": args.module, "cpu_revision": CPU_REV, "hpdcache_revision": HPD_REV,
              "candidate_sha256": hashlib.sha256(candidate).hexdigest(),
              "source_paths": sources,
              "input_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
    with tempfile.TemporaryDirectory(prefix="cpu-eval-stride-ports-", dir=ram_root) as temporary:
        work = Path(temporary)
        for name, data in files.items():
            (work / name).write_bytes(data)
        compile_files = [str(work / name) for name in files if name.endswith(".sv")]
        command = ["verilator", "--binary", "--timing", "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0",
                   "-Wno-fatal", "-DHPDCACHE_ASSERT_OFF"]
        if args.module == "hwpf_stride_wrapper":
            command.append("-DTEST_WRAPPER")
        command += ["--top-module", "tb", "-I" + str(work), "--Mdir", str(work / "obj")] + compile_files
        result["build_argv"] = command
        build = execute(command, 120, limit_files=True)
        (log_dir / "build.log").write_bytes(build.stdout)
        result["build_exit_code"] = build.returncode
        result["ram_bytes"] = sum(p.stat().st_size for p in work.rglob("*") if p.is_file())
        if result["ram_bytes"] > CAPACITY or build.returncode:
            result["exit_code"] = 2
            if result["ram_bytes"] <= CAPACITY and build.returncode not in (0, 124, 137, 143, -9, -15):
                classification = subprocess.run(["python3", str(Path(__file__).parents[2] / "harness/candidate_error.py"),
                    str(log_dir / "build.log"), str(work / "candidate.sv"), "--directory", str(work),
                    "--submitted", str(args.candidate)],
                    capture_output=True, check=False)
                if classification.returncode == 1:
                    if args.module == "hwpf_stride":
                        module_logs = log_root / args.module
                        module_logs.mkdir(exist_ok=True)
                        compile_logs = Path(tempfile.mkdtemp(prefix="stride-ports-", dir=module_logs))
                        (compile_logs / "build.log").write_bytes(build.stdout)
                        (compile_logs / "candidate-compile-error.txt").write_bytes(build.stdout)
                        (compile_logs / "exit-code.txt").write_text("1\n")
                        shutil.rmtree(log_dir)
                        print("FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv")
                        print("PORT_RESULT=" + str(compile_logs))
                        return 1
                    result["exit_code"] = 1
            runtime = b"INVALID: bounded prefetch port build did not complete\n"
        else:
            run = execute([str(work / "obj/Vtb")], 30)
            runtime = run.stdout
            result["runtime_exit_code"] = run.returncode
            text = runtime.decode(errors="replace")
            result["exit_code"] = (2 if run.returncode in (124, 137, 143, -9, -15) else
                                  0 if not run.returncode and "FAIL:" not in text and "INVALID:" not in text
                                  and "PASS: external sequence and pending-request stability" in text else 1)
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
