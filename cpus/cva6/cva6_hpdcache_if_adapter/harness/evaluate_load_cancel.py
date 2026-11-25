#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check cancellation of an accepted CV32A60X load at the HPDcache ports."""
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import signal
import subprocess
import sys
import tempfile

SHARED = Path(__file__).resolve().parents[2] / "harness"
sys.path.insert(0, str(SHARED))
from port_work_directory import port_work_root
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP

CORE_REVISION = "6348e9e684678f83b40d0520028513d06b36e7b2"
CACHE_PATH = "core/cache_subsystem/hpdcache"
CACHE_REVISION = "f404e7ebbda8baa4af3729535f520a6b12a06d03"
ADAPTER_PATH = "core/cache_subsystem/cva6_hpdcache_if_adapter.sv"
CORE_PACKAGES = (
    "config_pkg.sv", "cv32a60x_config_pkg.sv", "build_config_pkg.sv",
    "riscv_pkg.sv", "ariane_pkg.sv",
)
LOG_LIMIT = 16 * 1024 * 1024


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args],
                                   env={**os.environ, "GIT_NO_LAZY_FETCH": "1"})


def show(repo, revision, path):
    return git(repo, "show", f"{revision}:{path}")


def excerpt(source, first, last):
    return "".join(source.splitlines(keepends=True)[first - 1:last])


def testbench(core, subsystem, body):
    cpu = core.decode()
    cache = subsystem.decode()
    cfg = excerpt(cpu, 22, 24).replace("parameter ", "localparam ").replace("),", ");")
    assert "cva6_config_pkg::cva6_cfg" in cfg
    cbo = excerpt(cpu, 174, 174)
    assert "cbo_t = logic" in cbo
    cbo = "  typedef " + cbo.split(" = ")[1].strip().removesuffix(",") + " cbo_t;\n"
    types = excerpt(cpu, 205, 227)
    for name in ("dcache_req_i_t", "dcache_req_o_t"):
        pattern = rf"localparam type {name} = struct packed \{{(.*?)\n    \}},"
        types, count = re.subn(pattern, rf"typedef struct packed {{\1\n    }} {name};", types, flags=re.S)
        assert count == 1
    return ('`include "hpdcache_typedef.svh"\nmodule load_cancel_test;\n'
            + cfg + cbo + types + excerpt(cpu, 390, 390)
            + excerpt(cache, 140, 146) + excerpt(cache, 197, 254)
            + excerpt(cache, 263, 270) + body.decode()).encode()


def limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (LOG_LIMIT, LOG_LIMIT))


def execute(command, timeout, directory, log):
    with log.open("wb") as output, subprocess.Popen(
        command, cwd=directory, stdout=output, stderr=subprocess.STDOUT,
        start_new_session=True, preexec_fn=limits,
    ) as process:
        try:
            return process.wait(timeout=timeout)
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass


def run(candidate, log_dir):
    repo = Path(os.environ["CVA6_REPO"])
    cache_repo = repo / CACHE_PATH
    if git(repo, "rev-parse", "HEAD").strip().decode() != CORE_REVISION:
        raise ValueError("CVA6 checkout differs from the pinned revision")
    entry = git(repo, "ls-tree", CORE_REVISION, CACHE_PATH).decode().split()
    if entry != ["160000", "commit", CACHE_REVISION, CACHE_PATH]:
        raise ValueError("HPDcache Git link differs from the pinned revision")
    if git(cache_repo, "rev-parse", "HEAD").strip().decode() != CACHE_REVISION:
        raise ValueError("HPDcache checkout differs from the pinned revision")

    core_inputs = {name: show(repo, CORE_REVISION, f"core/include/{name}") for name in CORE_PACKAGES}
    core_source = show(repo, CORE_REVISION, "core/cva6.sv")
    subsystem = show(repo, CORE_REVISION, "core/cache_subsystem/cva6_hpdcache_subsystem.sv")
    body = Path(__file__).with_name("load_cancel_tb.sv").read_bytes()
    fixed = show(repo, CORE_REVISION, ADAPTER_PATH)
    files = {
        **core_inputs,
        "hpdcache_pkg.sv": show(cache_repo, CACHE_REVISION, "rtl/src/hpdcache_pkg.sv"),
        "hpdcache_typedef.svh": show(cache_repo, CACHE_REVISION, "rtl/include/hpdcache_typedef.svh"),
        "load_cancel_test.sv": testbench(core_source, subsystem, body),
    }
    sources = {**files, "core/cva6.sv": core_source, "subsystem.sv": subsystem,
               "fixture": body, "reference": fixed, "submission": candidate.read_bytes()}
    record = {"core_revision": CORE_REVISION, "cache_revision": CACHE_REVISION,
              "input_sha256": {name: hashlib.sha256(data).hexdigest() for name, data in sources.items()}}

    work_root = port_work_root()
    if shutil.disk_usage(work_root).free < 64 * 1024 * 1024:
        raise ValueError("64 MiB free temporary storage required")
    with tempfile.TemporaryDirectory(prefix="cpu-eval-load-cancel-", dir=work_root) as temporary:
        work = Path(temporary)
        for name, data in files.items():
            (work / name).write_bytes(data)
        (work / "reference.sv").write_bytes(fixed)
        adapter = work / "adapter.sv"
        replace = SHARED.parents[2] / "tools/cva6/replace_module.py"
        integration = subprocess.run([sys.executable, str(replace), "--module", "cva6_hpdcache_if_adapter",
                                      "--base", str(work / "reference.sv"), "--candidate", str(candidate),
                                      "--output", str(adapter)], capture_output=True, timeout=10)
        if integration.returncode == 1:
            return record, 1, "FAIL: the submission does not define cva6_hpdcache_if_adapter"
        integration.check_returncode()
        record["input_sha256"]["adapter.sv"] = hashlib.sha256(adapter.read_bytes()).hexdigest()
        command = ["verilator", "--binary", "--timing", "--assert", "-j", "2", "-Wno-fatal",
                   "--top-module", "load_cancel_test", "--Mdir", "obj", "-I.",
                   *CORE_PACKAGES, "hpdcache_pkg.sv", "adapter.sv", "load_cancel_test.sv"]
        record["build_argv"] = command
        build_log = log_dir / "build.log"
        record["build_exit_code"] = execute(command, 90, work, build_log)
        if record["build_exit_code"] in EXTERNAL_STOP or (record["build_exit_code"] and ENVIRONMENT_ERROR.search(
                build_log.read_text(errors="replace"))):
            return record, 2, "INVALID: load cancellation simulator build was stopped by a tool or resource failure"
        if record["build_exit_code"] != 0:
            return record, 1, "FAIL: load cancellation bench did not build with the submission"

        runtime_log = log_dir / "runtime.log"
        record["runtime_exit_code"] = execute([str(work / "obj/Vload_cancel_test")], 15, work, runtime_log)
        markers = [line for line in runtime_log.read_text(errors="replace").splitlines()
                   if line == "CVA6_LOAD_CANCEL_PASS" or line.startswith("CVA6_LOAD_CANCEL_FAIL: ")]
        if record["runtime_exit_code"] in EXTERNAL_STOP:
            return record, 2, "INVALID: load cancellation simulator was stopped from outside"
        if record["runtime_exit_code"] == 0 and markers == ["CVA6_LOAD_CANCEL_PASS"]:
            return record, 0, "PASS: load cancellation reaches HPDcache for exactly one cycle"
        if len(markers) == 1 and markers[0] != "CVA6_LOAD_CANCEL_PASS":
            return record, 1, "FAIL: " + markers[0].split(": ", 1)[1]
        return record, 1, "FAIL: load cancellation simulator did not report one passing check"


def main():
    candidate = Path(sys.argv[1]).resolve(strict=True)
    log_root = Path(os.environ["CPU_EVAL_LOG_ROOT"])
    log_root.mkdir(parents=True, exist_ok=True)
    log_dir = Path(tempfile.mkdtemp(prefix="load-cancel-", dir=log_root))
    try:
        record, status, message = run(candidate, log_dir)
    except (OSError, ValueError, AssertionError, subprocess.SubprocessError) as error:
        record, status, message = {}, 2, f"INVALID: load cancellation check failed: {error}"
    record.update(exit_code=status, message=message)
    (log_dir / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    (log_dir / "exit-code.txt").write_text(f"{status}\n")
    print(message)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
