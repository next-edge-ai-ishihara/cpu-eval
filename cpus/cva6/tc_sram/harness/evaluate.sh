#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-tc_sram.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/../../sram_cache/harness/testlist_icache_sram.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" tc_sram "$1"
python3 "$script_directory/evaluate_tc_sram_ports.py" "$1"
