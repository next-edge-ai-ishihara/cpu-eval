#!/usr/bin/env bash
has_cpu_cycle_limit() {
  # The tracer's 0xffffffff is shifted right once by the fixed C++ harness,
  # which prints 2147483647 with %d. Require normal Spike tohost completion.
  python3 - "$1" "$REPO/verif/sim" "$LOG_DIR/cycle-limit-evidence" "${2:-}" <<'PY'
import hashlib, json, os, pathlib, re, subprocess, sys
directory = pathlib.Path(sys.argv[1])
simulation_directory = pathlib.Path(sys.argv[2])
reports = list((directory / "veri-testharness_sim").glob("*.log.iss"))
pattern = re.compile(r"^(.+) \*\*\* FAILED \*\*\* \(tohost = 2147483647\) after ([0-9]+) cycles$", re.M)
for report in reports:
    if sys.argv[4] and report.name != sys.argv[4] + ".iss":
        continue
    report_bytes = report.read_bytes()
    text = report_bytes.decode(errors="replace")
    matches = pattern.findall(text)
    if matches and all(int(cycles) > 2000000 for _, cycles in matches):
        spike = directory / "spike_sim" / report.name.removesuffix(".iss")
        spike_runtime = spike.with_name(spike.name + ".iss")
        if not spike.is_file() or not spike_runtime.is_file():
            continue
        elf = (simulation_directory / matches[-1][0]).resolve()
        spike_runtime_bytes = spike_runtime.read_bytes()
        spike_inputs = re.findall(r"(?:^|\s)-l\s+(\S+)", spike_runtime_bytes.decode(errors="replace"))
        if not spike_inputs or (simulation_directory / spike_inputs[-1]).resolve() != elf:
            continue
        try:
            symbols = subprocess.check_output([os.environ.get("CV_SW_PREFIX", "riscv64-unknown-elf-") + "nm", "-B", str(elf)], text=True)
            tohost = next(int(line.split()[0], 16) for line in symbols.splitlines() if line.split()[-1:] == ["tohost"])
        except (OSError, subprocess.CalledProcessError, StopIteration, ValueError):
            continue
        spike_bytes = spike.read_bytes()
        lines = [line for line in spike_bytes.decode(errors="replace").splitlines() if re.match(r"^core\s+[0-9]+:", line)]
        completion = re.search(r"\bmem\s+0x([0-9a-fA-F]+)\s+0x([0-9a-fA-F]+)\s*$", lines[-1]) if lines else None
        if completion and int(completion[1], 16) == tohost and int(completion[2], 16) == 1:
            try:
                destination = pathlib.Path(sys.argv[3]) / directory.name
                destination.mkdir(parents=True, exist_ok=True)
                files = [
                    ("rtl-runtime.log", report, report_bytes),
                    ("spike.log", spike, spike_bytes),
                    ("spike-runtime.log", spike_runtime, spike_runtime_bytes),
                    ("program.elf", elf, elf.read_bytes()),
                    ("symbols.txt", None, symbols.encode()),
                ]
                bindings = []
                for name, source, data in files:
                    saved = destination / name
                    saved.write_bytes(data)
                    if saved.read_bytes() != data:
                        raise OSError("saved cycle-limit evidence differs: " + str(saved))
                    bindings.append({"path": name, "source": str(source) if source else None,
                                     "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
                record = {"simulation_directory": str(simulation_directory), "output_directory": str(directory),
                          "cycle_limit": 2000000, "reported_cycles": [int(cycles) for _, cycles in matches],
                          "tohost_address": tohost, "files": bindings}
                data = (json.dumps(record, indent=2) + "\n").encode()
                saved = destination / "binding.json"
                saved.write_bytes(data)
                if saved.read_bytes() != data:
                    raise OSError("saved cycle-limit binding differs: " + str(saved))
            except OSError as error:
                print("INVALID: cannot retain CPU cycle-limit evidence: " + str(error), file=sys.stderr)
                raise SystemExit(3)
            print("CPU_CYCLE_LIMIT: " + str(report))
            raise SystemExit(0)
raise SystemExit(2)
PY
}
