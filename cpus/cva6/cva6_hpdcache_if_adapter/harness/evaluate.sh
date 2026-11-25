#!/usr/bin/env bash
set -uo pipefail

CANDIDATE=${1:-}
if [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <candidate-cva6_hpdcache_if_adapter.sv>" >&2
  exit 2
fi

HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
COMMON_EVALUATOR="$HARNESS_DIR/../../harness/evaluate_parallel.sh"
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

CVA6_TESTLIST="$HARNESS_DIR/../../harness/testlist_cv32a60x.yaml" \
CPU_EVAL_LOG_ROOT="$LOG_ROOT/load-traces" \
  "$COMMON_EVALUATOR" cva6_hpdcache_if_adapter "$CANDIDATE"
LOAD_RC=$?
shopt -s nullglob
compile_errors=("$LOG_ROOT"/load-traces/cva6_hpdcache_if_adapter/*/candidate-compile-error.txt)
if [ "$LOAD_RC" -eq 1 ] && [ "${#compile_errors[@]}" -eq 1 ]; then
  exit 1
fi

CVA6_TESTLIST="$HARNESS_DIR/testlist_distinct_loads.yaml" \
CPU_EVAL_LOG_ROOT="$LOG_ROOT/distinct-load-traces" \
  "$COMMON_EVALUATOR" cva6_hpdcache_if_adapter "$CANDIDATE"
DISTINCT_LOAD_RC=$?

CPU_EVAL_LOG_ROOT="$LOG_ROOT/store-updates" \
  "$HARNESS_DIR/evaluate_store_updates.sh" "$CANDIDATE"
STORE_RC=$?

CPU_EVAL_LOG_ROOT="$LOG_ROOT/load-cancellation" \
  python3 "$HARNESS_DIR/evaluate_load_cancel.py" "$CANDIDATE"
CANCEL_RC=$?

# A definite mismatch outranks a check that could not finish.
if [ "$CANCEL_RC" -eq 1 ] || [ "$LOAD_RC" -eq 1 ] || [ "$STORE_RC" -eq 1 ] || [ "$DISTINCT_LOAD_RC" -eq 1 ]; then
  echo "FAIL: load cancellation, instruction traces, or store updates mismatched"
  exit 1
fi
if [ "$CANCEL_RC" -ne 0 ] || [ "$LOAD_RC" -ne 0 ] || [ "$STORE_RC" -ne 0 ] || [ "$DISTINCT_LOAD_RC" -ne 0 ]; then
  echo "INVALID: at least one adapter check did not complete" >&2
  exit 2
fi
echo "PASS: load cancellation, instruction traces, and store updates matched"
exit 0
