#!/usr/bin/env python3
"""Check the selected CSR module's halt request and machine counter ports."""
import argparse
import hashlib
import json
import pathlib
import re
import resource
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "harness"))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[4] / "tools/cva6"))
from candidate_error import EXTERNAL_STOP, candidate_error
from replace_module import MissingModule, module_text

REVISION = "6348e9e684678f83b40d0520028513d06b36e7b2"
SOURCES = ["core/include/" + name for name in
           ("config_pkg.sv", "cv32a60x_config_pkg.sv", "riscv_pkg.sv",
            "ariane_pkg.sv", "build_config_pkg.sv", "rvfi_types.svh")]
SOURCES += ["core/cva6.sv", "core/csr_regfile.sv"]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu-repo", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    out = pathlib.Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=False)
    candidate = pathlib.Path(args.candidate).read_bytes()
    result = {"candidate_sha256": sha(candidate), "cpu_revision": REVISION,
              "exit_code": 2, "source_inputs": {}}
    result["runner_sha256"] = sha(pathlib.Path(__file__).read_bytes())
    result["template_sha256"] = sha(pathlib.Path(__file__).with_name("csr_wfi_ports_tb.sv.in").read_bytes())
    try:
        sources = {p: subprocess.check_output(
            ["git", "-C", args.cpu_repo, "show", REVISION + ":" + p]) for p in SOURCES}
        result["source_inputs"] = {p: sha(b) for p, b in sources.items()}
        parent = sources["core/cva6.sv"].decode().splitlines()
        types = []
        for lo, hi, name in [(37, 40, "branchpredict_sbe_t"), (42, 52, "exception_t"),
                             (92, 95, "jvt_t"), (98, 124, "scoreboard_entry_t"),
                             (145, 154, "irq_ctrl_t")]:
            block = "\n".join(parent[lo - 1:hi])
            block = re.sub(r"(?:localparam|parameter) type " + name + r" =", "typedef", block)
            types.append(block.rsplit("},", 1)[0] + "} " + name + ";")
        fixed = sources["core/csr_regfile.sv"].decode()
        declaration = fixed[fixed.index("module csr_regfile"):].split(");", 1)[0]
        connections = {}
        for line in declaration.splitlines():
            if re.match(r"\s*input\s", line):
                name = re.search(r"(\w+)\s*[,]?\s*$", line).group(1)
                connections[name] = "'0"
        connections.update(clk_i="clk", rst_ni="rst_n", time_irq_i="timer_irq",
                           csr_op_i="op", csr_addr_i="addr", csr_wdata_i="wdata",
                           commit_ack_i="commit_ack", csr_rdata_o="rdata")
        connections["halt_csr_o"] = "halt"
        parameters = [".CVA6Cfg(CVA6Cfg)"] + ["." + n + "(" + n + ")" for n in
                      ("exception_t", "jvt_t", "irq_ctrl_t", "scoreboard_entry_t", "rvfi_probes_csr_t")]
        instance = "  csr_regfile #(" + ",".join(parameters) + ") dut (\n"
        instance += ",\n".join("    ." + n + "(" + v + ")" for n, v in connections.items()) + "\n  );"
        template = pathlib.Path(__file__).with_name("csr_wfi_ports_tb.sv.in").read_text()
        bench = template.replace("@@PARENT_TYPES@@", "\n".join(types)).replace("@@INSTANCE@@", instance)
        (out / "testbench.sv").write_text(bench)
        result["testbench_sha256"] = sha(bench.encode())
        result["verilator_version"] = subprocess.check_output(["verilator", "--version"], text=True).strip()
        with tempfile.TemporaryDirectory(prefix="build-", dir=out) as work:
            work = pathlib.Path(work)
            for p in SOURCES[:6]:
                (work / pathlib.Path(p).name).write_bytes(sources[p])
            (work / "candidate.sv").write_text(module_text(candidate.decode(), "csr_regfile"))
            command = ["verilator", "--binary", "--timing", "--assert", "-Wno-fatal",
                       "-Wno-PINMISSING", "-Wno-WIDTH", "--top-module", "csr_wfi_ports_tb",
                       "-I" + str(work)]
            command += [str(work / pathlib.Path(p).name) for p in SOURCES[:5]]
            command += [str(work / "candidate.sv"), str(out / "testbench.sv"),
                        "--Mdir", str(work / "obj"), "-j", "1"]
            result["build_command"] = command
            with (out / "build.log").open("wb") as log:
                built = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            result["build_exit_code"] = built.returncode
            if built.returncode not in (0, *EXTERNAL_STOP):
                identified = candidate_error((out / "build.log").read_text(errors="replace"),
                                             work / "candidate.sv", directory=work,
                                             submitted=work / "candidate.sv")
                result["candidate_compile_error"] = identified
                if identified:
                    result["exit_code"] = 1
            if built.returncode == 0:
                binary = work / "obj/Vcsr_wfi_ports_tb"
                result["simulator_sha256"] = sha(binary.read_bytes())
                result["build_bytes"] = sum(p.stat().st_size for p in work.rglob("*") if p.is_file())
                run = subprocess.run([str(binary)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
                (out / "run.log").write_bytes(run.stdout)
                result["simulation_exit_code"] = run.returncode
                markers = (b"PASS: WFI halt, hold, timer release, repeat and reset",
                           b"PASS: cycle and retired-instruction counter rollover")
                if run.returncode == 0 and all(marker in run.stdout for marker in markers):
                    result["exit_code"] = 0
                elif run.returncode not in EXTERNAL_STOP:
                    result["exit_code"] = 1
    except MissingModule as error:
        result.update(error=str(error), exit_code=1)
    except (OSError, subprocess.SubprocessError, ValueError) as error:
        result["error"] = str(error)
    (out / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    label = {0: "PASS", 1: "FAIL", 2: "INVALID"}[result["exit_code"]]
    print(label + ": CSR public-port halt and counter test; " + str(out / "result.json"))
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
