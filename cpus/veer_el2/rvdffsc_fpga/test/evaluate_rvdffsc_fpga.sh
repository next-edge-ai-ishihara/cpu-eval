#!/usr/bin/env bash
# The testbench routes CPU accesses to ICCM through the DMA slave port.

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
log="$results_dir/rvdffsc_fpga_dma_probe.log"
status_file="$results_dir/rvdffsc_fpga_dma_probe.status"

cp "$(dirname "${BASH_SOURCE[0]}")/rvdffsc_fpga_dma_probe.s" testbench/asm/rvdffsc_fpga_dma_probe.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir tools/obj_dir
rm -f verilator-build tools/verilator-build \
  rvdffsc_fpga_dma_probe.exe rvdffsc_fpga_dma_probe.o rvdffsc_fpga_dma_probe.map \
  rvdffsc_fpga_dma_probe.sym rvdffsc_fpga_dma_probe.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=rvdffsc_fpga_dma_probe TEST_DIR=testbench/asm >"$log" 2>&1
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
if grep -q 'TEST_PASSED' "$log" && { [ "$make_status" -ne 0 ] || grep -q 'TEST_FAILED' "$log"; }; then
  printf 'FAIL: TEST_PASSED requires a normal make exit and no TEST_FAILED marker (make exit: %s)\n' "$make_status" >>"$log"
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
