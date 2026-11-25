#!/usr/bin/env bash
set -uo pipefail

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CPU_EVAL_RESULTS_DIR="$results_dir/instruction_trace" \
CPU_EVAL_EXPECTED_MATCHED=2193 \
bash "$script_dir/test/with_observer.sh" bash "$script_dir/../_shared/run_fixed_test.sh"
trace_status=$?

CPU_EVAL_RESULTS_DIR="$results_dir/dmi_probe" \
bash "$script_dir/test/evaluate_veer_wrapper_dmi_probe.sh"
probe_status=$?

if [ "$trace_status" -eq 1 ] || [ "$probe_status" -eq 1 ]; then
  exit 1
fi
if [ "$trace_status" -ne 0 ] || [ "$probe_status" -ne 0 ]; then
  exit 2
fi
exit 0
