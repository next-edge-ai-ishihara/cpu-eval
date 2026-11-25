#!/usr/bin/env bash
# The RTL program checks DCCM store/load results, calls a two-instruction
# routine CALL_COUNT times from distinct call sites, and compares the first
# and final call intervals in the same run. No ISA model is invoked.

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
log="$results_dir/icache_dccm_selfcheck.log"
status_file="$results_dir/icache_dccm_selfcheck.status"

cp "$(dirname "${BASH_SOURCE[0]}")/icache_dccm_selfcheck.s" testbench/asm/icache_dccm_selfcheck.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build icache_dccm_selfcheck.exe icache_dccm_selfcheck.o \
      icache_dccm_selfcheck.map icache_dccm_selfcheck.sym \
      icache_dccm_selfcheck.dis program.hex crt0.o icache_dccm_selfcheck.cpp.s

set +e
printf '%s\n' '`verilator_config' 'lint_off -rule CMPCONST -file "*/el2_ifu_ic_mem.sv"' >"$results_dir/icache.vlt"
make -f tools/Makefile -f - verilator TEST=icache_dccm_selfcheck TEST_DIR=testbench/asm \
  <<<"VERILATOR_EXTRA_ARGS += $results_dir/icache.vlt" >"$log" 2>&1
build_status=$?
set -e
if [ "$build_status" -eq 124 ] || [ "$build_status" -eq 137 ] || [ "$build_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: build or simulation was interrupted (exit %s)\n' "$build_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if ! grep -q 'verilator --cc' "$log"; then
  printf 'CPU_EVAL_INVALID: verilator did not run -- the fixed program did not build or stale build artifacts were reused\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'VerilatorTB: Start of sim' "$log" &&
  grep -Eq '^Hit max cycle count \([0-9]+\) \.\. stopping$' "$log"; then
  printf '1\n' >"$status_file"
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  cat "$log" >&2
  exit 1
fi
if [ "$build_status" -ne 0 ] && ! {
    grep -q 'TEST_FAILED' "$log" &&
    ! grep -q 'TEST_PASSED' "$log" &&
    grep -q 'tb_top.sv:1028: Assertion failed' "$log";
  }; then
  printf 'FAIL: build or simulation command exited %d without a test result\n' "$build_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'TEST_PASSED' "$log" && grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL: the program reported both TEST_PASSED and TEST_FAILED\n' >>"$log"
  printf '2\n' >"$status_file"
  exit 2
fi
if grep -q 'TEST_PASSED' "$log"; then
  printf 'PASS\n' >>"$log"
  printf '0\n' >"$status_file"
  exit 0
fi
if grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL\n' >>"$log"
  printf '1\n' >"$status_file"
  exit 1
fi
printf 'FAIL: no TEST_PASSED or TEST_FAILED marker found in simulation output\n' >>"$log"
printf '2\n' >"$status_file"
cat "$log" >&2
exit 2
