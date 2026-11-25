#!/usr/bin/env bash
set -euo pipefail
problem_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$problem_dir/../_shared/run_fixed_test.sh"
python3 -B "$problem_dir/test/run_order_probe.py" \
  --checkout "$PWD" \
  --testbench "$problem_dir/test/order_probe.sv" \
  --results "${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}/bus-order"
