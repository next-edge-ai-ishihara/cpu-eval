#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_mem_to_axi_write.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

candidate=$(realpath "$1")

export CVA6_TARGET=cv64a6_imafdc_sv39_hpdcache_wb
export CVA6_TESTLIST="$script_directory/testlist_axi_write.yaml"
export CVA6_TEST_JOBS=1
bash "$script_directory/evaluate_ports.sh" "$candidate"
exec "$cpu_directory/harness/evaluate_parallel.sh" hpdcache_mem_to_axi_write "$candidate"
