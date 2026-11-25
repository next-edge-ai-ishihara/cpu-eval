#!/usr/bin/env bash
# The program arms instruction-address triggers through tselect, tdata1
# and tdata2 writes and compares mcause, mscause and mepc in its trap
# handler. The verdict uses the RTL mailbox result without an ISA model.

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
log="$results_dir/rvmaskandmatch_addr_match.log"
status_file="$results_dir/rvmaskandmatch_addr_match.status"

cp "$(dirname "${BASH_SOURCE[0]}")/rvmaskandmatch_addr_match.s" testbench/asm/rvmaskandmatch_addr_match.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build rvmaskandmatch_addr_match.exe rvmaskandmatch_addr_match.o \
  rvmaskandmatch_addr_match.map rvmaskandmatch_addr_match.sym \
  rvmaskandmatch_addr_match.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=rvmaskandmatch_addr_match TEST_DIR=testbench/asm >"$log" 2>&1
make_status=$?
set -e
if [ "$make_status" -eq 124 ] || [ "$make_status" -eq 137 ] || [ "$make_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: build or simulation was interrupted (exit %s)\n' "$make_status" >>"$log"
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
if grep -q 'Hit max cycle count' "$log"; then
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'TEST_PASSED' "$log" && grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL: the program reported both TEST_PASSED and TEST_FAILED\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'TEST_PASSED' "$log" && [ "$make_status" -ne 0 ]; then
  printf 'FAIL: TEST_PASSED followed by an abnormal make exit\n' >>"$log"
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
