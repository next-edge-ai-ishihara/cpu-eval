"""Observe the selected DMA valid register clock enable."""
from hashlib import sha256
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    root = Path.cwd()
    results = Path(os.environ["CPU_EVAL_RESULTS_DIR"])
    results.mkdir(parents=True, exist_ok=True)
    config = root / "snapshots/default"
    include = root / "design/include"
    bench = Path(__file__).with_name("clock_gate_probe.sv")
    sources = [config / "common_defines.vh", include / "el2_def.sv",
               root / "design/lib/beh_lib.sv", bench]
    version = subprocess.check_output(["verilator", "--version"], text=True).strip()
    if " 5.036 " not in version:
        raise ValueError("Clock enable probe requires Verilator 5.036")
    with tempfile.TemporaryDirectory(prefix="cpu-eval-clock-gate-ports-") as temporary:
        build = Path(temporary)
        executable = build / "Vclock_gate_probe"
        command = ["verilator", "--binary", "--timing", "-Wno-fatal", "-CFLAGS", "-g0",
                   "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--top-module", "clock_gate_probe",
                   "--Mdir", str(build), "-I" + str(config), "-I" + str(include), *map(str, sources)]
        build_log = results / "clock_gate_build.log"
        with build_log.open("w") as stream:
            compiled = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                      timeout=120, env=dict(os.environ, CCACHE_DISABLE="1"))
        if compiled.returncode:
            print(build_log.read_text(), end="")
            return 2
        run_log = results / "clock_gate_probe.log"
        with run_log.open("w") as stream:
            simulated = subprocess.run([str(executable)], stdout=stream, stderr=subprocess.STDOUT, timeout=10)
        captured = run_log.read_text()
        (results / "clock_gate_inputs.json").write_text(json.dumps({
            "tool": version,
            "sources": {str(path): sha256(path.read_bytes()).hexdigest()
                        for path in [*sources, config / "el2_param.vh", config / "el2_pdef.vh"]},
            "scope": "Selected DMA buffer clock enable with FPGA optimization",
            "simulation_exit_code": simulated.returncode,
        }, indent=2) + "\n")
        print(captured, end="")
        lines = captured.splitlines()
        if any(line.startswith("CLOCK_GATE_MISMATCH:") for line in lines):
            return 1
        if simulated.returncode or lines.count("CLOCK_GATE_PASS") != 1:
            return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"CPU_EVAL_INVALID: Clock enable probe: {error}")
        raise SystemExit(2)
