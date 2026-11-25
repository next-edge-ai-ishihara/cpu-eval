#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_mem_req_write_arbiter.sv>" >&2
  exit 2
fi

lock_repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$lock_repo.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $lock_repo" >&2
    exit 2
  fi
else
  exec 9>"$lock_repo.cpu-eval.lock" || { echo "INVALID: cannot open the evaluation lock" >&2; exit 2; }
fi
flock -n 9 || { echo "INVALID: another evaluation owns $lock_repo" >&2; exit 2; }
export CVA6_EVALUATION_LOCK_FD=9

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

candidate=$(realpath "$1")
base_log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

CPU_EVAL_LOG_ROOT="$base_log_root" python3 "$script_directory/evaluate_ports.py" "$candidate"

export CVA6_TARGET=cv64a6_imafdc_sv39_hpdcache_wb
export CVA6_TESTLIST="$script_directory/testlist_write_arbiter.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="$base_log_root/writeback"
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_mem_req_write_arbiter "$candidate"

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TARGET=cv32a60x
export CVA6_TEST_JOBS=4
export CPU_EVAL_LOG_ROOT="$base_log_root/standard"
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_mem_req_write_arbiter "$candidate"
