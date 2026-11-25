#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! -f $1 ]]; then
  echo "usage: evaluate.sh <candidate-lzc.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
candidate=$(realpath "$1")
python3 "$script_directory/check_ports.py" "$candidate" || exit $?
export CVA6_TARGET=cv32a60x CVA6_TESTLIST="$script_directory/testlist_lzc.yaml"
exec "$cpu_directory/harness/evaluate_parallel.sh" lzc "$candidate"
