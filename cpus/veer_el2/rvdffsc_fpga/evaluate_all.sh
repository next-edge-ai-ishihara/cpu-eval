#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0
results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
here="$(dirname "${BASH_SOURCE[0]}")"
CPU_EVAL_RESULTS_DIR="$results_dir/dma" bash "$here/test/evaluate_rvdffsc_fpga.sh"
CPU_EVAL_RESULTS_DIR="$results_dir/clock_gate_ports" python3 -B "$here/test/run_clock_gate_probe.py"
