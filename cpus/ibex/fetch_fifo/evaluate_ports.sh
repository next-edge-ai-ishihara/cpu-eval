#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: evaluate_ports.sh <Ibex checkout> <candidate> <new results directory>" >&2
  exit 2
fi
ibex=$(realpath -m "$1")
candidate=$(realpath -m "$2")
results=$(realpath -m "$3")
harness=$(cd "$(dirname "$0")/harness" && pwd)/fetch_fifo_error_tb.cpp
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
revision=$(git -c safe.directory="$ibex" -C "$ibex" rev-parse HEAD 2>/dev/null) || invalid 'fetch FIFO checkout'
if [ "$revision" != "$expected_revision" ] || [ ! -f "$candidate" ] || [ ! -f "$harness" ]; then
  invalid 'fetch FIFO port inputs'
fi
for tool in verilator timeout sha256sum; do
  command -v "$tool" >/dev/null || invalid "missing $tool"
done
include="$ibex/vendor/lowrisc_ip/ip/prim/rtl"
test -f "$include/prim_assert.sv" || invalid 'fetch FIFO assertion include'
{
  printf 'field\tvalue\nrevision\t%s\n' "$revision"
  printf 'candidate\t%s\ncandidate_sha256\t%s\n' "$candidate" "$(sha256sum "$candidate" | cut -d' ' -f1)"
  printf 'harness\t%s\nharness_sha256\t%s\n' "$harness" "$(sha256sum "$harness" | cut -d' ' -f1)"
  printf 'NUM_REQS\t2\nResetAll\t0\n'
} >"$results/inputs.tsv"
verilator --version >"$results/verilator-version.txt"
export CCACHE_DIR="$results/ccache"
export CCACHE_TEMPDIR="$results/ccache-tmp"
mkdir -p "$CCACHE_DIR" "$CCACHE_TEMPDIR"
command=(verilator --cc --exe --build -j "${FETCH_FIFO_BUILD_JOBS:-4}"
  --top-module ibex_fetch_fifo -Wno-fatal -GNUM_REQS=2 -GResetAll=0
  -I"$include" --Mdir "$results/obj_dir" "$candidate" "$harness")
printf '%q ' "${command[@]}" >"$results/build-command.txt"
printf '\n' >>"$results/build-command.txt"
set +e
timeout "${FETCH_FIFO_BUILD_TIMEOUT:-300}" "${command[@]}" >"$results/build.log" 2>&1
status=$?
set -e
printf '%s\n' "$status" >"$results/build-exit-code.txt"
executable="$results/obj_dir/Vibex_fetch_fifo"
if [ "$status" -ne 0 ] || [ ! -x "$executable" ]; then build_failed 'fetch FIFO port build' "$status" "$results/build.log"; fi
printf '%q ' timeout "${FETCH_FIFO_RUN_TIMEOUT:-300}" "$executable" >"$results/run-command.txt"
printf '\n' >>"$results/run-command.txt"
set +e
timeout "${FETCH_FIFO_RUN_TIMEOUT:-300}" "$executable" >"$results/run.log" 2>&1
status=$?
set -e
printf '%s\n' "$status" >"$results/run-exit-code.txt"
if [ "$status" -eq 1 ] && grep -q '^FETCH_FIFO_PORT_MISMATCH ' "$results/run.log"; then
  printf 'FAIL\tdirected public output mismatch\n' >"$results/verdict.tsv"
  exit 1
fi
if [ "$status" -ne 0 ] || ! grep -qx 'PASS all selected fetch error cases' "$results/run.log"; then
  run_failed 'fetch FIFO port execution' "$status"
fi
printf 'PASS\tfetch FIFO ports\n' >"$results/verdict.tsv"
