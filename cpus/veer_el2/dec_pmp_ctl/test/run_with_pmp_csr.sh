#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
results=${CPU_EVAL_RESULTS_DIR:-"$PWD/cpu-eval-results"}
mkdir -p "$results" || { echo "CPU_EVAL_INVALID: cannot create $results" >&2; exit 2; }
probe=$(mktemp -d "$results/pmp-csr.XXXXXXXX") || { echo "CPU_EVAL_INVALID: cannot create the PMP test workspace" >&2; exit 2; }
bash "$here/../../_shared/run_fixed_test.sh"
configuration=$PWD/tools/riscv-dv/work
if ! verilator --version >"$probe/version.log" ||
   ! grep -Eq '^Verilator 5\.036([[:space:]]|$)' "$probe/version.log"; then
    echo "CPU_EVAL_INVALID: PMP CSR test requires Verilator 5.036" >&2
    exit 2
fi
if ! verilator --binary --timing -Wno-fatal -j 2 --top-module check_pmp_csr \
    --Mdir "$probe/obj" "-I$configuration" \
    "$configuration/common_defines.vh" design/include/el2_def.sv \
    design/lib/beh_lib.sv design/dec/el2_dec_pmp_ctl.sv "$here/check_pmp_csr.sv" \
    >"$probe/build.log" 2>&1; then
    cat "$probe/build.log" >&2
    exit 2
fi
if ! "$probe/obj/Vcheck_pmp_csr" >"$probe/run.log" 2>&1; then
    cat "$probe/run.log" >&2
    exit 2
fi
mapfile -t counts < <(sed -nE 's/^PMP_CSR_CHECK_COMPLETE errors=([0-9]+)$/\1/p' "$probe/run.log")
if [[ ${#counts[@]} != 1 ]]; then
    cat "$probe/run.log" >&2
    exit 2
fi
if [[ ${counts[0]} != 0 ]]; then
    cat "$probe/run.log"
    exit 1
fi
