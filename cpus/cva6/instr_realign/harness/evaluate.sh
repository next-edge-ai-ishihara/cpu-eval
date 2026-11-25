#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-instr_realign.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)

set +e
python3 "$script_directory/evaluate_ports.py" "$1"
ports_rc=$?
set -e
if [ "$ports_rc" -ne 0 ]; then
  exit "$ports_rc"
fi

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_instr_realign.yaml"
export CVA6_TEST_JOBS=4
exec "$cpu_directory/harness/evaluate_parallel.sh" instr_realign "$1"
