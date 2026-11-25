"""Observe PIC load size through the fixed address-check ports."""
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
    config = root / "tools/riscv-dv/work"
    include = root / "design/include"
    bench = Path(__file__).with_name("addrcheck_port_probe.sv")
    sources = [config / "common_defines.vh", include / "el2_def.sv",
               root / "design/lib/beh_lib.sv", root / "design/lsu/el2_lsu_addrcheck.sv", bench]
    version = subprocess.check_output(["verilator", "--version"], text=True).strip()
    if " 5.036 " not in version:
        raise ValueError("Address-check probe requires Verilator 5.036")
    with tempfile.TemporaryDirectory(prefix="cpu-eval-addrcheck-ports-") as temporary:
        build = Path(temporary)
        executable = build / "Vaddrcheck_port_probe"
        command = ["verilator", "--binary", "--timing", "-Wno-fatal", "-CFLAGS", "-g0",
                   "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--top-module", "addrcheck_port_probe",
                   "--Mdir", str(build), "-I" + str(config), "-I" + str(include), *map(str, sources)]
        build_log = results / "addrcheck_port_build.log"
        with build_log.open("w") as stream:
            compiled = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                      timeout=120, env=dict(os.environ, CCACHE_DISABLE="1"))
        if compiled.returncode:
            print(build_log.read_text(), end="")
            return 2
        run_log = results / "addrcheck_port_probe.log"
        with run_log.open("w") as stream:
            simulated = subprocess.run([str(executable)], stdout=stream, stderr=subprocess.STDOUT, timeout=10)
        captured = run_log.read_text()
        (results / "addrcheck_port_inputs.json").write_text(json.dumps({
            "tool": version,
            "sources": {str(path): sha256(path.read_bytes()).hexdigest()
                        for path in [*sources, config / "el2_param.vh", config / "el2_pdef.vh"]},
            "scope": "Default configured PIC load access flags",
            "simulation_exit_code": simulated.returncode,
        }, indent=2) + "\n")
        print(captured, end="")
        lines = captured.splitlines()
        if any(line.startswith("ADDRCHECK_PORT_MISMATCH:") for line in lines):
            return 1
        if simulated.returncode or lines.count("ADDRCHECK_PORT_PASS") != 1:
            return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"CPU_EVAL_INVALID: Address-check probe: {error}")
        raise SystemExit(2)
