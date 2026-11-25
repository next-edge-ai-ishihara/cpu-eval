#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: evaluate_ports.sh <Ibex checkout> <candidate> <results>" >&2
  exit 2
fi

ibex=$(realpath "$1")
candidate=$(realpath "$2")
results=$(realpath -m "$3")
harness=$(cd "$(dirname "$0")/harness" && pwd)/csr_tb.cpp
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
  printf 'INVALID\tCSR port inputs\n' >"$results/verdict.tsv"
  exit 2
fi

for configuration in 32:0 32:1; do
  IFS=: read -r width reset <<<"$configuration"
  run="$results/width-${width}-reset-${reset}"
  mkdir -p "$run"
  command=(verilator --cc --exe --build --top-module ibex_csr -Wno-fatal
    -I"$ibex/vendor/lowrisc_ip/ip/prim/rtl"
    "-GWidth=$width" "-GResetValue=$reset" -GShadowCopy=0
    -CFLAGS "-DCSR_WIDTH=$width -DCSR_RESET_VALUE=$reset"
    --Mdir "$run/obj_dir" "$candidate" "$harness")
  printf '%q ' "${command[@]}" >"$run/build-command.txt"
  printf '\n' >>"$run/build-command.txt"
  set +e
  timeout "${CSR_BUILD_TIMEOUT:-300}" "${command[@]}" >"$run/build.log" 2>&1
  status=$?
  set -e
  printf '%s\n' "$status" >"$run/build-exit-code.txt"
  executable="$run/obj_dir/Vibex_csr"
  if [ "$status" -ne 0 ] || [ ! -x "$executable" ]; then
    build_failed "CSR port build $configuration" "$status" "$run/build.log"
  fi
  printf '%q ' timeout "${CSR_RUN_TIMEOUT:-300}" "$executable" >"$run/run-command.txt"
  printf '\n' >>"$run/run-command.txt"
  set +e
  timeout "${CSR_RUN_TIMEOUT:-300}" "$executable" >"$run/run.log" 2>&1
  status=$?
  set -e
  printf '%s\n' "$status" >"$run/run-exit-code.txt"
  if [ "$status" -eq 1 ] && grep -q '^CSR_PORT_MISMATCH ' "$run/run.log"; then
    printf 'FAIL\tdirected public output mismatch\t%s\n' "$configuration" >"$results/verdict.tsv"
    exit 1
  fi
  if [ "$status" -ne 0 ] || ! grep -qE "^CSR_PORT_PASS width=$width reset=[0-9a-f]{8} observations=[0-9]+$" "$run/run.log"; then
    run_failed "CSR port execution $configuration" "$status"
  fi
done
printf 'PASS\tCSR ports\n' >"$results/verdict.tsv"
