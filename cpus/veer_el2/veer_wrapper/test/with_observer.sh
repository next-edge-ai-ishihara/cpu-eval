#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
if [ -n "${CPU_EVAL_REAL_VERILATOR:-}" ]; then
  exec "$@"
fi
export CPU_EVAL_REAL_VERILATOR
CPU_EVAL_REAL_VERILATOR=$(command -v verilator) || {
  printf 'CPU_EVAL_INVALID: Verilator is not on PATH\n' >&2
  exit 2
}
observer_root=${CPU_EVAL_OBSERVER_RAM_ROOT:-/dev/shm}
observer_bin=$(mktemp -d "$observer_root/cpu-eval-wrapper-bin-XXXXXXXX") ||
  { printf 'CPU_EVAL_INVALID: cannot create the observer directory\n' >&2; exit 2; }
trap 'rm -f "$observer_bin/verilator"; rmdir "$observer_bin"' EXIT
ln -s "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/observer_verilator.py" "$observer_bin/verilator" ||
  { printf 'CPU_EVAL_INVALID: cannot install the trace observer\n' >&2; exit 2; }
export PATH="$observer_bin:$PATH"
set +e
"$@"
status=$?
set -e
exit "$status"
