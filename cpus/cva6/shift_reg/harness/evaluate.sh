#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    echo "usage: evaluate.sh <candidate-shift_reg.sv>" >&2
    exit 2
fi
script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
"$cpu_directory/harness/evaluate_parallel.sh" shift_reg "$1"
python3 "$script_directory/evaluate_shift_reg_ports.py" "$1"
