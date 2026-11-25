#!/usr/bin/env bash
set -uo pipefail

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${CPU_EVAL_OBSERVER_DEC:-}" != "1" ]; then
  export CPU_EVAL_OBSERVER_DEC=1
  exec bash "$script_dir/../veer_wrapper/test/with_observer.sh" bash "$script_dir/evaluate_all.sh"
fi

CPU_EVAL_RESULTS_DIR="$results_dir/instruction_trace" \
CPU_EVAL_EXPECTED_MATCHED=2193 \
bash "$script_dir/../_shared/run_fixed_test.sh"
trace_status=$?

CPU_EVAL_RESULTS_DIR="$results_dir/debug_probe" \
bash "$script_dir/harness/run_dbg_busy_probe.sh"
probe_status=$?

if [ "$trace_status" -eq 1 ] || [ "$probe_status" -eq 1 ]; then
  exit 1
fi
if [ "$trace_status" -ne 0 ] || [ "$probe_status" -ne 0 ]; then
  exit 2
fi
exit 0
