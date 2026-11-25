#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$here/../_shared/run_fixed_test.sh"

results="${CPU_EVAL_RESULTS_DIR:?}/async-reset"
mkdir -p "$results"
work="$PWD/tools/riscv-dv/work"
if ! verilator --binary --timing --timescale 1ns/1ps -j 2 -Wno-fatal \
    --top-module rvdffie_reset --Mdir "$work/rvdffie-reset" -I"$work" \
    "$work/common_defines.vh" "$PWD/design/include/el2_def.sv" "$PWD/design/lib/beh_lib.sv" \
    "$here/test/rvdffie_reset.sv" >"$results/build.log" 2>&1; then
    cat "$results/build.log" >&2
    exit 2
fi
if ! timeout --verbose 10 "$work/rvdffie-reset/Vrvdffie_reset" >"$results/simulation.log" 2>&1; then
    cat "$results/simulation.log" >&2
    exit 2
fi
case "$(grep -Ex 'RVDFFIE_RESET_(PASS|FAIL)' "$results/simulation.log" || true)" in
    RVDFFIE_RESET_PASS) exit 0 ;;
    RVDFFIE_RESET_FAIL) cat "$results/simulation.log" >&2; exit 1 ;;
    *) cat "$results/simulation.log" >&2; exit 2 ;;
esac
