#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo "usage: evaluate_ports.sh <Ibex checkout> <candidate> <results>" >&2
  exit 2
fi
ibex=$(realpath "$1")
candidate=$(realpath "$2")
results=$(realpath -m "$3")
harness=$(cd "$(dirname "$0")/harness" && pwd)/counter_tb.cpp
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
expected_revision=405c6d1d8220a18b2f9196141167a5875422dee4
if [ "$(git -c safe.directory="$ibex" -C "$ibex" rev-parse HEAD)" != "$expected_revision" ] || [ ! -f "$candidate" ]; then
  printf 'INVALID\tCounter port inputs\n' >"$results/verdict.tsv"
  exit 2
fi
for provide in 0 1; do
  run="$results/width-64-provide-$provide"
  mkdir -p "$run"
  command=(verilator --cc --exe --build --top-module ibex_counter -Wno-fatal
    -I"$ibex/vendor/lowrisc_ip/ip/prim/rtl"
    -GCounterWidth=64 "-GProvideValUpd=$provide"
    -CFLAGS "-DCOUNTER_PROVIDE_VAL_UPD=$provide"
    --Mdir "$run/obj_dir" "$candidate" "$harness")
  printf '%q ' "${command[@]}" >"$run/build-command.txt"
  printf '\n' >>"$run/build-command.txt"
  set +e
  timeout "${COUNTER_BUILD_TIMEOUT:-300}" "${command[@]}" >"$run/build.log" 2>&1
  status=$?
  set -e
  printf '%s\n' "$status" >"$run/build-exit-code.txt"
  executable="$run/obj_dir/Vibex_counter"
  if [ "$status" -ne 0 ] || [ ! -x "$executable" ]; then
    build_failed "Counter port build 64:$provide" "$status" "$run/build.log"
  fi
  printf '%q ' timeout "${COUNTER_RUN_TIMEOUT:-300}" "$executable" >"$run/run-command.txt"
  printf '\n' >>"$run/run-command.txt"
  set +e
  timeout "${COUNTER_RUN_TIMEOUT:-300}" "$executable" >"$run/run.log" 2>&1
  status=$?
  set -e
  printf '%s\n' "$status" >"$run/run-exit-code.txt"
  if [ "$status" -eq 1 ] && grep -q '^COUNTER_PORT_MISMATCH ' "$run/run.log"; then
    printf 'FAIL\tdirected public output mismatch\t64:%s\n' "$provide" >"$results/verdict.tsv"
    exit 1
  fi
  if [ "$status" -ne 0 ] || ! grep -qE "^COUNTER_PORT_PASS width=64 provide=$provide observations=[0-9]+$" "$run/run.log"; then
    run_failed "Counter port execution 64:$provide" "$status"
  fi
done
printf 'PASS\tCounter ports\n' >"$results/verdict.tsv"
