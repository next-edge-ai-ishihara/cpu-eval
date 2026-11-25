#!/usr/bin/env python3
"""Check write-request and burst-data transfers through external handshakes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools/cva6"))
from replace_module import MissingModule, module_text
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from candidate_error import EXTERNAL_STOP, missing_module

HPDCACHE_REV = "f404e7ebbda8baa4af3729535f520a6b12a06d03"
FIXED_SOURCES = ["rtl/src/common/hpdcache_fifo_reg.sv", "rtl/src/common/hpdcache_fxarb.sv",
                 "rtl/src/common/hpdcache_mux.sv", "rtl/src/common/hpdcache_prio_1hot_encoder.sv",
                 "rtl/src/common/hpdcache_sync_buffer.sv"]


def run(command, directory, name, timeout):
    with (directory / (name + ".log")).open("wb") as log:
        process = subprocess.Popen(command, cwd=directory, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    result = {"command": command, "cwd": str(directory),
              "process_returncode": process.returncode, "timed_out": timed_out}
    (directory / (name + ".json")).write_text(json.dumps(result, indent=2) + "\n")
    return process.returncode, timed_out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--build-timeout", type=float, default=120)
    parser.add_argument("--run-timeout", type=float, default=10)
    args = parser.parse_args()
    if not args.candidate.is_file() or min(args.build_timeout, args.run_timeout) <= 0:
        raise ValueError("a candidate file and positive timeouts are required")
    evidence_root = os.environ.get("CPU_EVAL_LOG_ROOT")
    root = Path(evidence_root or tempfile.gettempdir())
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="write-arbiter-ports-", dir=root))
    print(f"write arbiter port-test logs: {directory}", flush=True)
    here = Path(__file__).parent
    (directory / "candidate.sv").write_text(
        module_text(args.candidate.read_text(), "hpdcache_mem_req_write_arbiter"))
    shutil.copyfile(here / "write_arbiter_ports_tb.sv", directory / "tb.sv")
    files = [directory / "candidate.sv", directory / "tb.sv"]
    # Fixed dependencies come from the pinned HPDcache commit in the CVA6 checkout.
    hpdcache = Path(os.environ["CVA6_REPO"]) / "core/cache_subsystem/hpdcache"
    for source in FIXED_SOURCES:
        target = directory / Path(source).name
        target.write_bytes(subprocess.check_output(
            ["git", "-C", str(hpdcache), "show", HPDCACHE_REV + ":" + source]))
        files.append(target)
    (directory / "inputs.json").write_text(json.dumps(
        {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}, indent=2) + "\n")
    tool = os.environ.get("VERILATOR", "verilator")
    status, timed_out = run([tool, "--version"], directory, "tool", 10)
    if status or timed_out:
        print("INVALID: Verilator is unavailable")
        return 2
    status, timed_out = run([tool, "--binary", "--timing",
        "-Wno-fatal", "-DHPDCACHE_ASSERT_OFF", "-j", "2", "--top-module", "tb",
        "--Mdir", str(directory / "obj"), *[str(p) for p in files]],
        directory, "build", args.build_timeout)
    if status and not timed_out:
        classification = subprocess.run(["python3", str(here.parent.parent / "harness/candidate_error.py"),
            str(directory / "build.log"), str(directory / "candidate.sv"),
            "--directory", str(directory), "--submitted", str(directory / "candidate.sv")], check=False)
        if classification.returncode == 1:
            if evidence_root:
                # Leave only the compile receipt in the dispatcher run tree.
                receipt = root / "hpdcache_mem_req_write_arbiter" / directory.name
                receipt.mkdir(parents=True)
                shutil.copyfile(directory / "build.log", receipt / "build.log")
                shutil.copyfile(receipt / "build.log", receipt / "candidate-compile-error.txt")
                (receipt / "exit-code.txt").write_text("1\n")
                shutil.rmtree(directory)
                print(f"write arbiter compile-error logs: {receipt}", flush=True)
            return 1
    if status or timed_out:
        print("INVALID: write arbiter port-test build did not complete")
        return 2
    status, timed_out = run([str(directory / "obj/Vtb")], directory, "runtime", args.run_timeout)
    if timed_out:
        print("INVALID: write arbiter port-test timed out")
        return 2
    log = (directory / "runtime.log").read_text()
    if re.search(r"(?m)^MISMATCH cycle=\d+ reason=", log):
        print("FAIL: write arbiter external transfer mismatch")
        return 1
    if re.search(r"(?m)^INCOMPLETE ", log):
        print("FAIL: write arbiter reached the fixed 600-cycle observation limit")
        return 1
    observations = re.findall(r"(?m)^OBS cycle=(\d+) ", log)
    complete = observations == [str(cycle) for cycle in range(600)]
    complete = complete and re.search(r"(?m)^SUMMARY cycles=600 requests=24 bursts=24 errors=0$", log)
    complete = complete and re.search(r"(?m)^WRITE_ARBITER_PORT_TEST_COMPLETE$", log)
    if not status and not complete:
        print("FAIL: candidate did not complete the fixed observation sequence")
        return 1
    if status in EXTERNAL_STOP:
        print("INVALID: write arbiter port-test was stopped from outside")
        return 2
    if status:
        print("FAIL: write arbiter port-test simulator ended abnormally")
        return 1
    print("PASS: write arbiter port-test completed 24 requests and bursts with stalls")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MissingModule as error:
        raise SystemExit(missing_module("hpdcache_mem_req_write_arbiter", error))
    except Exception as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
