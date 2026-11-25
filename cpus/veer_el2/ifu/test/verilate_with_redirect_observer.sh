#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

for option in "$@"; do
    if [[ "$option" == "--cc" ]]; then
        exec verilator "$@" "$(dirname "${BASH_SOURCE[0]}")/observe_fetch_redirect.sv"
    fi
done
exec verilator "$@"
