#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$test_dir/../../_shared/run_fixed_test.sh"

results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-rvsyncss.XXXXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
config_dir="$PWD/tools/riscv-dv/work"
build_log="$results_dir/rvsyncss_port_probe.build.log"
probe_log="$results_dir/rvsyncss_port_probe.log"
status_file="$results_dir/rvsyncss_port_probe.status"

if ! timeout --verbose 120 verilator --binary --timing -Wno-fatal -j 2 \
    --top-module rvsyncss_port_probe --Mdir "$build_dir/obj" \
    "$config_dir/common_defines.vh" "$PWD/design/lib/beh_lib.sv" \
    "$test_dir/rvsyncss_port_probe.sv" >"$build_log" 2>&1; then
   printf '2\n' >"$status_file"
   cat "$build_log" >&2
   exit 2
fi
if ! timeout --verbose 10 "$build_dir/obj/Vrvsyncss_port_probe" >"$probe_log" 2>&1; then
   printf '2\n' >"$status_file"
   cat "$probe_log" >&2
   exit 2
fi
cat "$probe_log"
if grep -q '^RVSYNCSS_PORT_FAIL ' "$probe_log"; then
   printf '1\n' >"$status_file"
   exit 1
fi
if ! grep -Fxq 'RVSYNCSS_PORT_PASS widths=1,7,251' "$probe_log"; then
   printf '2\n' >"$status_file"
   exit 2
fi
printf '0\n' >"$status_file"
