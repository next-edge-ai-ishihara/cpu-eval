#!/usr/bin/env bash
set -uo pipefail

candidate=${1:-}
if [ -z "$candidate" ] || [ ! -f "$candidate" ]; then
  echo "usage: evaluate.sh <candidate-cva6_fifo_v3.sv>" >&2
  exit 2
fi

harness_dir=$(cd "$(dirname "$0")" && pwd)
CVA6_TESTLIST="$harness_dir/testlist_cva6_fifo_v3.yaml" \
  exec "$harness_dir/../../harness/evaluate_parallel.sh" cva6_fifo_v3 "$candidate"
