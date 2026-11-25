#!/usr/bin/env bash
set -euo pipefail
script_directory=$(cd "$(dirname "$0")" && pwd)
python3 "$script_directory/evaluate_ports.py" "$PWD/design/lib/beh_lib.sv"
bash "$script_directory/../_shared/run_fixed_test.sh"
