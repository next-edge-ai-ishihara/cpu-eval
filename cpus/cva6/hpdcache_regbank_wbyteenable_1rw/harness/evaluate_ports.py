#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Grade the register bank's writes via its public read port."""

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

HERE = Path(__file__).resolve().parent
SHARED = HERE.parents[1] / "harness"
sys.path.insert(0, str(SHARED))
from port_work_directory import port_work_root
from candidate_error import EXTERNAL_STOP


def run(command, cwd, log, limit):
    with log.open("wb") as output:
        process = subprocess.Popen(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            return 124
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("candidate", type=Path)
    candidate = cli.parse_args().candidate.resolve()
    files = {"candidate.sv": candidate.read_bytes(), "tb.sv": (HERE / "regbank_ports_tb.sv").read_bytes()}
    root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    root.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="regbank-ports-", dir=root))
    metadata = {"input_sha256": {name: hashlib.sha256(raw).hexdigest() for name, raw in files.items()}}
    tool = os.environ.get("VERILATOR", "verilator")
    with tempfile.TemporaryDirectory(prefix="regbank-port-build-", dir=port_work_root()) as temporary:
        work = Path(temporary)
        for name, raw in files.items():
            (work / name).write_bytes(raw)
        if run([tool, "--version"], work, logs / "tool.log", 10):
            return 2
        build = [tool, "--binary", "--timing", "--assert", "-Wno-fatal", "-j", "2", "--top-module", "tb",
                 "candidate.sv", "tb.sv"]
        build_code = run(build, work, logs / "build.log", 120)
        metadata.update(build_command=build, build_exit_code=build_code)
        if build_code:
            if build_code not in (124, 137, 143, -9, -15):
                check = subprocess.run(["python3", str(SHARED / "candidate_error.py"), str(logs / "build.log"),
                                        str(work / "candidate.sv"), "--directory", str(work), "--submitted", str(candidate)],
                                       check=False)
                if check.returncode == 1:
                    inputs = logs.rename(root.parent / (logs.name + "-compile-inputs"))
                    for name, raw in files.items():
                        (inputs / name).write_bytes(raw)
                    (inputs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
                    receipt = root / "hpdcache_regbank_wbyteenable_1rw" / logs.name
                    receipt.mkdir(parents=True)
                    shutil.copyfile(inputs / "build.log", receipt / "build.log")
                    shutil.copyfile(receipt / "build.log", receipt / "candidate-compile-error.txt")
                    (receipt / "exit-code.txt").write_text("1\n")
                    print(f"Register bank compiler inputs: {inputs}", flush=True)
                    return 1
            (logs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
            return 2
        runtime = run([str(work / "obj_dir/Vtb")], work, logs / "runtime.log", 10)
        metadata["runtime_exit_code"] = runtime
    raw = (logs / "runtime.log").read_bytes()
    expected = (b"full", b"way-zero", b"way-one", b"separate-bytes", b"mask-zero")
    if runtime != 124 and b"REGBANK_MISMATCH " in raw:
        result = 1
    elif runtime == 0 and b"REGBANK_PORT_TEST_COMPLETE" in raw and tuple(re.findall(rb"(?m)^READ ([^ ]+) ", raw)) == expected:
        result = 0
    elif runtime in EXTERNAL_STOP:
        result = 2
    else:
        result = 1
    metadata["exit_code"] = result
    (logs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(raw.decode(errors="replace"), end="")
    return result


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
