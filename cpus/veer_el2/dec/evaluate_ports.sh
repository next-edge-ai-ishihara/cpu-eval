#!/usr/bin/env bash
set -euo pipefail
export RV_ROOT="$PWD"
python3 -B "$(dirname "${BASH_SOURCE[0]}")/test/run_dec_port_probe.py"
