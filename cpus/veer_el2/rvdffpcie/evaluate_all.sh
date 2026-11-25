#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CPU_EVAL_RESULTS_DIR="$results_dir/arithmetic" bash "$here/../_shared/run_fixed_test.sh"

results_dir="$results_dir/pc_register"
mkdir -p "$results_dir"
build="$(mktemp -d)"
trap 'rm -rf -- "$build"' EXIT
sources=(tools/riscv-dv/work/common_defines.vh design/lib/beh_lib.sv "$here/test/pc_register_probe.sv")
verilator --version >"$results_dir/verilator.version"
sha256sum "${sources[@]}" >"$results_dir/inputs.sha256"
if ! CCACHE_DISABLE=1 verilator --binary --timing -j 1 -Wno-fatal -CFLAGS -g0 \
    --top-module pc_register_probe --Mdir "$build" "${sources[@]}" >"$results_dir/build.log" 2>&1; then
    cat "$results_dir/build.log" >&2
    exit 2
fi
if ! timeout --verbose 10 "$build/Vpc_register_probe" >"$results_dir/probe.log" 2>&1; then
    cat "$results_dir/probe.log" >&2
    exit 2
fi
cat "$results_dir/probe.log"
awk '
  /^PC_REGISTER_OK / { pass++ }
  /^PC_REGISTER_MISMATCH / { fail++ }
  /^PC_REGISTER_DONE / { done++; summary = $0 }
  END {
    if (pass + fail != 5 || done != 1 ||
        summary != sprintf("PC_REGISTER_DONE passed=%d failed=%d", pass, fail)) exit 2
    if (fail) exit 1
  }
' "$results_dir/probe.log"
