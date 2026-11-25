#!/usr/bin/env bash
set -euo pipefail

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"

CPU_EVAL_RESULTS_DIR="$results_dir/alignment" \
bash "$(dirname "${BASH_SOURCE[0]}")/../_shared/run_fixed_test.sh"

python3 "$(dirname "${BASH_SOURCE[0]}")/harness/run_alignment_ports.py" \
  --cpu-root "$PWD" --results "$results_dir/alignment_ports"
