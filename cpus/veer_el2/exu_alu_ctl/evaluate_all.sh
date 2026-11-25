#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
CPU_EVAL_RESULTS_DIR="$results_dir/bitmanip" RISCV_DV_TEST=riscv_bitmanip_default_test_veer \
  bash "$here/../_shared/run_fixed_test.sh"
CPU_EVAL_RESULTS_DIR="$results_dir/directed" bash "$here/test/evaluate_alu_directed.sh"
