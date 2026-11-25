#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/harness/evaluate_clock_ports.sh"
CPU_EVAL_EXPECTED_MATCHED=2193 bash "$here/../_shared/run_fixed_test.sh"
