#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
results="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results" || { printf 'CPU_EVAL_INVALID: cannot create %s\n' "$results" >&2; exit 2; }
bash "$here/../../_shared/run_fixed_test.sh"
probe_results="$(mktemp -d "$results/rvrangecheck-boundary.XXXXXXXX")" ||
  { printf 'CPU_EVAL_INVALID: cannot create the boundary test workspace\n' >&2; exit 2; }
printf 'rvrangecheck boundary results: %s\n' "$probe_results"
python3 "$here/run_boundary_probe.py" \
  --source "$PWD/design/lib/beh_lib.sv" \
  --results "$probe_results"
