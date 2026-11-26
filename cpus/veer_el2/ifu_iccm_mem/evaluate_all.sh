#!/usr/bin/env bash
set -euo pipefail

ulimit -c 0
results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPU_EVAL_RESULTS_DIR="$results_dir/arithmetic" bash "$here/../_shared/run_fixed_test.sh"

results_dir="$results_dir/iccm_correction"
mkdir -p "$results_dir"
results_dir="$(cd "$results_dir" && pwd)"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
config=tools/riscv-dv/work
sources=(
  "$config/common_defines.vh"
  design/include/el2_def.sv
  design/lib/beh_lib.sv
  design/lib/mem_lib.sv
  design/ifu/el2_ifu_iccm_mem.sv
  "$here/test/iccm_correction_probe.sv"
)
interface=design/lib/el2_mem_if.sv
verilator --version >"$results_dir/verilator.version"
sha256sum "${sources[@]}" "$interface" "$config/el2_param.vh" "$config/el2_pdef.vh" \
  >"$results_dir/inputs.sha256"
if ! CCACHE_DISABLE=1 verilator --binary --timing -j 1 -Wno-fatal \
  -DTEC_RV_ICG=clockhdr -I"$config" -Idesign/include -CFLAGS -g0 \
  --top-module iccm_correction_probe --Mdir "$build" "${sources[@]:0:2}" \
  "$interface" "${sources[@]:2}" >"$results_dir/build.log" 2>&1; then
  cat "$results_dir/build.log" >&2
  exit 2
fi
if ! timeout --verbose 10 "$build/Viccm_correction_probe" >"$results_dir/probe.log" 2>&1; then
  cat "$results_dir/probe.log" >&2
  exit 2
fi
cat "$results_dir/probe.log"
awk '
  /^ICCM_OK / { pass++ }
  /^ICCM_MISMATCH / { fail++ }
  /^ICCM_DONE / { done++; summary = $0 }
  END {
    if (pass + fail != 3 || done != 1 ||
        summary != sprintf("ICCM_DONE passed=%d failed=%d", pass, fail)) exit 2
    if (fail) exit 1
  }
' "$results_dir/probe.log"
