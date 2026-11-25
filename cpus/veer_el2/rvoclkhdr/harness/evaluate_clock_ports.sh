#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
results="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}/clock-ports"
mkdir -p "$results"
command -v verilator >/dev/null 2>&1 || { printf 'CPU_EVAL_INVALID: verilator is not on PATH\n' >&2; exit 2; }
verilator --version | grep -q ' 5\.036 ' || { printf 'CPU_EVAL_INVALID: Verilator 5.036 is required\n' >&2; exit 2; }
if ! python3 - "$PWD/design/lib/beh_lib.sv" "$here" "$results" <<'PY'
import hashlib, json, re, sys
from pathlib import Path
source, here, results = map(Path, sys.argv[1:])
recipe = json.loads((here.parent / 'TEST_RECIPE.json').read_text())
for entry in recipe['clock_port_files']:
    p = here.parent / entry['path']
    if hashlib.sha256(p.read_bytes()).hexdigest() != entry['sha256']:
        raise SystemExit('CPU_EVAL_INVALID: clock port fixture hash differs: ' + str(p))
text = source.read_text()
def module(name):
    start = re.search(r'(?m)^\s*module\s+' + re.escape(name) + r'\b', text)
    if start is None:
        raise SystemExit('missing clock module: ' + name)
    end = re.search(r'(?m)^\s*endmodule\b[^\n]*', text[start.start():])
    if end is None:
        raise SystemExit('incomplete clock module: ' + name)
    return text[start.start():start.start() + end.end()] + '\n'
header = '\n'.join(text.splitlines()[:14]) + '\n'
# Match the default tec_rv_icg value in the pinned configs/veer.config.
output = header + '`define TEC_RV_ICG clockhdr\n'
output += module('rvoclkhdr') + module('rvclkhdr') + module('`TEC_RV_ICG')
(results / 'clock_modules.sv').write_text(output)
PY
then
  printf '2\n' >"$results/status"
  exit 2
fi
if ! verilator --cc --exe --build -j 2 -Wno-fatal --top-module rvoclkhdr \
  --Mdir "$results/obj_dir" "$results/clock_modules.sv" \
  "$here/clock_gate.cpp" >"$results/build.log" 2>&1; then
  printf '2\n' >"$results/status"
  exit 2
fi
set +e
"$results/obj_dir/Vrvoclkhdr" >"$results/observations.log" 2>&1
port_status=$?
set -e
if [ "$port_status" -eq 0 ] && grep -q '^clock_gate_port_test PASS observations=24$' "$results/observations.log"; then
  printf '0\n' >"$results/status"
  exit 0
fi
if [ "$port_status" -eq 1 ] && grep -q '^clock_observation ' "$results/observations.log"; then
  printf '1\n' >"$results/status"
  exit 1
fi
printf '2\n' >"$results/status"
exit 2
