#!/usr/bin/env python3
"""Check byte-enable writes through the fixed SRAM macros at the cv32a60x data RAM geometry."""

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
sys.path.insert(0, str(HERE.parents[1] / "harness"))
from candidate_error import EXTERNAL_STOP


def checked_git(repository, *args):
    return subprocess.check_output(["git", "-C", str(repository), *args])


def stage(directory, candidate):
    recipe = json.loads((HERE.parent / "TEST_RECIPE.json").read_bytes())
    cpu = Path(os.environ["CVA6_REPO"])
    submodule = "core/cache_subsystem/hpdcache"
    pin = recipe["source_submodule_revision"]
    cpu_pin = recipe["cpu_revision"]
    if (checked_git(cpu, "rev-parse", "HEAD").decode().strip() != cpu_pin
            or checked_git(cpu, "rev-parse", f"{cpu_pin}:{submodule}").decode().strip() != pin):
        raise ValueError("CVA6 checkout or HPDcache gitlink differs from its recorded revision")
    shutil.copyfile(candidate, directory / "candidate.sv")
    shutil.copyfile(HERE / "sram_ports_tb.sv", directory / "tb.sv")
    dependencies = []
    for entry in recipe["port_test"]["dependencies"]:
        path = Path(entry["path"])
        data = checked_git(cpu / submodule, "show", f"{pin}:{path}")
        if sha256(data).hexdigest() != entry["sha256"]:
            raise ValueError(f"unexpected fixed dependency bytes for {path}")
        (directory / path.name).write_bytes(data)
        if path.suffix == ".sv":
            dependencies.append(path.name)
    inputs = {path.name: sha256(path.read_bytes()).hexdigest() for path in sorted(directory.iterdir())}
    (directory / "inputs.json").write_text(json.dumps(inputs, indent=2) + "\n")
    return dependencies


def run(command, directory, label, seconds):
    with (directory / f"{label}.log").open("wb") as log:
        status = subprocess.run(["timeout", "-k", "5", str(seconds), *command], cwd=directory,
                                stdout=log, stderr=subprocess.STDOUT, check=False).returncode
    receipt = {"command": command, "timeout_seconds": seconds, "process_returncode": status}
    (directory / f"{label}.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return status


def main(candidate):
    root = Path(os.environ["CPU_EVAL_LOG_ROOT"]).resolve()
    root.mkdir(parents=True, exist_ok=True)
    case = Path(tempfile.mkdtemp(prefix="sram-ports-", dir=root.parent))
    print(f"SRAM port-test logs: {case}", flush=True)
    dependencies = stage(case, candidate)
    tool = os.environ.get("VERILATOR", "verilator")
    if run([tool, "--version"], case, "tool", 10):
        return 2
    build = [tool, "--binary", "--timing", "--assert", "-Wno-fatal", "-j", "2",
             "--top-module", "tb", "--Mdir", "obj", "-I.", *dependencies, "candidate.sv", "tb.sv"]
    status = run(build, case, "build", 120)
    if status:
        classified = subprocess.run(
            [sys.executable, str(HERE.parents[1] / "harness/candidate_error.py"),
             str(case / "build.log"), str(case / "candidate.sv"), "--directory", str(case),
             "--submitted", str(candidate)], capture_output=True, text=True, check=False)
        if (status in (124, 137) or classified.returncode != 1
                or not classified.stdout.startswith("FAIL_CANDIDATE_COMPILE:")):
            print(classified.stdout, end="")
            return 2
        receipt = root / MODULE / case.name
        receipt.mkdir(parents=True)
        shutil.copyfile(case / "build.log", receipt / "build.log")
        shutil.copyfile(case / "build.log", receipt / "candidate-compile-error.txt")
        (receipt / "exit-code.txt").write_text("1\n")
        return 1
    status = run([str(case / "obj/Vtb")], case, "runtime", 10)
    if status in EXTERNAL_STOP:
        return 2
    log = (case / "runtime.log").read_text()
    checks = re.findall(r"(?m)^OBS check=(\d+) ecc=(\d+) ", log)
    mismatches = re.findall(r"(?m)^MISMATCH check=(\d+) ecc=(\d+)$", log)
    summaries = re.findall(r"(?m)^SUMMARY observations=3 mismatches=(\d+)$", log)
    if status or checks != [("0", "0"), ("1", "0"), ("2", "0")] or summaries != [str(len(mismatches))]:
        print("FAIL: candidate did not complete the SRAM observations")
        return 1
    if mismatches:
        print("FAIL: SRAM readback or error output differs")
        return 1
    print("PASS: all three SRAM observations match")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(Path(sys.argv[1]).resolve()))
    except (KeyError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
