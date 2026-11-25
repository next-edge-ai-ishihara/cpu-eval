#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-issue_stage.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)

python3 "$script_directory/check_issue_ports.py" "$1"

export CPU_EVAL_MODULE=issue_stage
export CVA6_TESTLIST="$cpu_directory/copro_alu/harness/testlist_copro_alu.yaml"
exec "$cpu_directory/copro_alu/harness/evaluate.sh" "$1"
