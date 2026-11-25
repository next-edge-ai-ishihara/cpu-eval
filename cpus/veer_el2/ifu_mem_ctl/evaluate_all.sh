#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
export RV_ROOT="$PWD"

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
arithmetic_runner="$(dirname "${BASH_SOURCE[0]}")/../_shared/run_fixed_test.sh"
CPU_EVAL_RESULTS_DIR="$results_dir/arithmetic" bash "$arithmetic_runner"

test_name=ifu_fence_i
probe_dir="$results_dir/fence_i"
mkdir -p "$probe_dir"
log="$probe_dir/$test_name.log"

probe_build="$(mktemp -d)"
trap 'rm -rf -- "$probe_build"' EXIT
cp -R testbench "$probe_build/testbench"
patch --batch --forward -d "$probe_build" -p1 <cpu_eval_ifu_fence_i.patch || {
    printf 'CPU_EVAL_INVALID: the fixed testbench patch did not apply\n' >&2
    exit 2
}

rm -rf obj_dir
rm -f verilator-build program.hex "$test_name".{o,exe,map,sym,dis,cpp.s} \
    console.log exec.log trace_port.csv

sim_status=0
make -f tools/Makefile verilator TEST="$test_name" TBDIR="$probe_build/testbench" TEST_DIR=testbench/asm \
    TB_MAX_CYCLES=10000 >"$log" 2>&1 || sim_status=$?

for trace in console.log exec.log trace_port.csv; do
    if [[ -f "$trace" ]]; then
        cp "$trace" "$probe_dir/"
    fi
done

status=2
if [[ "$sim_status" == 124 || "$sim_status" == 137 || "$sim_status" == 143 ]] ||
   ! grep -q 'verilator --cc' "$log"; then
    printf 'CPU_EVAL_INVALID: %s was interrupted or the fixed program did not build (exit %s)\n' \
        "$test_name" "$sim_status" >>"$log"
elif grep -q 'VerilatorTB: Start of sim' "$log"; then
    if grep -Eq '^Hit max cycle count \(10000\) \.\. stopping$' "$log"; then
        status=1
    elif grep -q 'TEST_PASSED' "$log" && ! grep -q 'TEST_FAILED' "$log" &&
         [[ "$sim_status" == 0 ]]; then
        status=0
    elif grep -q 'TEST_FAILED' "$log" && ! grep -q 'TEST_PASSED' "$log" &&
         grep -q 'tb_top.sv:1028: Assertion failed' "$log"; then
        status=1
    fi
fi
printf '%s\n' "$status" >"$probe_dir/$test_name.status"
if [[ "$status" != 0 ]]; then
    cat "$log" >&2
fi
exit "$status"
