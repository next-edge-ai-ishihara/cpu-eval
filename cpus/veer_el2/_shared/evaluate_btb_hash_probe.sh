#!/usr/bin/env bash
# Run a fixed branch workload and compare its mcycle delta with the recorded value.
set -euo pipefail
if [ -z "${CPU_EVAL_EXPECTED_MCYCLE_HEX:-}" ]; then
  printf 'CPU_EVAL_INVALID: CPU_EVAL_EXPECTED_MCYCLE_HEX must be the reference mcycle delta\n' >&2
  exit 2
fi
probe_test="${CPU_EVAL_MCYCLE_PROBE_TEST:-btb_hash_cycle_probe}"
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
log="$results_dir/${probe_test}.log"
status_file="$results_dir/${probe_test}.status"

# Force recompilation of the candidate RTL.
rm -f tools/verilator-build
rm -rf tools/obj_dir

# The reference program takes 320,307 cycles; the limit is 15 times that.
set +e
(cd tools && make TEST="$probe_test" CONF_PARAMS='-set build_axi4' TB_MAX_CYCLES=5000000 verilator) >"$log" 2>&1
build_status=$?
set -e
if ! grep -q 'verilator --cc' "$log"; then
  printf 'CPU_EVAL_INVALID: verilator did not re-elaborate -- the fixed program did not build or stale build artifacts were reused\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if [ "$build_status" -eq 124 ] || [ "$build_status" -eq 137 ] || [ "$build_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: build or simulation was interrupted (exit %s)\n' "$build_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

observed="$( { grep -E '^\[[0-9]+ ns\] [0-9a-f]{8}$' "$log" || true; } | tail -1 | awk '{print $3}')"
if grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL\tprobe program reported TEST_FAILED or reached the cycle limit (observed=%s)\n' "$observed" >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi
if [ "$build_status" -ne 0 ] || [ -z "$observed" ] || ! grep -q 'TEST_PASSED' "$log"; then
  printf 'FAIL: build or simulation ended without TEST_PASSED and an mcycle delta (exit %s)\n' "$build_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if [ "$observed" != "$CPU_EVAL_EXPECTED_MCYCLE_HEX" ]; then
  printf 'FAIL\tmcycle delta differs: expected=%s observed=%s\n' "$CPU_EVAL_EXPECTED_MCYCLE_HEX" "$observed" >>"$log"
  printf '1\n' >"$status_file"
  exit 1
fi
printf 'PASS\tmcycle delta matches: %s\n' "$observed" >>"$log"
printf '0\n' >"$status_file"
exit 0
