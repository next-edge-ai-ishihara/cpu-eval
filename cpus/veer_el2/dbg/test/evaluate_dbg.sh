#!/usr/bin/env bash
set -euo pipefail
test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
status_file="$results_dir/dbg_combined.status"
set +e
bash "$test_dir/../../_shared/run_fixed_test.sh"
cpu_status=$?
set -e
if [ "$cpu_status" -ne 0 ]; then
  printf '%s\n' "$cpu_status" >"$status_file"
  exit "$cpu_status"
fi
set +e
bash "$test_dir/run_dbg_port_probe.sh"
port_status=$?
set -e
printf '%s\n' "$port_status" >"$status_file"
exit "$port_status"
