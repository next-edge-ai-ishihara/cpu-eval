#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import random
import re
import resource
import signal
import subprocess
import tempfile


def main() -> int:
    problem = Path(__file__).resolve().parents[1]
    root = Path(os.environ.get("RV_ROOT", Path.cwd()))
    results = Path(os.environ["CPU_EVAL_RESULTS_DIR"])
    results.mkdir(parents=True, exist_ok=True)
    version = subprocess.run(["verilator", "--version"], capture_output=True, text=True, check=True)
    if " 5.036 " not in version.stdout:
        raise RuntimeError("raw decoder port test requires Verilator 5.036")
    prompt = (problem / "SPEC.md").read_text()
    binding = json.loads((problem / "SPEC_SOURCES.json").read_text())
    if hashlib.sha256(prompt.encode()).hexdigest() != binding["prompt_sha256"]:
        raise RuntimeError("decode test prompt differs from its recorded source binding")
    table = prompt.split(".definition", 1)[1].split(".end", 1)[0]
    definitions = dict(re.findall(r"^\s*([\w.]+)\s*=\s*\[([01.]{32})\]", table, re.M))
    packet = prompt.split("## Dependency declarations", 1)[1].split("```verilog\n", 1)[1].split("```", 1)[0]
    fields = re.findall(r"logic\s+(\w+)\s*;", packet)
    if len(definitions) != 232 or len(fields) != 96 or len(set(fields)) != 96:
        raise RuntimeError("unexpected decode table or packet shape")
    positions = {name: len(fields) - 1 - i for i, name in enumerate(fields)}
    rows = []
    for name, body in re.findall(r"^\s*rv32i\[([^\]]+)\]\s*=\s*\{([^}]*)\}", table, re.M):
        group = re.fullmatch(r"(.*)\{(\d+)-(\d+)\}", name)
        names = [group[1] + str(i) for i in range(int(group[2]), int(group[3]) + 1)] if group else [name]
        asserted = body.split() + ["legal"]
        value = sum(1 << positions[field] for field in asserted)
        for expanded in names:
            pattern = definitions[expanded]
            mask = int("".join("0" if bit == "." else "1" for bit in pattern), 2)
            match = int(pattern.replace(".", "0"), 2)
            rows.append((expanded, mask, match, value))
    if len(rows) != 232 or {row[0] for row in rows} != set(definitions):
        raise RuntimeError("decode rows do not cover the supplied definitions")
    rng = random.Random(999)
    vectors = set()
    for _, mask, match, _ in rows:
        free = (~mask) & 0xFFFFFFFF
        vectors.update((match, match | free))
        for bit in range(32):
            if free & (1 << bit):
                vectors.add(match | (1 << bit))
        for _ in range(16):
            vectors.add(match | (rng.getrandbits(32) & free))
    vectors.update((0, 0xFFFFFFFF))
    vectors.update(rng.getrandbits(32) for _ in range(256))
    checks = []
    recognized = 0
    for inst in sorted(vectors):
        matching = [row for row in rows if inst & row[1] == row[2]]
        expected = 0
        for row in matching:
            expected |= row[3]
        recognized += bool(matching)
        mask = (1 << 96) - 1 if matching else 1 << positions["legal"]
        checks.append(f"{inst:08x}{expected:024x}{mask:024x}")
    source = (root / "design/dec/el2_dec_decode_ctl.sv").read_text()
    module = re.search(r"(?ms)^\s*module\s+el2_dec_dec_ctl\b.*?^\s*endmodule\b[^\n]*", source)
    if module is None:
        print("raw decoder module is unavailable in the installed source")
        return 2
    testbench = """module raw_decode_port_test;
import el2_pkg::*;
logic [31:0] inst;
el2_dec_pkt_t actual;
logic [223:0] vectors [0:VECTOR_COUNT-1];
string vector_file;
el2_dec_dec_ctl dut(.inst(inst),.out(actual));
task automatic check(input logic [31:0] instruction,
                     input logic [95:0] expected, input logic [95:0] mask);
inst=instruction;
#1;
if ((actual & mask) !== (expected & mask)) begin
  $display("RAW_DECODE_MISMATCH inst=%h expected=%h actual=%h mask=%h",instruction,expected,actual,mask);
  $finish;
end
endtask
initial begin
if (!$value$plusargs("vectors=%s",vector_file)) $fatal(1,"missing vectors");
$readmemh(vector_file,vectors);
for (int index=0; index<VECTOR_COUNT; index++)
  check(vectors[index][223:192],vectors[index][191:96],vectors[index][95:0]);
$display("RAW_DECODE_PORT_PASS");
$finish;
end
endmodule
""".replace("VECTOR_COUNT", str(len(checks)))
    def limits() -> None:
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024**2, 16 * 1024**2))
    def run_limited(command: list[str], log, timeout: int) -> int:
        environment = dict(os.environ, CCACHE_DISABLE="1")
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True, preexec_fn=limits, env=environment)
        try:
            process.communicate(timeout=timeout)
            return process.returncode
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
    with tempfile.TemporaryDirectory(prefix="cpu-eval-raw-decode-port-") as workspace:
        work = Path(workspace)
        (work / "decoder.sv").write_text(module.group() + "\n")
        (work / "test.sv").write_text(testbench)
        (work / "vectors.hex").write_text("\n".join(checks) + "\n")
        config = work / "configuration"
        with (results / "configuration.log").open("w") as log:
            configured = subprocess.run(
                ["make", "-C", str(root / "tools/riscv-dv"), f"WORK_DIR={config}",
                 str(config / "defines.h")],
                env=dict(os.environ, RV_ROOT=str(root)), stdout=log, stderr=subprocess.STDOUT,
                timeout=30,
            )
        if configured.returncode or not (config / "el2_pdef.vh").is_file():
            raise RuntimeError("could not generate the VeeR decoder configuration")
        command = ["verilator", "--binary", "--timing", "-Wno-fatal", "-CFLAGS", "-g0",
                   "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--top-module", "raw_decode_port_test",
                   "--Mdir", str(work / "obj"), "-I" + str(config),
                   str(root / "design/include/el2_def.sv"),
                   str(work / "decoder.sv"), str(work / "test.sv")]
        with (results / "raw_decode_port_build.log").open("w") as log:
            build_status = run_limited(command, log, 120)
        if build_status:
            return 2
        size = sum(path.stat().st_size for path in work.rglob("*") if path.is_file())
        if size >= 32 * 1024**2:
            print("raw decoder workspace exceeds 32 MiB")
            return 2
        with (results / "raw_decode_port_probe.log").open("w") as log:
            run_status = run_limited([str(work / "obj/Vraw_decode_port_test"),
                                      "+vectors=" + str(work / "vectors.hex")], log, 10)
        text = (results / "raw_decode_port_probe.log").read_text()
        (results / "raw_decode_port_inputs.json").write_text(json.dumps({
            "prompt_sha256": binding["prompt_sha256"], "patterns": len(rows),
            "vectors": len(vectors), "recognized_vectors": recognized,
            "workspace_bytes": size, "seed": 999,
            "comparison": "All packet fields for recognized inputs; only legal for unrecognized inputs",
        }, indent=2) + "\n")
        if "RAW_DECODE_MISMATCH" in text:
            return 1
        if run_status or "RAW_DECODE_PORT_PASS" not in text.splitlines():
            return 2
        print(text, end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, KeyError, IndexError, subprocess.SubprocessError) as error:
        print(f"CPU_EVAL_INVALID: raw decoder port test: {error}")
        raise SystemExit(2)
