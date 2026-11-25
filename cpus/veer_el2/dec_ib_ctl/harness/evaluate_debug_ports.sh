#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
results="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}/debug-ports"
mkdir -p "$results"
if ! python3 - "$here/../TEST_RECIPE.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path
p = Path(sys.argv[1]).resolve()
records = json.loads(p.read_bytes())["debug_port_check"]["files"]
assert {x["path"] for x in records} == {
    "evaluate_all.sh", "harness/evaluate_debug_ports.sh", "harness/debug_commands.cpp"}
for x in records:
    assert hashlib.sha256((p.parent / x["path"]).read_bytes()).hexdigest() == x["sha256"]
PY
then
  printf 'CPU_EVAL_INVALID: debug port fixture input record is missing or differs\n' >&2
  exit 2
fi
if ! command -v verilator >/dev/null || ! verilator --version | grep -q ' 5\.036 '; then
  printf 'CPU_EVAL_INVALID: debug port check requires Verilator 5.036\n' >&2
  exit 2
fi
for input in configs/veer.config design/include/el2_def.sv design/dec/el2_dec_ib_ctl.sv; do
  if [ ! -f "$input" ]; then
    printf 'CPU_EVAL_INVALID: missing selected-checkout input: %s\n' "$input" >&2
    exit 2
  fi
done
mkdir -p "$results/configuration"
if ! RV_ROOT="$PWD" BUILD_PATH="$results/configuration" configs/veer.config \
     -target=default -set build_axi4 -set reset_vec=0x80000000 -set fpga_optimize=0 \
     >"$results/configuration.log" 2>&1; then
  cat "$results/configuration.log" >&2
  printf 'CPU_EVAL_INVALID: the fixed configuration was not generated\n' >&2
  exit 2
fi
if ! verilator --cc --exe --build -j 2 -Wno-fatal --top-module el2_dec_ib_ctl \
     -I"$results/configuration" -Idesign/include \
     --Mdir "$results/build" design/include/el2_def.sv design/dec/el2_dec_ib_ctl.sv \
     "$here/debug_commands.cpp" >"$results/build.log" 2>&1; then
  cat "$results/build.log" >&2
  exit 2
fi
set +e
"$results/build/Vel2_dec_ib_ctl" >"$results/run.log" 2>&1
status=$?
set -e
cat "$results/run.log"
if [ "$status" -eq 0 ] && grep -qx DEBUG_COMMANDS_PASS "$results/run.log"; then exit 0; fi
if [ "$status" -eq 1 ] && grep -q '^DEBUG_COMMAND_MISMATCH ' "$results/run.log"; then exit 1; fi
exit 2
