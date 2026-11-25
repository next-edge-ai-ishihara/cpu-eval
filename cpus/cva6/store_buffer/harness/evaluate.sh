#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-store_buffer.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
python3 "$script_directory/evaluate_flush_ports.py" "$1"
export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_store_buffer.yaml"
export CVA6_TEST_JOBS=4
exec "$script_directory/../../harness/evaluate_parallel.sh" store_buffer "$1"
