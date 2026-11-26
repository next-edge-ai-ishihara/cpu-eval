#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bash "$here/../_shared/run_fixed_test.sh"

results="${CPU_EVAL_RESULTS_DIR:?}/illegal-zero"
mkdir -p "$results"
simulator="$PWD/tools/riscv-dv/work/verilator/Vtb_top"
if ! riscv64-unknown-elf-gcc -march=rv32imc_zicsr -mabi=ilp32 -nostdlib \
    -Wl,--no-relax -Wl,--build-id=none -Wl,-Ttext=0x80000000 -Wl,--entry=_start \
    -o "$results/illegal_zero.elf" "$here/test/illegal_zero.s" >"$results/build.log" 2>&1 ||
   ! riscv64-unknown-elf-objcopy -O verilog "$results/illegal_zero.elf" "$results/program.hex" \
    >>"$results/build.log" 2>&1; then
    cat "$results/build.log" >&2
    printf 'CPU_EVAL_INVALID: the fixed program did not build\n' >&2
    exit 2
fi

status=0
(cd "$results" && ulimit -c 0 && timeout --verbose 600 "$simulator") >"$results/simulation.log" 2>&1 || status=$?
mapfile -t completion < <(grep -E '^\[[0-9]+ ns\] TEST_(PASSED|FAILED)$' "$results/simulation.log")
if [[ ${#completion[@]} == 1 ]]; then
    if [[ ${completion[0]} == *TEST_PASSED && $status == 0 ]]; then
        exit 0
    fi
    if [[ ${completion[0]} == *TEST_FAILED && $status == 0 ]]; then
        cat "$results/simulation.log" >&2
        exit 1
    fi
fi
cat "$results/simulation.log" >&2
exit 2
