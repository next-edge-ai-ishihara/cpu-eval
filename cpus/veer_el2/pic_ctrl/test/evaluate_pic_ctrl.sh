#!/usr/bin/env bash
# Check PIC enable gating (phase 1) and priority-threshold masking (phase 2)
# through the claim ids recorded by the fast-redirect handlers.
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
log="$results_dir/pic_ctrl_gating.log"
status_file="$results_dir/pic_ctrl_gating.status"

cp "$(dirname "${BASH_SOURCE[0]}")/pic_ctrl_gating.s" testbench/asm/pic_ctrl_gating.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build pic_ctrl_gating.exe pic_ctrl_gating.o pic_ctrl_gating.map pic_ctrl_gating.sym pic_ctrl_gating.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=pic_ctrl_gating TEST_DIR=testbench/asm >"$log" 2>&1
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
pass_seen=0
fail_seen=0
grep -Eq '^\[[0-9]+ ns\] TEST_PASSED[[:space:]]*$' "$log" && pass_seen=1
grep -Eq '^\[[0-9]+ ns\] TEST_FAILED[[:space:]]*$' "$log" && fail_seen=1
if ! grep -Fxq 'VerilatorTB: Start of sim' "$log" ||
   [ "$pass_seen" -eq "$fail_seen" ]; then
  printf 'FAIL: missing simulation outcome or conflicting pass/fail markers\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if [ "$pass_seen" -eq 1 ]; then
  if [ "$make_status" -ne 0 ] || ! grep -Fq 'Verilog $finish' "$log"; then
    printf 'FAIL: TEST_PASSED without a normal simulation exit\n' >>"$log"
    printf '2\n' >"$status_file"
    cat "$log" >&2
    exit 2
  fi
  set +e
  bash "$(dirname "${BASH_SOURCE[0]}")/run_pic_port_probe.sh" "$RV_ROOT/snapshots/default" >>"$log" 2>&1
  port_status=$?
  set -e
  if [ "$port_status" -ne 0 ]; then
    printf '%s\n' "$port_status" >"$status_file"
    cat "$log" >&2
    exit "$port_status"
  fi
  printf 'PASS\n' >>"$log"
  printf '0\n' >"$status_file"
  exit 0
fi
if [ "$fail_seen" -eq 1 ]; then
  printf 'FAIL\n' >>"$log"
  printf '1\n' >"$status_file"
  exit 1
fi
printf 'FAIL: no TEST_PASSED or TEST_FAILED marker found in simulation output\n' >>"$log"
printf '2\n' >"$status_file"
cat "$log" >&2
exit 2
