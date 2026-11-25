#!/usr/bin/env bash
# Phase 1 checks that an asserted inverted-polarity line does not interrupt;
# phase 2 checks the claim id of a normal-polarity line. gateway_edges.sv tests edge mode.
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
log="$results_dir/pic_configurable_gw.log"
status_file="$results_dir/pic_configurable_gw.status"

cp "$(dirname "${BASH_SOURCE[0]}")/pic_configurable_gw.s" testbench/asm/pic_configurable_gw.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build pic_configurable_gw.exe pic_configurable_gw.o pic_configurable_gw.map pic_configurable_gw.sym pic_configurable_gw.dis program.hex crt0.o

printf '%s\n' '`verilator_config' 'lint_off -rule IMPLICIT -file "*/el2_pic_ctrl.sv"' >"$results_dir/gateway.vlt"
set +e
make -f tools/Makefile -f - verilator TEST=pic_configurable_gw TEST_DIR=testbench/asm \
  <<<"VERILATOR_EXTRA_ARGS += $results_dir/gateway.vlt" >"$log" 2>&1
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
  cfg="$RV_ROOT/snapshots/default"
  build_dir="$(mktemp -d "$PWD/gateway-edges.XXXXXXXX")"
  trap 'rm -rf "$build_dir"' EXIT
  bench="$(dirname "${BASH_SOURCE[0]}")/gateway_edges.sv"
  edge_log="$results_dir/gateway-edges.log"
  if ! verilator --binary --timing --top-module gateway_edges --Mdir "$build_dir" \
      -I"$cfg" "$cfg/common_defines.vh" "$RV_ROOT/design/include/el2_def.sv" \
      "$results_dir/gateway.vlt" "$RV_ROOT/design/lib/beh_lib.sv" \
      "$RV_ROOT/design/el2_pic_ctrl.sv" "$bench" \
      >"$results_dir/gateway-edges.build.log" 2>&1; then
    cat "$results_dir/gateway-edges.build.log" >&2
    printf '2\n' >"$status_file"
    exit 2
  fi
  if ! timeout --verbose 10 "$build_dir/Vgateway_edges" >"$edge_log" 2>&1; then
    cat "$edge_log" >&2
    printf '2\n' >"$status_file"
    exit 2
  fi
  marker="$(grep -Ex 'GATEWAY_EDGES_(PASS|FAIL)' "$edge_log" || true)"
  if [[ "$marker" == GATEWAY_EDGES_FAIL ]]; then
    cat "$edge_log" >&2
    printf '1\n' >"$status_file"
    exit 1
  fi
  if [[ "$marker" != GATEWAY_EDGES_PASS ]]; then
    printf '2\n' >"$status_file"
    exit 2
  fi
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
