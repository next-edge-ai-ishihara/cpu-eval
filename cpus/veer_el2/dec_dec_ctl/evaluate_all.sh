#!/usr/bin/env bash
set -euo pipefail

results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"

CPU_EVAL_RESULTS_DIR="$results_dir/arithmetic" \
CPU_EVAL_EXPECTED_MATCHED=2193 \
RISCV_DV_TEST=riscv_arithmetic_basic_test \
bash "$(dirname "${BASH_SOURCE[0]}")/../_shared/run_fixed_test.sh"

CPU_EVAL_RESULTS_DIR="$results_dir/bitmanip" \
RISCV_DV_TEST=riscv_bitmanip_default_test_veer \
CPU_EVAL_EXPECTED_MATCHED=77 \
bash "$(dirname "${BASH_SOURCE[0]}")/../_shared/run_fixed_test.sh"

CPU_EVAL_RESULTS_DIR="$results_dir/decode_ports" \
python3 -B "$(dirname "${BASH_SOURCE[0]}")/test/check_decode_ports.py"
