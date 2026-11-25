#!/usr/bin/env bash
set -euo pipefail
config_dir="$1"
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
unit_dir="$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-pic-port.XXXXXXXX")" ||
  { printf 'CPU_EVAL_INVALID: cannot create the PIC unit workspace\n' >&2; exit 2; }
trap 'rm -rf "$unit_dir"' EXIT
ulimit -c 0
probe="$(dirname "${BASH_SOURCE[0]}")/pic_port_probe.sv"
build_log="$results_dir/pic_port_build.log"
run_log="$results_dir/pic_port_probe.log"
: >"$run_log"
if ! timeout --verbose 120 verilator --binary --timing -j 4 -Wno-fatal --top-module pic_port_probe \
    --Mdir "$unit_dir/obj" -I"$config_dir" "$config_dir/common_defines.vh" \
    "$RV_ROOT/design/include/el2_def.sv" "$RV_ROOT/design/lib/beh_lib.sv" \
    "$RV_ROOT/design/lib/el2_lib.sv" "$RV_ROOT/design/el2_pic_ctrl.sv" \
    "$probe" >"$build_log" 2>&1; then
  cat "$build_log" >&2
  exit 2
fi
set +e
timeout --verbose 10 "$unit_dir/obj/Vpic_port_probe" >"$run_log" 2>&1
run_status=$?
set -e
if [ "$run_status" -ne 0 ]; then
  cat "$run_log" >&2
  if [ "$run_status" -eq 124 ] || [ "$run_status" -eq 137 ] || [ "$run_status" -eq 143 ]; then
    printf 'CPU_EVAL_INVALID: PIC unit test was interrupted (exit %s)\n' "$run_status" >&2
    exit 2
  fi
  if grep -Fq 'PIC diagnostic watchdog' "$run_log"; then
    exit 2
  fi
  exit 1
fi
if ! grep -Fxq 'PIC_PORT_DIAGNOSTIC_PASS' "$run_log"; then
  cat "$run_log" >&2
  exit 2
fi
cat "$run_log"
