#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import subprocess
import tempfile
import time


def limits() -> None:
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024**2, 16 * 1024**2))


def run(command: list[str], log, seconds: int) -> int:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                               start_new_session=True, preexec_fn=limits,
                               env=dict(os.environ, CCACHE_DISABLE="1"))
    try:
        process.communicate(timeout=seconds)
        return process.returncode
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        while group_has_running_members(process.pid):
            time.sleep(0.01)


def group_has_running_members(group: int) -> bool:
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
            if int(fields[2]) == group and int(fields[3]) == group and fields[0] != "Z":
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


def prepare_configuration(root: Path, results: Path) -> Path:
    config = root / "snapshots/default"
    with (results / "dec_port_configuration.log").open("w") as log:
        status = run(["make", "-C", str(root), "-f", "tools/Makefile",
                      "snapshots/default/defines.h"], log, 30)
    required = ("defines.h", "common_defines.vh", "el2_param.vh", "el2_pdef.vh")
    if status or any(not (config / name).is_file() for name in required):
        raise RuntimeError("DEC default configuration generation failed")
    return config


def main() -> int:
    problem = Path(__file__).resolve().parents[1]
    root = Path(os.environ.get("RV_ROOT", Path.cwd())).resolve()
    results = Path(os.environ["CPU_EVAL_RESULTS_DIR"])
    results.mkdir(parents=True, exist_ok=True)
    version = subprocess.run(["verilator", "--version"], capture_output=True, text=True, check=True)
    if " 5.036 " not in version.stdout:
        raise RuntimeError("DEC port test requires Verilator 5.036")
    prompt = (problem / "SPEC.md").read_bytes()
    binding = json.loads((problem / "SPEC_SOURCES.json").read_text())
    if hashlib.sha256(prompt).hexdigest() != binding["prompt_sha256"]:
        raise RuntimeError("DEC prompt differs from its recorded source binding")
    config = prepare_configuration(root, results)
    declaration = prompt.decode().split("## Module declaration", 1)[1].split("```verilog", 1)[1].split(");", 1)[0] + ");\nendmodule\n"
    with tempfile.TemporaryDirectory(prefix="cpu-eval-dec-interface-") as directory:
        interface = Path(directory) / "interface.sv"
        interface.write_text(declaration)
        expanded = Path(directory) / "expanded.sv"
        with expanded.open("w") as log:
            status = run(["verilator", "-E", "-I" + str(config),
                          str(config / "common_defines.vh"), str(interface)], log, 30)
        if status:
            raise RuntimeError("DEC prompt interface preprocessing failed")
        header = expanded.read_text().split("module el2_dec", 1)[1]
        header = re.split(r"\)\s*\(", header, maxsplit=1)[1].split(");", 1)[0]
    declarations, assignments = [], []
    for line in header.splitlines():
        match = re.match(r"^\s*(input|output)\s+(.+)", line.split("//")[0])
        if not match:
            continue
        declaration = match[2].strip().rstrip(",")
        name = re.search(r"(\w+)\s*(?:\[[^\]]+\]\s*)?$", declaration)[1]
        if declaration == name:
            declaration = "logic " + declaration
        declarations.append(declaration + ";")
        if match[1] == "input":
            assignments.append(name + "='0;")
    ports = "\n".join(declarations) + "\ntask automatic zero_inputs;\n"
    ports += "\n".join(assignments) + "\nendtask\n"
    test = Path(__file__).with_name("dec_port_probe.sv")
    config = root / "snapshots/default"
    paths = [config / "common_defines.vh", root / "design/include/el2_def.sv",
             root / "design/lib/beh_lib.sv"]
    paths += [root / "design/dec" / name for name in
              ["el2_dec_ib_ctl.sv", "el2_dec_decode_ctl.sv", "el2_dec_tlu_ctl.sv",
               "el2_dec_gpr_ctl.sv", "el2_dec_pmp_ctl.sv", "el2_dec_trigger.sv", "el2_dec.sv"]]
    if not declarations or any(not path.is_file() for path in paths):
        raise RuntimeError("decoder interface or configured peripheral sources are unavailable")
    with tempfile.TemporaryDirectory(prefix="cpu-eval-decoder-port-") as directory:
        work = Path(directory)
        (work / "dec_ports.svh").write_text(ports)
        command = ["verilator", "--binary", "--timing", "-Wno-fatal", "-CFLAGS", "-g0",
                   "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--top-module", "dec_operand_tb",
                   "--Mdir", str(work / "obj"), "-I" + str(work), "-I" + str(config),
                   "-I" + str(root / "design/include"), "-I" + str(root / "design/dec")]
        command += [str(path) for path in paths] + [str(test)]
        with (results / "dec_port_build.log").open("w") as log:
            build_status = run(command, log, 120)
        if build_status:
            print((results / "dec_port_build.log").read_text(), end="")
            return 2
        size = sum(path.stat().st_size for path in work.rglob("*") if path.is_file())
        if size >= 32 * 1024**2:
            print("DEC port workspace exceeds 32 MiB")
            return 2
        with (results / "dec_port_probe.log").open("w") as log:
            status = run([str(work / "obj/Vdec_operand_tb")], log, 10)
        text = (results / "dec_port_probe.log").read_text()
        (results / "dec_port_inputs.json").write_text(json.dumps({
            "prompt_sha256": binding["prompt_sha256"],
            "test_sha256": hashlib.sha256(test.read_bytes()).hexdigest(),
            "workspace_bytes": size,
            "scope": "109 arithmetic, nonblocking-load, division, CSR, ECALL and illegal instructions; 440 instruction trace fields; one NMI event with four field checks; 32 debug GPR reads and seven debug CSR commands",
            "comparison": "Visible events at supplied interface stages; no private-state comparison",
        }, indent=2) + "\n")
        if "DEC_OPERAND_TIMEOUT:" in text or "DEC_OPERAND_MISMATCH:" in text:
            return 1
        if status or not all(marker in text.splitlines() for marker in ["DEC_OPERAND_PASS: instructions=109 checks=323", "DEC_TRACE_PASS: events=109 checks=440", "DEC_DEBUG_PASS: reads=32", "DEC_CSR_PASS: commands=7", "DEC_INTERRUPT_PASS: events=1 checks=4"]):
            return 2
        print(text, end="")
    return 0


if __name__ == "__main__":
    def terminate(signum, frame):
        print("CPU_EVAL_INVALID: interrupted by signal " + str(signum), flush=True)
        raise SystemExit(2)

    signal.signal(signal.SIGTERM, terminate)
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, KeyError, IndexError, TypeError,
            AttributeError, subprocess.SubprocessError) as error:
        print(f"CPU_EVAL_INVALID: DEC port test: {error}")
        raise SystemExit(2)
