#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

import os
from pathlib import Path
import resource
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def limits():
    resource.setrlimit(resource.RLIMIT_FSIZE, (32 * 1024 * 1024,) * 2)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def observe_dmi_activity(testbench):
    port = b".dmi_active             ()"
    ending = b"endmodule\n"
    if testbench.count(port) != 1 or not testbench.endswith(ending):
        raise ValueError("cannot locate the DMI activity output in the pinned testbench")
    body = b"""
    logic cpu_eval_dmi_active;
    bit cpu_eval_dmi_seen_idle;
    bit cpu_eval_dmi_seen_active;
    always @(negedge core_clk) begin
        if (porst_l && cpu_eval_dmi_active && !cpu_eval_dmi_seen_active) begin
            cpu_eval_dmi_seen_active = 1'b1;
            $display("CPU_EVAL_DMI_ACTIVE=1");
            $fflush();
        end
        if (porst_l && !cpu_eval_dmi_active && !cpu_eval_dmi_seen_idle) begin
            cpu_eval_dmi_seen_idle = 1'b1;
            $display("CPU_EVAL_DMI_ACTIVE=0");
            $fflush();
        end
    end
"""
    return testbench[:-len(ending)].replace(port, b".dmi_active(cpu_eval_dmi_active)") + body + ending


def icache_data_net(tree, core):
    parent, _, instance = core.rpartition(".")
    parents = [cell.get("submodname") for cell in tree.findall("./cells//cell") if cell.get("hier") == parent]
    if len(parents) != 1:
        return None
    for module in tree.findall("./netlist/module"):
        if module.get("name") != parents[0]:
            continue
        matching = [item for item in module.findall(".//instance") if item.get("name") == instance]
        if len(matching) != 1:
            return None
        port = matching[0].find("./port[@name='ic_rd_data']")
        if port is None or len(port) != 1 or port[0].tag != "varref":
            return None
        name = port[0].get("name", "")
        if re.fullmatch(r"[a-zA-Z_][a-zA-Z0-9_$]*", name):
            suffix = parent.removeprefix("el2_veer_wrapper")
            return ("rvtop_wrapper.rvtop" + suffix + "." + name).encode()
    return None


def main():
    compiler = os.environ["CPU_EVAL_REAL_VERILATOR"]
    args = sys.argv[1:]
    builds = "--cc" in args or "--lint-only" in args
    sources = [a for a in args if Path(a).name == "tb_top.sv"]
    if not builds or len(sources) != 1 or "--top-module" not in args:
        return subprocess.call([compiler, *args])
    if args[args.index("--top-module") + 1] != "tb_top":
        return subprocess.call([compiler, *args])
    observe_decoder = os.environ.get("CPU_EVAL_OBSERVER_DEC") == "1"
    ram = Path(os.environ.get("CPU_EVAL_OBSERVER_RAM_ROOT", "/dev/shm"))
    if shutil.disk_usage(ram).free < 64 * 1024 * 1024:
        print("CPU_EVAL_INVALID: trace observer requires 64 MiB free RAM", file=sys.stderr)
        return 2
    with tempfile.TemporaryDirectory(prefix="cpu-eval-wrapper-observer-", dir=ram) as directory:
        work = Path(directory)
        source = Path(sources[0])
        before = source.read_bytes()
        observed = before
        if os.environ.get("CPU_EVAL_OBSERVE_DMI_ACTIVITY") == "1":
            observed = observe_dmi_activity(before)

        def compile_testbench(content):
            if content == before:
                return subprocess.call([compiler, *args])
            adapted = work / "tb_top.sv"
            adapted.write_bytes(content)
            return subprocess.call([compiler, *(str(adapted) if a == sources[0] else a for a in args)])

        xml_args = [a for a in args if a not in sources]
        for option in ("--cc", "--lint-only"):
            if option in xml_args:
                xml_args.remove(option)
        xml_args[xml_args.index("--top-module") + 1] = "el2_veer_wrapper"
        if "--Mdir" in xml_args:
            xml_args[xml_args.index("--Mdir") + 1] = str(work / "obj")
        # Treat top-level interfaces as opaque for hierarchy discovery only.
        xml_args += ["--bbox-unsup", "-Wno-fatal"]
        xml_args += ["--xml-only", "--xml-output", str(work / "hierarchy.xml")]
        result = subprocess.run([compiler, *xml_args], stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=120, preexec_fn=limits)
        if result.returncode:
            return compile_testbench(observed)
        tree = ET.parse(work / "hierarchy.xml")
        modules = {m.get("name"): m.get("origName") for m in tree.findall(".//module")}
        cores = [c.get("hier") for c in tree.findall("./cells//cell")
                 if modules.get(c.get("submodname")) == "el2_veer"]
        if len(cores) != 1 or not cores[0].startswith("el2_veer_wrapper."):
            return compile_testbench(observed)
        suffix = cores[0][len("el2_veer_wrapper."):]
        prefix = ("rvtop_wrapper.rvtop." + suffix).encode()
        after = re.sub(rb"\brvtop_wrapper\.rvtop\.veer\b", lambda _: prefix, observed)
        if observe_decoder:
            decoders = [c.get("hier") for c in tree.findall("./cells//cell")
                        if modules.get(c.get("submodname")) == "el2_dec"
                        and c.get("hier", "").startswith(cores[0] + ".")]
            if len(decoders) != 1:
                print("FAIL: trace observer finds no single el2_dec instance in the submitted core", file=sys.stderr)
                return 2
            decoder_prefix = ("rvtop_wrapper.rvtop." +
                              decoders[0][len("el2_veer_wrapper."):]).encode()
            after = re.sub(rb"\b" + re.escape(prefix) + rb"\.dec\b",
                           lambda _: decoder_prefix, after)
        else:
            # ECC injection must force the connected net, not the core's input port.
            data_net = icache_data_net(tree, cores[0])
            if data_net is not None:
                after = after.replace(b"rvtop_wrapper.rvtop.ic_rd_data", data_net)
        if after != observed:
            print("CPU_EVAL_TRACE_CPU=" + suffix, flush=True)
        return compile_testbench(after)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, ET.ParseError, subprocess.TimeoutExpired) as error:
        print("CPU_EVAL_INVALID: trace observer preparation failed: " + str(error), file=sys.stderr)
        raise SystemExit(2)
