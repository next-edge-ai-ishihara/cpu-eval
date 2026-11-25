#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_sram_1rw.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)
: "${CVA6_REPO:?CVA6_REPO is required}"

candidate=$(realpath "$1")
base_log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
python3 "$script_directory/evaluate_ports.py" "$candidate"

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_hpdcache_sram_1rw.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="$base_log_root/directed"
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_sram_1rw "$candidate"
