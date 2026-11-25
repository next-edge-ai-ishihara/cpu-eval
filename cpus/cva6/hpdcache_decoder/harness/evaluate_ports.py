#!/usr/bin/env python3
"""Compare the decoder outputs at N=1, the width that cv32a60x instantiates."""
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
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools/cva6"))
from replace_module import MissingModule, module_text
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from candidate_error import EXTERNAL_STOP, missing_module


def stop_group(process):
    def running():
        for entry in Path("/proc").iterdir():
            if not entry.name.isdecimal():
                continue
            try:
                fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
                if int(fields[2]) == process.pid and int(fields[3]) == process.pid and fields[0] != "Z":
                    return True
            except (FileNotFoundError, ProcessLookupError):
                continue
            except PermissionError:
                try:
                    if entry.stat().st_uid == os.geteuid():
                        return True
                except FileNotFoundError:
                    continue
        return False
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    while running():
        time.sleep(0.01)
    process.wait()


def run(command, directory, name, timeout):
    with (directory / (name + ".log")).open("wb") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   cwd=directory, start_new_session=True)
        timed_out = False
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
        finally:
            stop_group(process)
    record = {"command": command, "cwd": str(directory),
              "process_returncode": process.returncode, "timed_out": timed_out}
    (directory / (name + ".json")).write_text(json.dumps(record, indent=2) + "\n")
    return process.returncode, timed_out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--build-timeout", type=float, default=120)
    parser.add_argument("--run-timeout", type=float, default=10)
    args = parser.parse_args()
    log_root = os.environ.get("CPU_EVAL_LOG_ROOT")
    root = Path(log_root) if log_root else Path(tempfile.mkdtemp(prefix="decoder-evidence-")) / "runs"
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="decoder-ports-", dir=root))
    print(f"decoder port-test logs: {directory}", flush=True)
    (directory / "candidate.sv").write_text(module_text(args.candidate.read_text(), "hpdcache_decoder"))
    shutil.copyfile(Path(__file__).with_name("decoder_ports_tb.sv"), directory / "tb.sv")
    (directory / "inputs.json").write_text(json.dumps({p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [directory / "candidate.sv", directory / "tb.sv"]}, indent=2) + "\n")
    tool = os.environ.get("VERILATOR", "verilator")
    status, timeout = run([tool, "--version"], directory, "tool", 10)
    if status or timeout:
        return 2
    status, timeout = run([tool, "--binary", "--timing", "--assert", "-Wno-fatal", "-j", "2",
        "--top-module", "tb", "--Mdir", str(directory / "obj"), "candidate.sv", "tb.sv"],
        directory, "build", args.build_timeout)
    if status and not timeout:
        classification = subprocess.run(["python3", str(Path(__file__).parents[2] / "harness/candidate_error.py"),
            str(directory / "build.log"), str(directory / "candidate.sv"), "--directory", str(directory), "--submitted", str(directory / "candidate.sv")], check=False)
        if classification.returncode == 1:
            summary = root / "hpdcache_decoder" / directory.name
            summary.mkdir(parents=True)
            build_log = (directory / "build.log").read_bytes()
            (summary / "build.log").write_bytes(build_log)
            (summary / "candidate-compile-error.txt").write_bytes(build_log)
            (summary / "exit-code.txt").write_text("1\n")
            shutil.rmtree(directory)
            print(f"decoder port compile-error logs: {summary}", flush=True)
            return 1
    if status or timeout:
        return 2
    status, timeout = run([str(directory / "obj/Vtb")], directory, "runtime", args.run_timeout)
    if timeout:
        return 2
    log = (directory / "runtime.log").read_text()
    observations = re.findall(r"(?m)^OBS check=(\d+) ", log)
    complete = (observations == [str(i) for i in range(1, 5)]
        and re.search(r"(?m)^SUMMARY checks=4 errors=0$", log)
        and re.search(r"(?m)^DECODER_PORT_TEST_COMPLETE$", log))
    if status in EXTERNAL_STOP:
        return 2
    return 0 if status == 0 and complete else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MissingModule as error:
        raise SystemExit(missing_module("hpdcache_decoder", error))
    except Exception as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
