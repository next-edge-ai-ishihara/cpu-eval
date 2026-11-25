#!/usr/bin/env bash
# Fast interrupt redirect selects ID 5 for priorities 5 and 10, then ID 4
# when both pending sources have priority 10.
set -euo pipefail
export RV_ROOT="$PWD"
for tool in verilator riscv64-unknown-elf-gcc; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/pic_cmp_and_mux.log"
status_file="$results_dir/pic_cmp_and_mux.status"

cp "$(dirname "${BASH_SOURCE[0]}")/pic_cmp_and_mux.s" testbench/asm/pic_cmp_and_mux.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build pic_cmp_and_mux.exe pic_cmp_and_mux.o pic_cmp_and_mux.map pic_cmp_and_mux.sym pic_cmp_and_mux.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=pic_cmp_and_mux TEST_DIR=testbench/asm >"$log" 2>&1
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
