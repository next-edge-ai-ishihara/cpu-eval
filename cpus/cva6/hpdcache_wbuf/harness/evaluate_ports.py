#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the independent CMI write channels on the submitted write buffer."""

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


def git(repository, *command):
    return subprocess.check_output(["git", "-C", repository, *command])


def inputs(submission):
    recipe = json.loads((HERE.parent / "TEST_RECIPE.json").read_bytes())
    cpu = Path(os.environ["CVA6_REPO"])
    submodule = "core/cache_subsystem/hpdcache"
    pin = recipe["source_submodule_revision"]
    if git(cpu, "rev-parse", "HEAD").decode().strip() != recipe["cpu_revision"] or (
            git(cpu, "rev-parse", f"HEAD:{submodule}").decode().strip() != pin):
        raise ValueError("CVA6 checkout or HPDcache gitlink differs from its recorded revision")
    files = {}
    for dependency in recipe["port_test"]["dependencies"]:
        path = Path(dependency["path"])
        raw = git(cpu / submodule, "show", f"{pin}:{path}")
        if sha256(raw).hexdigest() != dependency["sha256"]:
            raise ValueError(f"fixed HPDcache source differs for {path}")
        files[path.name] = raw
    files.update({"candidate.sv": submission.read_bytes(), "tb.sv": (HERE / "wbuf_ports_tb.sv").read_bytes()})
    return files


def run(command, work, output, seconds):
    with output.open("wb") as log:
        return subprocess.run(["timeout", "-k", "5", str(seconds), *command], cwd=work,
                              stdout=log, stderr=subprocess.STDOUT, check=False).returncode


def compile_failure(work, logs, submission, log_root, metadata):
    check = subprocess.run([sys.executable, str(SHARED / "candidate_error.py"), str(logs / "build.log"),
                            str(work / "candidate.sv"), "--directory", str(work), "--submitted", str(submission)],
                           capture_output=True, check=False)
    if metadata["build_exit_code"] not in (124, 137, 143) and check.returncode == 1:
        failure = log_root / MODULE / logs.name
        failure.mkdir(parents=True)
        diagnostic = logs.rename(log_root.parent / (logs.name + "-compile-inputs"))
        (diagnostic / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
        (diagnostic / "candidate.sv").write_bytes(submission.read_bytes())
        for name in ("build.log", "candidate-compile-error.txt"):
            shutil.copyfile(diagnostic / "build.log", failure / name)
        (failure / "exit-code.txt").write_text("1\n")
        print("FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv")
        return 1
    (logs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print("INVALID: WBUF port compilation did not complete")
    return 2


def main(submission):
    files = inputs(submission)
    root = Path(os.environ["CPU_EVAL_LOG_ROOT"]).resolve()
    root.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="wbuf-ports-", dir=root))
    note = {"input_sha256": {name: sha256(raw).hexdigest() for name, raw in files.items()}}
    tool = os.environ.get("VERILATOR", "verilator")
    with tempfile.TemporaryDirectory(prefix="wbuf-port-build-", dir=port_work_root()) as directory:
        work = Path(directory)
        for name, raw in files.items():
            (work / name).write_bytes(raw)
        build = [tool, "--binary", "--timing", "--assert", "-Wno-fatal", "-j", "2", "-I.",
                 "--top-module", "testbench", "--Mdir", "obj", *(name for name in files if name.endswith(".sv"))]
        status = run(build, work, logs / "build.log", 120)
        note.update(build_command=build, build_exit_code=status)
        if status:
            return compile_failure(work, logs, submission, root, note)
        runtime = run([str(work / "obj/Vtestbench")], work, logs / "runtime.log", 10)
    raw = (logs / "runtime.log").read_bytes()
    marks = re.findall(rb"(?m)^MISMATCH (\S+) (\S+)$", raw)
    observations = re.findall(rb"(?m)^OBS (\S+) (\S+) ([01])$", raw)
    status = 2 if runtime in EXTERNAL_STOP else 1
    if not runtime and len(observations) == 27 and all(value == b"1" for _, _, value in observations) and (
            not marks and raw.splitlines().count(b"WBUF_PORT_TEST_COMPLETE") == 1):
        status = 0
    note.update(runtime_exit_code=runtime, exit_code=status)
    (logs / "result.json").write_text(json.dumps(note, indent=2) + "\n")
    print(raw.decode(errors="replace"), end="")
    print(("PASS: WBUF port observations match", "FAIL: WBUF port observations differ",
           "INVALID: WBUF port simulation was stopped from outside")[status])
    return status


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1]).resolve()))
    except (KeyError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
