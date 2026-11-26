#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0
results_dir="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
here="$(dirname "${BASH_SOURCE[0]}")"
CPU_EVAL_RESULTS_DIR="$results_dir/arithmetic" bash "$here/../_shared/run_fixed_test.sh"
CPU_EVAL_RESULTS_DIR="$results_dir/addrcheck_ports" python3 -B "$here/test/run_addrcheck_port_probe.py"
