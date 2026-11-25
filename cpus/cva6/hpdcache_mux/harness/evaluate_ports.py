#!/usr/bin/env python3
"""Compare the mux output for valid binary and one-hot selections."""
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

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from candidate_error import EXTERNAL_STOP


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
    evidence_root = os.environ.get("CPU_EVAL_LOG_ROOT")
    root = Path(evidence_root or tempfile.gettempdir())
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix="mux-ports-", dir=root))
    print(f"mux port-test logs: {directory}", flush=True)
    shutil.copyfile(args.candidate.resolve(), directory / "candidate.sv")
    shutil.copyfile(Path(__file__).with_name("mux_ports_tb.sv"), directory / "tb.sv")
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
            str(directory / "build.log"), str(directory / "candidate.sv"), "--directory", str(directory), "--submitted", str(args.candidate)], check=False)
        if classification.returncode == 1:
            if evidence_root:
                # Keep the compiler inputs separately from the dispatcher's receipt.
                inputs = directory.rename(root.parent / (directory.name + "-compile-inputs"))
                receipt = root / "hpdcache_mux" / directory.name
                receipt.mkdir(parents=True)
                shutil.copyfile(inputs / "build.log", receipt / "build.log")
                shutil.copyfile(receipt / "build.log", receipt / "candidate-compile-error.txt")
                (receipt / "exit-code.txt").write_text("1\n")
                print(f"mux compiler inputs: {inputs}", flush=True)
            return 1
    if status or timeout:
        return 2
    status, timeout = run([str(directory / "obj/Vtb")], directory, "runtime", args.run_timeout)
    if timeout:
        return 2
    log = (directory / "runtime.log").read_text()
    observations = re.findall(r"(?m)^OBS config=(\d+) check=(\d+) ", log)
    expected = {str(i): [str(n) for n in range(1, count + 1)]
                for i, count in enumerate([8, 32, 32, 16, 32, 32, 32, 32, 48, 48, 64, 64, 64, 64, 160, 80, 80, 80, 128, 128])}
    observed = {key: [check for config, check in observations if config == key]
                for key in expected}
    total = sum(map(len, expected.values()))
    complete = (observed == expected and len(observations) == total
        and re.search(rf"(?m)^SUMMARY checks={total} errors=0$", log)
        and re.search(r"(?m)^MUX_PORT_TEST_COMPLETE$", log))
    if status in EXTERNAL_STOP:
        return 2
    return 0 if status == 0 and complete else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
