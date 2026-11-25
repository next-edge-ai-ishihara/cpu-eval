#!/usr/bin/env bash
set -uo pipefail

CANDIDATE=${1:-}
if [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <candidate-cva6_hpdcache_wrapper.sv>" >&2
  exit 2
fi

HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
COMMON_EVALUATOR="$HARNESS_DIR/../../harness/evaluate_parallel.sh"
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

CVA6_TESTLIST="$HARNESS_DIR/../../harness/testlist_cv32a60x.yaml" \
CPU_EVAL_LOG_ROOT="$LOG_ROOT/load-traces" \
  "$COMMON_EVALUATOR" cva6_hpdcache_wrapper "$CANDIDATE"
LOAD_RC=$?

CPU_EVAL_LOG_ROOT="$LOG_ROOT/store-updates" \
  "$HARNESS_DIR/evaluate_store_updates.sh" "$CANDIDATE"
STORE_RC=$?

# A definite mismatch outranks a check that could not finish.
if [ "$LOAD_RC" -eq 1 ] || [ "$STORE_RC" -eq 1 ]; then
  echo "FAIL: load instruction traces or store updates mismatched"
  exit 1
fi
if [ "$LOAD_RC" -ne 0 ] || [ "$STORE_RC" -ne 0 ]; then
  echo "INVALID: one or both CPU regressions did not complete" >&2
  exit 2
fi
echo "PASS: load instruction traces and store updates matched"
exit 0
