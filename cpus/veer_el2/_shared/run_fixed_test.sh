#!/usr/bin/env bash
set -euo pipefail
test_name="${RISCV_DV_TEST:-riscv_arithmetic_basic_test}"
export RV_ROOT="$PWD"
for tool in spike verilator dtc make; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
if ! verilator --version 2>&1 | grep -q ' 5\.036 '; then
  printf 'CPU_EVAL_INVALID: wrong verilator on PATH (expected 5.036): %s\n' "$(verilator --version 2>&1)" >&2
  exit 2
fi
export SPIKE_PATH="${SPIKE_PATH:-$(dirname "$(command -v spike)")}"
work="$PWD/tools/riscv-dv/work"
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/${test_name}.log"
status_file="$results_dir/${test_name}.status"
test_work="$work/test_${test_name}"
raw_dir="$results_dir/${test_name}.raw"
preserve_raw_evidence() {
  rm -rf "$raw_dir"
  mkdir -p "$raw_dir"
  for name in asm_test hdl_sim spike_sim iss_sim.log; do
    if [ -e "$test_work/$name" ]; then
      cp -a "$test_work/$name" "$raw_dir/$name"
    fi
  done
  for comparison in "$test_work"/comp_*.log; do
    if [ -f "$comparison" ]; then
      cp -a "$comparison" "$raw_dir/"
    fi
  done
}
if ! find "$work/test_${test_name}/asm_test" -maxdepth 1 -type f -name '*.S' -print -quit 2>/dev/null | grep -q .; then
  printf '2\n' >"$status_file"
  printf 'CPU_EVAL_INVALID: fixed generated program is missing: %s\n' "$test_name" >&2
  exit 2
fi
rm -rf "$work/test_${test_name}/hdl_sim" "$work/test_${test_name}/spike_sim" \
  "$work/test_${test_name}/iss_sim.log" "$work"/test_"${test_name}"/comp_*.log "$work/verilator"
set +e
(cd tools/riscv-dv && make RISCV_DV_TEST="$test_name" RISCV_DV_ITER=1 run) >"$log" 2>&1
run_status=$?
set -e
preserve_raw_evidence
if [ "$run_status" -eq 124 ] || [ "$run_status" -eq 137 ] || [ "$run_status" -eq 143 ]; then
  printf '2\n' >"$status_file"
  printf 'CPU_EVAL_INVALID: RTL or reference execution was interrupted before completion\n' >>"$log"
  cat "$log" >&2
  exit 2
fi
if grep -q '^ISS simulation failed$' "$log" ||
   ! find "$raw_dir/spike_sim" -type f -print -quit 2>/dev/null | grep -q .; then
  printf '2\n' >"$status_file"
  printf 'CPU_EVAL_INVALID: missing Spike trace of the fixed program\n' >>"$log"
  cat "$log" >&2
  exit 2
fi
if ! find "$raw_dir/hdl_sim" -type f -print -quit 2>/dev/null | grep -q .; then
  printf '2\n' >"$status_file"
  printf 'FAIL: RTL build or simulation produced no trace\n' >>"$log"
  cat "$log" >&2
  exit 2
fi
if grep -R -E -q 'Hit max cycle count \([0-9]+\) \.\. stopping$' "$log" "$raw_dir/hdl_sim"; then
  printf '1\n' >"$status_file"
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  cat "$log" >&2
  exit 1
fi
if [ "$run_status" -eq 0 ]; then
  result="$(grep -E '^\[PASSED\]: [1-9][0-9]* matched$' "$log" | tail -1 || true)"
  test -n "$result" || { printf '2\n' >"$status_file"; cat "$log" >&2; exit 2; }
  matched="$(printf '%s\n' "$result" | sed -E 's/^\[PASSED\]: ([0-9]+) matched$/\1/')"
  if [ -n "${CPU_EVAL_EXPECTED_MATCHED:-}" ] && [ "$matched" -ne "$CPU_EVAL_EXPECTED_MATCHED" ]; then
    printf '[FAILED]: matched GPR state-change count differs: expected=%s actual=%s\n' \
      "$CPU_EVAL_EXPECTED_MATCHED" "$matched" >>"$log"
    printf '1\n' >"$status_file"
    exit 1
  fi
  printf '0\n' >"$status_file"
  printf '%s\n' "$result"
  exit 0
fi
if grep -Eq '^\[FAILED\]: [0-9]+ matched, [1-9][0-9]* mismatch$' "$log"; then
  printf '1\n' >"$status_file"
  exit 1
fi
printf '2\n' >"$status_file"
cat "$log" >&2
exit 2
