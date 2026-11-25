"""Check documented CSR readbacks and diagnostic operations at TLU ports."""
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
    bench = Path(__file__).with_name("tlu_csr_probe.sv")
    driver = bench.with_suffix(".cpp")
    sources = [config / "common_defines.vh", include / "el2_def.sv",
               root / "design/lib/beh_lib.sv", root / "design/dec/el2_dec_pmp_ctl.sv",
               root / "design/dec/el2_dec_tlu_ctl.sv", bench, driver]
    version = subprocess.check_output(["verilator", "--version"], text=True).strip()
    if " 5.036 " not in version:
        raise ValueError("TLU CSR probe requires Verilator 5.036")
    with tempfile.TemporaryDirectory(prefix="cpu-eval-tlu-ports-") as temporary:
        build = Path(temporary)
        executable = build / "Vtlu_csr_probe"
        command = ["verilator", "--cc", "--exe", "--build", "-j", "1",
                   "-Wno-fatal", "-Wno-PINMISSING", "-DTEC_RV_ICG=clockhdr", "-CFLAGS", "-g0",
                   "-MAKEFLAGS", "VM_PARALLEL_BUILDS=0", "--top-module", "tlu_csr_probe",
                   "--Mdir", str(build), "-I" + str(config), "-I" + str(include), *map(str, sources)]
        build_log = results / "tlu_csr_build.log"
        with build_log.open("w") as stream:
            compiled = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                      timeout=120, env=dict(os.environ, CCACHE_DISABLE="1"))
        if compiled.returncode:
            print(build_log.read_text(), end="")
            return 2
        run_log = results / "tlu_csr_probe.log"
        with run_log.open("w") as stream:
            simulated = subprocess.run([str(executable)], stdout=stream, stderr=subprocess.STDOUT, timeout=10)
        captured = run_log.read_text()
        (results / "tlu_csr_inputs.json").write_text(json.dumps({
            "tool": version,
            "sources": {str(path): sha256(path.read_bytes()).hexdigest()
                        for path in [*sources, config / "el2_param.vh", config / "el2_pdef.vh",
                                     include / "el2_dec_csr_equ_m.svh"]},
            "scope": "Selected default MFDC and diagnostic CSR ports after the documented halt handshake",
            "simulation_exit_code": simulated.returncode,
        }, indent=2) + "\n")
        print(captured, end="")
        lines = captured.splitlines()
        if simulated.returncode == 1 and any(line.startswith("TLU_CSR_MISMATCH ") for line in lines):
            return 1
        if (simulated.returncode or lines.count("TLU_CSR_PASS") != 1
                or sum(line.startswith("TLU_CSR_OK ") for line in lines) != 11):
            return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"CPU_EVAL_INVALID: TLU CSR probe: {error}")
        raise SystemExit(2)
