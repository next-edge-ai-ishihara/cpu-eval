#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
results="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
CPU_EVAL_RESULTS_DIR="$results/arithmetic" bash "$here/../_shared/run_fixed_test.sh"

ports="$results/rvdffs_ports"
mkdir -p "$ports"
build="$(mktemp -d)"
trap 'rm -rf -- "$build"' EXIT
sources=(tools/riscv-dv/work/common_defines.vh design/lib/beh_lib.sv "$here/test/rvdffs_reset_probe.sv")
verilator --version >"$ports/verilator.version"
sha256sum "${sources[@]}" >"$ports/inputs.sha256"
if ! verilator --binary --timing -j 1 -Wno-fatal -DTEC_RV_ICG=clockhdr --top-module rvdffs_reset_probe \
  --Mdir "$build" "${sources[@]}" >"$ports/build.log" 2>&1; then
  cat "$ports/build.log" >&2
  exit 2
fi
if ! timeout --verbose 10 "$build/Vrvdffs_reset_probe" >"$ports/run.log" 2>&1; then
  cat "$ports/run.log" >&2
  exit 2
fi
cat "$ports/run.log"
if grep -q '^RVDFFS_MISMATCH ' "$ports/run.log"; then
  exit 1
fi
test "$(grep -c '^RVDFFS_OK ' "$ports/run.log")" -eq 5 &&
  grep -qx 'RVDFFS_PASS' "$ports/run.log" || exit 2
