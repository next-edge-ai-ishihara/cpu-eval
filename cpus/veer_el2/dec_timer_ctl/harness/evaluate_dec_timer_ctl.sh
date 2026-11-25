#!/usr/bin/env bash
# Check timer increments, timer-0 interrupt delivery and cascade through
# the directed program's mailbox result. The selected Spike model does not
# implement the custom timer CSR addresses.
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
log="$results_dir/dec_timer_ctl_selfcheck.log"
status_file="$results_dir/dec_timer_ctl_selfcheck.status"

cp "$(dirname "${BASH_SOURCE[0]}")/dec_timer_ctl_selfcheck.s" testbench/asm/dec_timer_ctl_selfcheck.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build dec_timer_ctl_selfcheck.exe dec_timer_ctl_selfcheck.o \
      dec_timer_ctl_selfcheck.map dec_timer_ctl_selfcheck.sym \
      dec_timer_ctl_selfcheck.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=dec_timer_ctl_selfcheck TEST_DIR=testbench/asm >"$log" 2>&1
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
if grep -q 'TEST_PASSED' "$log" && grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL: the program reported both TEST_PASSED and TEST_FAILED\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
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
