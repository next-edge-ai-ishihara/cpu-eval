#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-scoreboard.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
python3 "$script_directory/evaluate_cvxif_ports.py" "$1"
export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/../../raw_checker/harness/testlist_raw_checker.yaml"
export CVA6_TEST_JOBS=4
exec "$cpu_directory/harness/evaluate_parallel.sh" scoreboard "$1"
