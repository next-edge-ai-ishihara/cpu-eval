#!/usr/bin/env bash
set -euo pipefail
export RV_ROOT="$PWD"

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
mkdir -p "$results_dir"

CPU_EVAL_RESULTS_DIR="$results_dir/trace" \
CPU_EVAL_EXPECTED_MATCHED=2193 \
bash "$(dirname "${BASH_SOURCE[0]}")/../_shared/run_fixed_test.sh"

rm -rf obj_dir
rm -f verilator-build icache_ecc.exe icache_ecc.o icache_ecc.map \
  icache_ecc.sym icache_ecc.dis program.hex crt0.o

run_icache_ecc() {
  local case_name=$1
  local sim_args=$2
  local log="$results_dir/$case_name.log"
  local status="$results_dir/$case_name.status"
  local build_status=0
  make -f tools/Makefile verilator TEST=icache_ecc \
    TEST_DIR=testbench/tests/icache_ecc TB_EXTRA_ARGS="$sim_args" >"$log" 2>&1 || build_status=$?
  # Only the first case builds; later cases reuse the model and the program.
  if [ "$build_status" -eq 124 ] || [ "$build_status" -eq 137 ] || [ "$build_status" -eq 143 ] || {
       ! grep -q 'verilator --cc' "$log" && ! grep -q 'VerilatorTB: Start of sim' "$log"; }; then
    printf '2\n' >"$status"
    printf 'CPU_EVAL_INVALID: icache_ecc was interrupted or the fixed program did not build (command status %d)\n' \
      "$build_status" >>"$log"
    cat "$log" >&2
    return 2
  fi
  if [ "$build_status" -ne 124 ] && [ "$build_status" -ne 137 ] && [ "$build_status" -ne 143 ] &&
    grep -q 'VerilatorTB: Start of sim' "$log" &&
    grep -Eq '^Hit max cycle count \([0-9]+\) \.\. stopping$' "$log"; then
    printf '1\n' >"$status"
    printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
    cat "$log" >&2
    return 1
  fi
  if grep -q 'Hit max cycle count' "$log"; then
    printf '2\n' >"$status"
    printf 'FAIL: icache_ecc reached its cycle limit\n' >>"$log"
    return 2
  fi
  if grep -q 'TEST_PASSED' "$log" && grep -q 'TEST_FAILED' "$log"; then
    printf '2\n' >"$status"
    printf 'FAIL: icache_ecc reported both TEST_PASSED and TEST_FAILED\n' >>"$log"
    return 2
  fi
  if grep -q 'TEST_PASSED' "$log" && [ "$build_status" -ne 0 ]; then
    printf '2\n' >"$status"
    printf 'FAIL: icache_ecc TEST_PASSED followed by an abnormal make exit\n' >>"$log"
    return 2
  fi
  if grep -q 'TEST_PASSED' "$log"; then
    printf '0\n' >"$status"
    return 0
  fi
  if grep -q 'TEST_FAILED' "$log"; then
    printf '1\n' >"$status"
    return 1
  fi
  printf '2\n' >"$status"
  printf 'FAIL: icache_ecc ended without a test verdict (command status %d)\n' \
    "$build_status" >>"$log"
  return 2
}

run_icache_ecc icache_ecc --test-halt
for ecc_bit in 0 1 2 3 4 5 6; do
  run_icache_ecc "icache_ecc_bit$ecc_bit" "--test-halt +cpu_eval_ecc_bit=$ecc_bit"
done
