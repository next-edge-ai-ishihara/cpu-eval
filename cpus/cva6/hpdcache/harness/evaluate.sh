#!/usr/bin/env bash
set -uo pipefail

candidate=${1:-}
if [ -z "$candidate" ] || [ ! -f "$candidate" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)
log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml" \
CPU_EVAL_LOG_ROOT="$log_root/load-traces" \
  "$cpu_directory/harness/evaluate_parallel.sh" hpdcache "$candidate"
load_rc=$?

CPU_EVAL_MODULE=hpdcache \
CPU_EVAL_SOURCE=core/cache_subsystem/hpdcache/rtl/src/hpdcache.sv \
CPU_EVAL_LOG_ROOT="$log_root/store-updates" \
  "$cpu_directory/cva6_hpdcache_if_adapter/harness/evaluate_store_updates.sh" "$candidate"
store_rc=$?

# A definite mismatch outranks a check that could not finish.
if [ "$load_rc" -eq 1 ] || [ "$store_rc" -eq 1 ]; then
  echo "FAIL: a load trace or accepted DRAM store update mismatched"
  exit 1
fi
if [ "$load_rc" -ne 0 ] || [ "$store_rc" -ne 0 ]; then
  echo "INVALID: a load or store regression did not complete" >&2
  exit 2
fi
echo "PASS: load traces and accepted DRAM store updates matched"
exit 0
