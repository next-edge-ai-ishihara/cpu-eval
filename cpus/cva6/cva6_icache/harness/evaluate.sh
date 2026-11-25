#!/usr/bin/env bash
set -uo pipefail

candidate=${1:-}
if [ -z "$candidate" ] || [ ! -f "$candidate" ]; then
  echo "usage: evaluate.sh <candidate-cva6_icache.sv>" >&2
  exit 2
fi

harness_dir=$(cd "$(dirname "$0")" && pwd)
scratch=$(mktemp -d) || exit 2
trap 'rm -rf "$scratch"' EXIT
export CVA6_TESTLIST="$scratch/testlist.yaml"
if ! cat "$harness_dir/../../harness/testlist_cv32a60x.yaml" "$harness_dir/fence_i_test.yaml" >"$CVA6_TESTLIST" ||
   ! cp "$harness_dir/icache_fence_i.S" "$scratch/"; then
  exit 2
fi
"$harness_dir/../../harness/evaluate_parallel.sh" cva6_icache "$candidate"
