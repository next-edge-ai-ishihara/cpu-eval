#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check byte writes and synchronous read behavior at the SRAM ports."""

from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
MODULE = HERE.parent.name
SHARED = HERE.parents[1] / "harness"
sys.path.insert(0, str(SHARED))
from port_work_directory import port_work_root
from candidate_error import EXTERNAL_STOP

OBSERVATIONS = (
    b"initial-read", b"before-read-edge", b"after-read-edge",
    b"separate-byte-masks", b"deselected-write-keeps-memory",
)


def run(command, work, output, seconds):
    with output.open("wb") as log:
        return subprocess.run(["timeout", "-k", "5", str(seconds), *command], cwd=work,
                              stdout=log, stderr=subprocess.STDOUT, check=False).returncode


def main(submission):
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"]).resolve()
    log_root.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="sram-byte-ports-", dir=log_root))
    inputs = {"candidate.sv": submission.read_bytes(), "tb.sv": (HERE / "sram_byte_ports_tb.sv").read_bytes()}
    metadata = {"input_sha256": {name: sha256(raw).hexdigest() for name, raw in inputs.items()}}
    tool = os.environ.get("VERILATOR", "verilator")
    with tempfile.TemporaryDirectory(prefix="sram-byte-build-", dir=port_work_root()) as scratch:
        work = Path(scratch)
        for name, content in inputs.items():
            (work / name).write_bytes(content)
        build = [tool, "--binary", "--timing", "-Wno-fatal", "-j", "2", "--top-module", "tb",
                 "--Mdir", "obj", *inputs]
        result = run(build, work, logs / "build.log", 120)
        metadata.update(build_command=build, build_exit_code=result)
        if result:
            classified = subprocess.run(
                [sys.executable, str(SHARED / "candidate_error.py"), str(logs / "build.log"),
                 str(work / "candidate.sv"), "--directory", str(work), "--submitted", str(submission)],
                capture_output=True, check=False)
            if result not in (124, 137, 143) and classified.returncode == 1:
                failure = log_root / MODULE / logs.name
                failure.mkdir(parents=True)
                diagnostic = logs.rename(log_root.parent / (logs.name + "-compile-inputs"))
                for name, content in inputs.items():
                    (diagnostic / name).write_bytes(content)
                (diagnostic / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
                shutil.copyfile(diagnostic / "build.log", failure / "build.log")
                shutil.copyfile(diagnostic / "build.log", failure / "candidate-compile-error.txt")
                (failure / "exit-code.txt").write_text("1\n")
                print(f"SRAM byte-port logs: {diagnostic}")
                print("FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv")
                return 1
            (logs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
            print("INVALID: SRAM byte-port compilation did not complete")
            return 2
        runtime = run([str(work / "obj/Vtb")], work, logs / "runtime.log", 10)
    trace = (logs / "runtime.log").read_bytes()
    observations = tuple(re.findall(rb"(?m)^OBS (\S+) expected=[0-9a-f]+ actual=[0-9a-fxz]+$", trace))
    mismatches = re.findall(rb"(?m)^MISMATCH (\S+)$", trace)
    summaries = re.findall(rb"(?m)^SUMMARY observations=5 mismatches=(\d+)$", trace)
    if runtime in EXTERNAL_STOP:
        verdict = 2
    elif runtime or observations != OBSERVATIONS or summaries != [str(len(mismatches)).encode()]:
        verdict = 1
    else:
        verdict = int(bool(mismatches))
    metadata.update(runtime_exit_code=runtime, exit_code=verdict)
    (logs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"SRAM byte-port logs: {logs}")
    print(trace.decode(errors="replace"), end="")
    print(("PASS: SRAM byte-port observations match", "FAIL: SRAM byte-port observations differ",
           "INVALID: SRAM byte-port simulation was stopped from outside")[verdict])
    return verdict


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1]).resolve()))
    except (KeyError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
