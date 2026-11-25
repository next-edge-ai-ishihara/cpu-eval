#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/harness/evaluate_debug_ports.sh"
bash "$here/../_shared/run_fixed_test.sh"
