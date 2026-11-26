#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
results="${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}"
bash "$here/../_shared/run_fixed_test.sh"

work=$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-cache-tag.XXXXXXXX")
trap 'rm -rf -- "$work"' EXIT
source=design/lib/beh_lib.sv
config=tools/riscv-dv/work/common_defines.vh
probe="$here/test/cache_tag_probe.sv"
sha256sum "$source" "$config" "$probe" >"$results/cache_tag_inputs.sha256"
verilator --version >"$results/cache_tag_verilator.txt"
if ! CCACHE_DISABLE=1 verilator --binary --timing -j 2 -Wno-fatal -CFLAGS -g0 --top-module cache_tag_probe --Mdir "$work" "$config" "$source" "$probe" >"$results/cache_tag_build.log" 2>&1; then
    cat "$results/cache_tag_build.log" >&2
    exit 2
fi

run_log="$results/cache_tag_probe.log"
if ! "$work/Vcache_tag_probe" >"$run_log" 2>&1; then
    cat "$run_log" >&2
    exit 2
fi
cat "$run_log"
if [[ $(grep -c '^CACHE_TAG_PORT_OBSERVATION ' "$run_log") -ne 5 ]] ||
   [[ $(grep -c '^CACHE_TAG_PORT_COMPLETE$' "$run_log") -ne 1 ]]; then
    exit 2
fi
if grep -q '^CACHE_TAG_PORT_MISMATCH ' "$run_log"; then
    exit 1
fi
