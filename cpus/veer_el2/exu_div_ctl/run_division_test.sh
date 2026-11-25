#!/usr/bin/env bash
set -euo pipefail

problem_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
testbench="$PWD/testbench/tb_top.sv"
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
snapshot=$(mktemp)
cp -- "$testbench" "$snapshot"
trap 'cp -- "$snapshot" "$testbench"; rm -f -- "$snapshot"' EXIT
printf '\n' >>"$testbench"
cat "$problem_dir/test/observe_cancel.sv" >>"$testbench"

bash "$problem_dir/../_shared/run_fixed_test.sh"
test_name="${RISCV_DV_TEST:-riscv_arithmetic_basic_test}"
log="$results_dir/$test_name.log"
status_file="$results_dir/$test_name.status"
raw="$results_dir/$test_name.raw/hdl_sim"
if grep -r -q 'CPU_EVAL_DIV_CANCEL_MISMATCH' "$raw" "$log"; then
    printf '1\n' >"$status_file"
    printf '[FAILED]: a canceled division signaled completion\n'
    exit 1
fi
if ! grep -r -q 'CPU_EVAL_DIV_CANCEL_OBSERVED' "$raw" "$log"; then
    printf '2\n' >"$status_file"
    printf 'FAIL: the fixed workload did not cancel a division in progress\n' >&2
    exit 2
fi
