#!/usr/bin/env bash
# Each program records the claim id selected through el2_configurable_gw polarity
# and fast redirect; the port probe then checks the two-edge synchronizer delay.
set -euo pipefail
export RV_ROOT="$PWD"
for tool in verilator riscv64-unknown-elf-gcc; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
run_directed() {
local test_name="$1"
local results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
local log="$results_dir/${test_name}.log"
local status_file="$results_dir/${test_name}.status"

cp "$(dirname "${BASH_SOURCE[0]}")/${test_name}.s" "testbench/asm/${test_name}.s"

# Force recompilation of the candidate RTL.
rm -rf obj_dir tools/obj_dir
rm -f verilator-build tools/verilator-build \
  "${test_name}.exe" "${test_name}.o" \
  "${test_name}.map" "${test_name}.sym" \
  "${test_name}.dis" program.hex crt0.o

BUILD_PATH=snapshots/default configs/veer.config -target=default -set build_axi4 -set fpga_optimize=0 || {
  printf 'CPU_EVAL_INVALID: the fixed configuration was not generated\n' >&2
  return 2
}

set +e
make -f tools/Makefile verilator TEST="${test_name}" TEST_DIR=testbench/asm >"$log" 2>&1
make_status=$?
set -e
if [ "$make_status" -eq 124 ] || [ "$make_status" -eq 137 ] || [ "$make_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: build or simulation was interrupted (exit %s)\n' "$make_status" >>"$log"
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
if grep -q 'Hit max cycle count' "$log"; then
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  return 2
fi
if grep -q 'TEST_PASSED' "$log" && { [ "$make_status" -ne 0 ] || grep -q 'TEST_FAILED' "$log"; }; then
  printf 'FAIL: TEST_PASSED requires a normal make exit and no TEST_FAILED marker (make exit: %s)\n' "$make_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
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

run_directed rvsyncss_fpga_gw_polarity
run_directed rvsyncss_fpga_gw_low

results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-rvsyncss-fpga.XXXXXXXX")"
trap 'rm -rf -- "$probe_dir"' EXIT
build_log="$results_dir/rvsyncss_fpga_port_probe.build.log"
probe_log="$results_dir/rvsyncss_fpga_port_probe.log"
status_file="$results_dir/rvsyncss_fpga_port_probe.status"
if ! timeout --verbose 120 verilator --binary --timing -Wno-fatal -j 2 \
    --top-module rvsyncss_fpga_port_probe --Mdir "$probe_dir/obj" \
    "$PWD/snapshots/default/common_defines.vh" "$PWD/design/lib/beh_lib.sv" \
    "$(dirname "${BASH_SOURCE[0]}")/rvsyncss_fpga_port_probe.sv" >"$build_log" 2>&1; then
  printf '2\n' >"$status_file"
  cat "$build_log" >&2
  exit 2
fi
if ! timeout --verbose 10 "$probe_dir/obj/Vrvsyncss_fpga_port_probe" >"$probe_log" 2>&1; then
  printf '2\n' >"$status_file"
  cat "$probe_log" >&2
  exit 2
fi
cat "$probe_log"
if grep -q '^RVSYNCSS_FPGA_PORT_FAIL ' "$probe_log"; then
  printf '1\n' >"$status_file"
  exit 1
fi
if ! grep -Fxq 'RVSYNCSS_FPGA_PORT_PASS widths=1,7,251' "$probe_log"; then
  printf '2\n' >"$status_file"
  exit 2
fi
printf '0\n' >"$status_file"
