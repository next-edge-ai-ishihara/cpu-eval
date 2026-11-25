#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-sram_cache.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
log_parent=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
mkdir -p "$log_parent"
unit_log=$(mktemp -d "$(dirname "$log_parent")/sram-cache-user-test-XXXXXX")
python3 "$script_directory/test_user.py" --candidate "$1" \
  --checkout "${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}" \
  --log-root "$unit_log/results" \
  --compile-marker-root "$log_parent/sram_cache"
export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_icache_sram.yaml"
export CVA6_TEST_JOBS=4
exec "$cpu_directory/harness/evaluate_parallel.sh" sram_cache "$1"
