#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_uncached.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)

export CVA6_TARGET=cv64a6_imafdc_sv39_hpdcache_wb
export CVA6_TESTLIST="$script_directory/testlist_amo.yaml"
export CVA6_TEST_JOBS=1
exec python3 "$script_directory/evaluate_with_diagnostics.py" "$cpu_directory/harness/evaluate_parallel.sh" "$1"
