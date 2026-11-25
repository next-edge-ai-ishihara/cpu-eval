#!/usr/bin/env bash
set -euo pipefail
config_dir="$1"
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
unit_dir="$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-dma-axi.XXXXXXXX")" ||
  { printf 'CPU_EVAL_INVALID: cannot create the DMA unit workspace\n' >&2; exit 2; }
trap 'rm -rf "$unit_dir"' EXIT
ulimit -c 0
probe="$(dirname "${BASH_SOURCE[0]}")/dma_axi_probe.sv"
build_log="$results_dir/dma_axi_build.log"
run_log="$results_dir/dma_axi_probe.log"
: >"$run_log"
if ! timeout --verbose 120 verilator --binary --timing -Wno-fatal --top-module dma_axi_probe \
    --Mdir "$unit_dir/obj" -I"$config_dir" "$config_dir/common_defines.vh" \
    "$RV_ROOT/design/include/el2_def.sv" "$RV_ROOT/design/lib/beh_lib.sv" \
    "$RV_ROOT/design/lib/el2_lib.sv" "$RV_ROOT/design/el2_dma_ctrl.sv" \
    "$probe" >"$build_log" 2>&1; then
  cat "$build_log" >&2
  exit 2
fi
set +e
timeout --verbose 10 "$unit_dir/obj/Vdma_axi_probe" >"$run_log" 2>&1
run_status=$?
set -e
if [ "$run_status" -eq 124 ] || [ "$run_status" -eq 137 ] || [ "$run_status" -eq 143 ]; then
  cat "$run_log" >&2
  printf 'CPU_EVAL_INVALID: DMA unit test was interrupted (exit %s)\n' "$run_status" >&2
  exit 2
fi
if grep -Fq 'diagnostic watchdog' "$run_log"; then
  cat "$run_log" >&2
  exit 2
fi
if [ "$run_status" -ne 0 ]; then
  cat "$run_log" >&2
  if grep -Eq '%(Error|Fatal):.*Assertion failed' "$run_log"; then
    exit 1
  fi
  exit 2
fi
if ! grep -Fxq 'DMA_AXI_DIAGNOSTIC_PASS' "$run_log"; then
  cat "$run_log" >&2
  exit 2
fi
cat "$run_log"
