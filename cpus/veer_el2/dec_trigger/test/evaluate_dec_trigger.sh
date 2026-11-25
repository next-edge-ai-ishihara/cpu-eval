#!/usr/bin/env bash
# Run the directed trigger program, then the port test of the M-mode enable,
# masked matching and all four trigger slots.
set -euo pipefail
export RV_ROOT="$PWD"
for tool in verilator riscv64-unknown-elf-gcc timeout; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/dec_trigger_addr_match.log"
status_file="$results_dir/dec_trigger_addr_match.status"
port_log="$results_dir/dec_trigger_ports.log"
port_status="$results_dir/dec_trigger_ports.status"
port_build_log="$results_dir/dec_trigger_ports_build.log"
rm -f "$port_log" "$port_status" "$port_build_log"

cp "$(dirname "${BASH_SOURCE[0]}")/dec_trigger_addr_match.s" testbench/asm/dec_trigger_addr_match.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build dec_trigger_addr_match.exe dec_trigger_addr_match.o dec_trigger_addr_match.map dec_trigger_addr_match.sym dec_trigger_addr_match.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=dec_trigger_addr_match TEST_DIR=testbench/asm >"$log" 2>&1
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
  if ! port_dir="$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-trigger-ports.XXXXXXXX")"; then
    printf 'CPU_EVAL_INVALID: cannot create the port test workspace\n' >&2
    printf '2\n' >"$port_status"
    exit 2
  fi
  trap 'rm -rf "$port_dir"' EXIT
  snapshot="$RV_ROOT/snapshots/default"
  probe="$(dirname "${BASH_SOURCE[0]}")/dec_trigger_ports.sv"
  if ! timeout --verbose 120 verilator --binary --timing -Wno-fatal -CFLAGS -g0 \
    -MAKEFLAGS VM_PARALLEL_BUILDS=0 --top-module dec_trigger_ports \
    --Mdir "$port_dir/obj" -I"$snapshot" -I"$RV_ROOT/design/include" \
    "$snapshot/common_defines.vh" "$RV_ROOT/design/include/el2_def.sv" \
    "$RV_ROOT/design/lib/beh_lib.sv" "$RV_ROOT/design/dec/el2_dec_trigger.sv" \
    "$probe" >"$port_build_log" 2>&1; then
    printf '2\n' >"$port_status"
    cat "$port_build_log" >&2
    exit 2
  fi
  if ! timeout --verbose 10 "$port_dir/obj/Vdec_trigger_ports" >"$port_log" 2>&1; then
    printf '2\n' >"$port_status"
    cat "$port_log" >&2
    exit 2
  fi
  cat "$port_log"
  if grep -Eq '^TRIGGER_PORTS_FAIL mismatches=[1-3]$' "$port_log" &&
    ! grep -Fxq 'TRIGGER_PORTS_PASS' "$port_log"; then
    printf '1\n' >"$port_status"
    printf 'FAIL: decode trigger port mismatch\n' >&2
    exit 1
  fi
  if grep -Fxq 'TRIGGER_PORTS_PASS' "$port_log" &&
    ! grep -q '^TRIGGER_PORTS_FAIL' "$port_log"; then
    printf '0\n' >"$port_status"
    exit 0
  fi
  printf '2\n' >"$port_status"
  printf 'FAIL: incomplete decode trigger port result\n' >&2
  exit 2
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
