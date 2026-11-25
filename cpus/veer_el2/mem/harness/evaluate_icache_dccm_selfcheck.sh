#!/usr/bin/env bash
# Both the DCCM/cache self-check and the pinned upstream ICCM program must pass.
set -euo pipefail
export RV_ROOT="$PWD"
for tool in verilator riscv64-unknown-elf-gcc; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
if ! verilator --version 2>&1 | grep -q ' 5\.036 '; then
  printf 'CPU_EVAL_INVALID: wrong verilator on PATH (expected 5.036): %s\n' "$(verilator --version 2>&1)" >&2
  exit 2
fi
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"

printf '%s\n' \
  '56113a214c091a0479ff804dbbbb27d96d86926c00613edf8f493e6ecc8bc123  testbench/asm/hello_world_iccm.s' \
  'd5dbc4959b16e8ddf5d0d69a01443d56eee07276970bcfdc09394abef911f354  testbench/asm/hello_world_iccm.ld' \
  | sha256sum --check --status || {
    printf 'CPU_EVAL_INVALID: fixed ICCM test inputs are missing or changed\n' >&2
    exit 2
  }

cp "$(dirname "${BASH_SOURCE[0]}")/icache_dccm_selfcheck.s" testbench/asm/icache_dccm_selfcheck.s

# Each test recompiles the candidate RTL.
run_test() {
local test_name="$1"
local log="$results_dir/$test_name.log"
local status_file="$results_dir/$test_name.status"
local build_status
rm -rf obj_dir
rm -f verilator-build "$test_name.exe" "$test_name.o" \
      "$test_name.map" "$test_name.sym" \
      "$test_name.dis" program.hex crt0.o "$test_name.cpp.s"

set +e
make -f tools/Makefile verilator "TEST=$test_name" TEST_DIR=testbench/asm >"$log" 2>&1
build_status=$?
set -e
if [ "$build_status" -eq 124 ] || [ "$build_status" -eq 137 ] || [ "$build_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: build or simulation was interrupted (exit %s)\n' "$build_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  return 2
fi
if ! grep -q 'verilator --cc' "$log"; then
  printf 'CPU_EVAL_INVALID: verilator did not run -- the fixed program did not build or stale build artifacts were reused\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  return 2
fi
if grep -q 'VerilatorTB: Start of sim' "$log" &&
  grep -Eq '^Hit max cycle count \([0-9]+\) \.\. stopping$' "$log"; then
  printf '1\n' >"$status_file"
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  cat "$log" >&2
  return 1
fi
if [ "$build_status" -ne 0 ] && ! {
    grep -q 'TEST_FAILED' "$log" &&
    ! grep -q 'TEST_PASSED' "$log" &&
    grep -q 'tb_top.sv:1028: Assertion failed' "$log";
  }; then
  printf 'FAIL: build or simulation command exited %d without a test result\n' "$build_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  return 2
fi
if grep -q 'Hit max cycle count' "$log"; then
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  return 2
fi
if grep -q 'TEST_PASSED' "$log" && grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL: the program reported both TEST_PASSED and TEST_FAILED\n' >>"$log"
  printf '2\n' >"$status_file"
  return 2
fi
if grep -q 'TEST_PASSED' "$log"; then
  printf 'PASS\n' >>"$log"
  printf '0\n' >"$status_file"
  return 0
fi
if grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL\n' >>"$log"
  printf '1\n' >"$status_file"
  return 1
fi
printf 'FAIL: no TEST_PASSED or TEST_FAILED marker found in simulation output\n' >>"$log"
printf '2\n' >"$status_file"
cat "$log" >&2
return 2
}

for test_name in icache_dccm_selfcheck hello_world_iccm; do
  run_test "$test_name" || exit "$?"
done
exit 0
