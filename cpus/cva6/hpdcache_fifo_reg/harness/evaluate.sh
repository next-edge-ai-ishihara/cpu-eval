#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_fifo_reg.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
python3 "$script_directory/evaluate_ports.py" "$1" || exit $?

problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
exec "$cpu_directory/harness/evaluate_parallel.sh" hpdcache_fifo_reg "$1"
