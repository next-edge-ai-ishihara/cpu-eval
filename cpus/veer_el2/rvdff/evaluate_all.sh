#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -uo pipefail

here="$(dirname "${BASH_SOURCE[0]}")"
results="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
ports="$results/rvdff_ports"
mkdir -p "$ports" || { printf 'CPU_EVAL_INVALID: cannot create %s\n' "$ports" >&2; exit 2; }

bash "$here/../_shared/run_fixed_test.sh" || exit "$?"

if ! verilator --binary --timing -j 1 -Wno-fatal --top-module test_rvdff_ports \
    --Mdir "$ports/build" tools/riscv-dv/work/common_defines.vh \
    design/lib/beh_lib.sv "$here/test/test_rvdff_ports.sv" \
    >"$ports/build.log" 2>&1; then
    cat "$ports/build.log" >&2
    exit 2
fi
if ! "$ports/build/Vtest_rvdff_ports" >"$ports/run.log" 2>&1; then
    cat "$ports/run.log" >&2
    exit 2
fi
cat "$ports/run.log"
if grep -q '^RVDFF_PORT_MISMATCH ' "$ports/run.log"; then
    exit 1
fi
grep -qx 'RVDFF_PORT_PASS' "$ports/run.log" || exit 2
