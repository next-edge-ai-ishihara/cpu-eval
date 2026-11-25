#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Grade the AXI read bridge at its public request and response ports."""

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
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools/cva6"))
from replace_module import MissingModule, module_text
from candidate_error import EXTERNAL_STOP, missing_module


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


def git(checkout, *args):
    return subprocess.check_output(["git", "-C", str(checkout), *args])


def source_inputs(candidate):
    recipe = json.loads((HERE.parent / "TEST_RECIPE.json").read_bytes())
    checkout = Path(os.environ["CVA6_REPO"])
    submodule_path = "core/cache_subsystem/hpdcache"
    submodule = checkout / submodule_path
    pin = recipe["port_test"]["hpdcache_revision"]
    tree = git(checkout, "ls-tree", recipe["cpu_revision"], submodule_path).decode().split()
    if tree != ["160000", "commit", pin, submodule_path]:
        raise ValueError("HPDcache source pin does not match the fixed CVA6 checkout")
    roots = {"cva6": (checkout, recipe["cpu_revision"]), "hpdcache": (submodule, pin)}
    files = {"candidate.sv": module_text(candidate.read_text(), "hpdcache_mem_to_axi_read").encode(), "tb.sv": (HERE / "axi_read_ports_tb.sv").read_bytes()}
    for name, source in recipe["port_test"]["sources"].items():
        repository, revision = roots[source["repository"]]
        content = git(repository, "show", f'{revision}:{source["path"]}')
        if hashlib.sha256(content).hexdigest() != source["sha256"]:
            raise ValueError(f"source digest differs: {name}")
        files[name] = content
    return files


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("candidate", type=Path)
    candidate = cli.parse_args().candidate.resolve()
    files = source_inputs(candidate)
    root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    root.mkdir(parents=True, exist_ok=True)
    logs = Path(tempfile.mkdtemp(prefix="axi-read-ports-", dir=root))
    metadata = {"input_sha256": {name: hashlib.sha256(raw).hexdigest() for name, raw in files.items()}}
    tool = os.environ.get("VERILATOR", "verilator")
    with tempfile.TemporaryDirectory(prefix="axi-read-port-build-", dir=port_work_root()) as temporary:
        work = Path(temporary)
        for name, raw in files.items():
            (work / name).write_bytes(raw)
        if run([tool, "--version"], work, logs / "tool.log", 10):
            return 2
        build = [tool, "--binary", "--timing", "--assert", "-Wno-fatal", "-j", "2", "--top-module", "tb",
                 "+incdir+.", "axi_pkg.sv", "hpdcache_pkg.sv", "candidate.sv", "tb.sv"]
        build_code = run(build, work, logs / "build.log", 120)
        metadata.update(build_command=build, build_exit_code=build_code)
        if build_code:
            if build_code not in (124, 137, 143, -9, -15):
                check = subprocess.run(["python3", str(SHARED / "candidate_error.py"), str(logs / "build.log"),
                                        str(work / "candidate.sv"), "--directory", str(work), "--submitted", str(work / "candidate.sv")],
                                       check=False)
                if check.returncode == 1:
                    receipt = root / "hpdcache_mem_to_axi_read" / logs.name
                    receipt.mkdir(parents=True)
                    shutil.copyfile(logs / "build.log", receipt / "build.log")
                    shutil.copyfile(receipt / "build.log", receipt / "candidate-compile-error.txt")
                    (receipt / "exit-code.txt").write_text("1\n")
                    shutil.rmtree(logs)
                    print(f"AXI read compile-error logs: {receipt}", flush=True)
                    return 1
            (logs / "result.json").write_text(json.dumps(metadata, indent=2) + "\n")
            return 2
        runtime = run([str(work / "obj_dir/Vtb")], work, logs / "runtime.log", 10)
        metadata["runtime_exit_code"] = runtime
    raw = (logs / "runtime.log").read_bytes()
    expected = (b"cacheable-held", b"cacheable-ready", b"okay-held", b"okay-ready", b"slave-error",
                b"uncached-read", b"decode-error", b"exclusive-read", b"exclusive-okay")
    if runtime != 124 and b"BRIDGE_MISMATCH " in raw:
        result = 1
    elif runtime == 0 and b"AXI_READ_PORT_TEST_COMPLETE" in raw and tuple(re.findall(rb"(?m)^(?:AR|R) ([^ ]+) ", raw)) == expected:
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
    except MissingModule as error:
        raise SystemExit(missing_module("hpdcache_mem_to_axi_read", error))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"INVALID: {error}")
        raise SystemExit(2)
