#!/usr/bin/env bash
set -euo pipefail
export RV_ROOT="${RV_ROOT:-$PWD}"
config_dir="${1:-$RV_ROOT/tools/riscv-dv/work}"
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
if ! verilator --version 2>&1 | grep -q ' 5\.036 '; then
  printf 'CPU_EVAL_INVALID: DBG port probe requires Verilator 5.036\n' >&2
  exit 2
fi
unit_dir="$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-dbg-port.XXXXXXXX")" ||
  { printf 'CPU_EVAL_INVALID: cannot create the DBG port workspace\n' >&2; exit 2; }
trap 'rm -rf "$unit_dir"' EXIT
ulimit -c 0
probe="$(dirname "${BASH_SOURCE[0]}")/dbg_port_probe.sv"
build_log="$results_dir/dbg_port_build.log"
run_log="$results_dir/dbg_port_probe.log"
: >"$run_log"
if ! timeout --verbose 120 verilator --binary --timing -Wno-fatal -CFLAGS -g0 \
    -MAKEFLAGS VM_PARALLEL_BUILDS=0 --top-module dbg_port_probe \
    --Mdir "$unit_dir/obj" -I"$config_dir" "$config_dir/common_defines.vh" \
    "$RV_ROOT/design/include/el2_def.sv" "$RV_ROOT/design/lib/beh_lib.sv" \
    "$RV_ROOT/design/lib/el2_lib.sv" "$RV_ROOT/design/dbg/el2_dbg.sv" \
    "$probe" >"$build_log" 2>&1; then
  cat "$build_log" >&2
  exit 2
fi
unit_bytes="$(du -sb "$unit_dir" | cut -f1)"
printf 'DBG_PORT_WORKSPACE_BYTES=%s\n' "$unit_bytes"
if [ "$unit_bytes" -ge 33554432 ]; then
  printf 'FAIL: DBG port probe workspace exceeds 32MiB\n' >&2
  exit 2
fi
set +e
timeout --verbose 10 "$unit_dir/obj/Vdbg_port_probe" >"$run_log" 2>&1
run_status=$?
set -e
if [ "$run_status" -eq 124 ] || [ "$run_status" -eq 137 ] || [ "$run_status" -eq 143 ]; then
  cat "$run_log" >&2
  printf 'CPU_EVAL_INVALID: DBG port probe was interrupted (exit %s)\n' "$run_status" >&2
  exit 2
fi
if [ "$run_status" -eq 0 ] &&
   grep -Eq '^DBG_PORT_DIAGNOSTIC_FAIL: (core reset wait bound|system bus wait bound|debug status wait bound|core command wait bound|abstract completion wait bound|write channel wait bound|write response wait bound|read channel wait bound|read response wait bound|halt request wait bound|resume request wait bound|watchdog)$' "$run_log" &&
   grep -Eq 'dbg_port_probe\.sv:[0-9]+: Verilog \$finish' "$run_log"; then
  cat "$run_log" >&2
  exit 1
fi
if grep -Fq 'DBG_PORT_DIAGNOSTIC_FAIL' "$run_log"; then
  cat "$run_log" >&2
  printf 'FAIL: failure marker without a clean simulator $finish (exit %s)\n' "$run_status" >&2
  exit 2
fi
if [ "$run_status" -ne 0 ]; then
  cat "$run_log" >&2
  if grep -Eq 'dbg_port_probe\.sv:[0-9]+: Assertion failed in dbg_port_probe' "$run_log"; then
    exit 1
  fi
  exit 2
fi
if ! grep -Fxq 'DBG_PORT_DIAGNOSTIC_PASS' "$run_log"; then
  cat "$run_log" >&2
  exit 2
fi
cat "$run_log"
