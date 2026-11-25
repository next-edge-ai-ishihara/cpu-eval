#!/usr/bin/env bash
set -euo pipefail
export RV_ROOT="$PWD"
results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
CPU_EVAL_RESULTS_DIR="$results_dir/arithmetic" \
CPU_EVAL_EXPECTED_MATCHED=2193 \
RISCV_DV_TEST=riscv_arithmetic_basic_test \
bash "$(dirname "${BASH_SOURCE[0]}")/../_shared/run_fixed_test.sh"

CPU_EVAL_RESULTS_DIR="$results_dir/decode_ports" \
CPU_EVAL_DECODER_PROBE_CONFIG="$RV_ROOT/tools/riscv-dv/work" \
python3 -B "$(dirname "${BASH_SOURCE[0]}")/test/run_decode_port_probe.py"
