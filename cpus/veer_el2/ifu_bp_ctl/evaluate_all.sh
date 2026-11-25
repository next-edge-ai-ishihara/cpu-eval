#!/usr/bin/env bash
set -euo pipefail
export RV_ROOT="$PWD"
make -C tools/riscv-dv work/defines.h || {
  printf 'CPU_EVAL_INVALID: the fixed configuration was not generated\n' >&2
  exit 2
}
python3 "$(dirname "${BASH_SOURCE[0]}")/harness/run_prediction_ports.py" \
  --cpu-root "$PWD" --results "${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
