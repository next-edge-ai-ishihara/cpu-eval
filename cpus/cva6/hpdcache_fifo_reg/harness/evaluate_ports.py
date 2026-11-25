#!/usr/bin/env python3
"""Check FIFO external transfers in the five cv32a60x depth and feed-through configurations."""
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

CPU_REV = "6348e9e684678f83b40d0520028513d06b36e7b2"
FIFO_V3 = "vendor/pulp-platform/common_cells/src/fifo_v3.sv"
HPDCACHE_REV = "f404e7ebbda8baa4af3729535f520a6b12a06d03"
SYNC_BUFFER = "rtl/src/common/hpdcache_sync_buffer.sv"


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


def preserve_compile_error(directory, root):
    receipt = root / "hpdcache_fifo_reg" / directory.name
    receipt.mkdir(parents=True)
    shutil.copyfile(directory / "build.log", receipt / "build.log")
    shutil.copyfile(receipt / "build.log", receipt / "candidate-compile-error.txt")
    (receipt / "exit-code.txt").write_text("1\n")
    shutil.rmtree(directory)
    print(f"FIFO compile-error logs: {receipt}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--build-timeout", type=float, default=120)
    parser.add_argument("--run-timeout", type=float, default=10)
    args = parser.parse_args()
    if not args.candidate.is_file() or min(args.build_timeout, args.run_timeout) <= 0:
        raise ValueError("a candidate file and positive timeouts are required")
    log_root = os.environ.get("CPU_EVAL_LOG_ROOT")
    root = Path(log_root) if log_root else Path(tempfile.mkdtemp(prefix="fifo-evidence-")) / "runs"
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="fifo-ports-", dir=root))
    print(f"FIFO port-test logs: {directory}", flush=True)
    here = Path(__file__).parent
    (directory / "candidate.sv").write_text(module_text(args.candidate.read_text(), "hpdcache_fifo_reg"))
    shutil.copyfile(here / "fifo_ports_tb.sv", directory / "tb.sv")
    (directory / "hpdcache_sync_buffer.sv").write_bytes(subprocess.check_output(
        ["git", "-C", os.environ["CVA6_REPO"] + "/core/cache_subsystem/hpdcache", "show",
         HPDCACHE_REV + ":" + SYNC_BUFFER]))
    # fifo_v3 is in the CPU file list, so a candidate may instantiate it.
    (directory / "fifo_v3.sv").write_bytes(subprocess.check_output(
        ["git", "-C", os.environ["CVA6_REPO"], "show", CPU_REV + ":" + FIFO_V3]))
    files = [directory / name for name in
             ["candidate.sv", "tb.sv", "hpdcache_sync_buffer.sv", "fifo_v3.sv"]]
    (directory / "inputs.json").write_text(json.dumps(
        {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}, indent=2) + "\n")
    tool = os.environ.get("VERILATOR", "verilator")
    status, timed_out = run([tool, "--version"], directory, "tool", 10)
    if status or timed_out:
        print("INVALID: Verilator is unavailable")
        return 2
    status, timed_out = run([tool, "--binary", "--timing", "--public-flat-rw",
        "-Wno-fatal", "-DHPDCACHE_ASSERT_OFF", "-j", "2", "--top-module", "tb",
        "--Mdir", str(directory / "obj"), "candidate.sv", "hpdcache_sync_buffer.sv", "fifo_v3.sv",
        "tb.sv"],
        directory, "build", args.build_timeout)
    if status and not timed_out:
        classification = subprocess.run(["python3", str(here.parent.parent / "harness/candidate_error.py"),
            str(directory / "build.log"), str(directory / "candidate.sv"),
            "--directory", str(directory), "--submitted", str(directory / "candidate.sv")], check=False)
        if classification.returncode == 1:
            preserve_compile_error(directory, root)
            return 1
    if status or timed_out:
        print("INVALID: FIFO port-test build did not complete")
        return 2
    status, timed_out = run([str(directory / "obj/Vtb")], directory, "runtime", args.run_timeout)
    if timed_out:
        print("INVALID: FIFO port-test timed out")
        return 2
    log = (directory / "runtime.log").read_text()
    if re.search(r"(?m)^MISMATCH config=\d+ cycle=-?\d+ reason=", log):
        print("FAIL: FIFO external transfer mismatch")
        return 1
    observations = re.findall(r"(?m)^OBS config=(\d+) cycle=(\d+) ", log)
    expected = [(str(config), str(cycle)) for cycle in range(2500) for config in range(5)]
    complete = observations == expected and re.search(
        r"(?m)^SUMMARY configurations=5 cycles=2500 observations=12500 errors=0$", log)
    complete = complete and re.search(r"(?m)^FIFO_PORT_TEST_COMPLETE$", log)
    if not status and not complete:
        print("FAIL: candidate did not complete the fixed observation sequence")
        return 1
    if status in EXTERNAL_STOP:
        print("INVALID: FIFO port-test was stopped from outside")
        return 2
    if status:
        print("FAIL: FIFO port-test simulator ended abnormally")
        return 1
    print("PASS: FIFO port-test completed all five configurations")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MissingModule as error:
        raise SystemExit(missing_module("hpdcache_fifo_reg", error))
    except Exception as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
