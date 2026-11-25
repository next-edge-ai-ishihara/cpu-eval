#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-issue_read_operands.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_issue_read_operands.yaml"
export CVA6_TEST_JOBS=2
exec "$cpu_directory/harness/evaluate_parallel.sh" issue_read_operands "$1"
