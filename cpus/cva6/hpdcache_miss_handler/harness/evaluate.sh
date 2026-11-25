#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_miss_handler.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

candidate=$(realpath "$1")
base_log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

export CVA6_TESTLIST="$script_directory/testlist_miss_handler.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="$base_log_root/directed"
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_miss_handler "$candidate"

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
export CPU_EVAL_LOG_ROOT="$base_log_root/standard"
exec "$cpu_directory/harness/evaluate_parallel.sh" hpdcache_miss_handler "$candidate"
