#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: evaluate_ports.sh <Ibex checkout> <candidate> <new results directory>" >&2
  exit 2
fi
ibex=$(realpath -m "$1")
candidate=$(realpath -m "$2")
results=$(realpath -m "$3")
harness=$(cd "$(dirname "$0")/harness" && pwd)/prefetch_grant_tb.cpp
if [ -e "$results" ]; then
  echo "results directory already exists: $results" >&2
  exit 2
fi
mkdir -p "$results"
# After only the candidate is built in, a failure is the answer's unless it is an interruption or a resource or tool failure.
build_failed() {
  if [ "$2" -eq 124 ] || [ "$2" -eq 137 ] || [ "$2" -eq 143 ] ||
      grep -qiE 'command not found|out of memory|cannot allocate memory|no space left on device' "$3"; then
    printf 'INVALID\t%s\n' "$1" >"$results/verdict.tsv"; exit 2
  fi
  printf 'FAIL\tcandidate compile diagnostic\t%s\n' "$1" >"$results/verdict.tsv"; exit 1
}
run_failed() {
  if [ "$2" -eq 124 ] || [ "$2" -eq 137 ] || [ "$2" -eq 143 ]; then
    printf 'INVALID\t%s interrupted\n' "$1" >"$results/verdict.tsv"; exit 2
  fi
  printf 'FAIL\tprogram did not complete\t%s\n' "$1" >"$results/verdict.tsv"; exit 1
}
invalid() { printf 'INVALID\t%s\n' "$1" >"$results/verdict.tsv"; exit 2; }
expected_revision=405c6d1d8220a18b2f9196141167a5875422dee4
revision=$(git -c safe.directory="$ibex" -C "$ibex" rev-parse HEAD 2>/dev/null) || invalid 'prefetch buffer checkout'
if [ "$revision" != "$expected_revision" ] || [ ! -f "$candidate" ] || [ ! -f "$harness" ]; then
  invalid 'prefetch buffer port inputs'
fi
for tool in verilator timeout sha256sum; do
  command -v "$tool" >/dev/null || invalid "missing $tool"
done
include="$ibex/vendor/lowrisc_ip/ip/prim/rtl"
test -f "$include/prim_assert.sv" || invalid 'prefetch buffer assertion include'
fifo="$ibex/rtl/ibex_fetch_fifo.sv"
fifo_sha256=3e0b48b771055ea50356cdff418decae16e7d9586a7f953e6799112b238bb63c
printf '%s  %s\n' "$fifo_sha256" "$fifo" | sha256sum --check --status ||
  invalid 'prefetch buffer dependency source'
{
  printf 'field\tvalue\nrevision\t%s\n' "$revision"
  printf 'candidate\t%s\ncandidate_sha256\t%s\n' "$candidate" "$(sha256sum "$candidate" | cut -d' ' -f1)"
  printf 'harness\t%s\nharness_sha256\t%s\n' "$harness" "$(sha256sum "$harness" | cut -d' ' -f1)"
  printf 'fifo_sha256\t%s\nResetAll\t0\n' "$fifo_sha256"
} >"$results/inputs.tsv"
verilator --version >"$results/verilator-version.txt"
export CCACHE_DIR="$results/ccache"
export CCACHE_TEMPDIR="$results/ccache-tmp"
mkdir -p "$CCACHE_DIR" "$CCACHE_TEMPDIR"
command=(verilator --cc --exe --build -j "${PREFETCH_BUILD_JOBS:-4}"
  --top-module ibex_prefetch_buffer -Wno-fatal -GResetAll=0
  -I"$include" --Mdir "$results/obj_dir" "$candidate" "$fifo" "$harness")
printf '%q ' "${command[@]}" >"$results/build-command.txt"
printf '\n' >>"$results/build-command.txt"
set +e
timeout "${PREFETCH_BUILD_TIMEOUT:-300}" "${command[@]}" >"$results/build.log" 2>&1
status=$?
set -e
printf '%s\n' "$status" >"$results/build-exit-code.txt"
executable="$results/obj_dir/Vibex_prefetch_buffer"
if [ "$status" -ne 0 ] || [ ! -x "$executable" ]; then build_failed 'prefetch buffer port build' "$status" "$results/build.log"; fi
printf '%q ' timeout "${PREFETCH_RUN_TIMEOUT:-300}" "$executable" >"$results/run-command.txt"
printf '\n' >>"$results/run-command.txt"
set +e
timeout "${PREFETCH_RUN_TIMEOUT:-300}" "$executable" >"$results/run.log" 2>&1
status=$?
set -e
printf '%s\n' "$status" >"$results/run-exit-code.txt"
if [ "$status" -eq 1 ] && grep -q '^PREFETCH_PORT_MISMATCH ' "$results/run.log"; then
  printf 'FAIL\tdirected public output mismatch\n' >"$results/verdict.tsv"
  exit 1
fi
if [ "$status" -ne 0 ] || ! grep -qx 'PASS prefetch request held until grant' "$results/run.log"; then
  run_failed 'prefetch buffer port execution' "$status"
fi
printf 'PASS\tprefetch buffer ports\n' >"$results/verdict.tsv"
