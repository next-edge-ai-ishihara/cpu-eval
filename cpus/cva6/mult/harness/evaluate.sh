#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-mult.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
candidate=$(realpath "$1")
export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_mult.yaml"
python3 "$script_directory/evaluate_ports.py" "$candidate"
exec "$cpu_directory/harness/evaluate_parallel.sh" mult "$candidate"
