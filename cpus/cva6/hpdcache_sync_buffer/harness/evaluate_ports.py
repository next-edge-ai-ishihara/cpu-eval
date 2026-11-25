#!/usr/bin/env python3
"""Check synchronization-buffer ports in two widths and both feedthrough modes."""
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

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from candidate_error import EXTERNAL_STOP


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
    root = Path(os.environ.get("CPU_EVAL_LOG_ROOT", tempfile.gettempdir()))
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="sync-ports-", dir=root))
    print(f"SYNC port-test logs: {directory}", flush=True)
    here = Path(__file__).parent
    for source, name in [(args.candidate, "candidate.sv"),
                         (here / "sync_ports_tb.sv", "tb.sv")]:
        shutil.copyfile(source.resolve(), directory / name)
    files = [directory / name for name in
             ["candidate.sv", "tb.sv"]]
    (directory / "inputs.json").write_text(json.dumps(
        {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}, indent=2) + "\n")
    tool = os.environ.get("VERILATOR", "verilator")
    status, timed_out = run([tool, "--version"], directory, "tool", 10)
    if status or timed_out:
        print("INVALID: Verilator is unavailable")
        return 2
    status, timed_out = run([tool, "--binary", "--timing",
        "-Wno-fatal", "-DHPDCACHE_ASSERT_OFF", "-j", "2", "--top-module", "tb",
        "--Mdir", str(directory / "obj"), "candidate.sv", "tb.sv"],
        directory, "build", args.build_timeout)
    if status and not timed_out:
        classification = subprocess.run(["python3", str(here.parent.parent / "harness/candidate_error.py"),
            str(directory / "build.log"), str(directory / "candidate.sv"),
            "--directory", str(directory), "--submitted", str(args.candidate)], check=False)
        if classification.returncode == 1:
            module_logs = root / "hpdcache_sync_buffer"
            module_logs.mkdir(exist_ok=True)
            compile_logs = Path(tempfile.mkdtemp(prefix="sync-ports-", dir=module_logs))
            shutil.copyfile(directory / "build.log", compile_logs / "build.log")
            shutil.copyfile(directory / "build.log", compile_logs / "candidate-compile-error.txt")
            (compile_logs / "exit-code.txt").write_text("1\n")
            shutil.rmtree(directory)
            print(f"SYNC compiler diagnostics: {compile_logs}", flush=True)
            return 1
    if status or timed_out:
        print("INVALID: SYNC port-test build did not complete")
        return 2
    status, timed_out = run([str(directory / "obj/Vtb")], directory, "runtime", args.run_timeout)
    if timed_out:
        print("INVALID: SYNC port-test timed out")
        return 2
    log = (directory / "runtime.log").read_text()
    if re.search(r"(?m)^MISMATCH config=\d+ case=\d+ reason=", log):
        print("FAIL: SYNC external transfer mismatch")
        return 1
    observations = re.findall(r"(?m)^OBS case=(\d+)$", log)
    complete = observations == [str(case) for case in range(2048)] and re.search(
        r"(?m)^SUMMARY configurations=4 cases=2048 errors=0$", log)
    complete = complete and re.search(r"(?m)^SYNC_PORT_TEST_COMPLETE$", log)
    if status in EXTERNAL_STOP:
        print("INVALID: SYNC port-test was stopped from outside")
        return 2
    if status or not complete:
        print("FAIL: SYNC port-test did not complete the fixed observation sequence")
        return 1
    print("PASS: SYNC port-test completed all four configurations")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
