#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ] || [ -e "$3" ]; then
  echo "usage: evaluate_ports.sh <Ibex checkout> <candidate> <new results directory>" >&2
  exit 2
fi
ibex=$(realpath "$1")
candidate=$(realpath "$2")
results=$(realpath -m "$3")
harness=$(cd "$(dirname "$0")/harness" && pwd)/register_file_ff_tb.sv
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
revision=$(git -c safe.directory="$ibex" -C "$ibex" rev-parse HEAD) || invalid 'register-file checkout'
if [ "$revision" != 405c6d1d8220a18b2f9196141167a5875422dee4 ]; then
  invalid 'register-file revision'
fi
include="$ibex/vendor/lowrisc_ip/ip/prim/rtl"
for tool in verilator timeout sha256sum; do
  command -v "$tool" >/dev/null || invalid "missing $tool"
done
sources=("$include/prim_secded_pkg.sv" "$ibex/rtl/ibex_cheriot_pkg.sv"
  "$ibex/rtl/ibex_pkg.sv" "$candidate" "$harness")
sha256sum "${sources[@]}" "$include/prim_assert.sv" >"$results/inputs.sha256"
verilator --version >"$results/verilator-version.txt"
command=(verilator --binary --timing --top-module register_file_ff_tb -Wno-fatal
  -j 4 -I"$include" --Mdir "$results/obj_dir" "${sources[@]}")
printf '%q ' "${command[@]}" >"$results/build-command.txt"
printf '\n' >>"$results/build-command.txt"
status=0
timeout 300 "${command[@]}" >"$results/build.log" 2>&1 || status=$?
printf '%s\n' "$status" >"$results/build-exit-code.txt"
executable="$results/obj_dir/Vregister_file_ff_tb"
if [ "$status" -ne 0 ] || [ ! -x "$executable" ]; then
  build_failed 'register-file port build' "$status" "$results/build.log"
fi
status=0
timeout 300 "$executable" >"$results/run.log" 2>&1 || status=$?
printf '%s\n' "$status" >"$results/run-exit-code.txt"
if [ "$status" -ne 0 ]; then run_failed 'register-file port execution' "$status"; fi
mapfile -t outcomes < <(grep -E '^REGFILE_CAP_(PASS$|MISMATCH )' "$results/run.log")
if [ "${#outcomes[@]}" -ne 1 ]; then run_failed 'register-file port outcome' 1; fi
case "${outcomes[0]}" in
  'REGFILE_CAP_MISMATCH '*)
    printf 'FAIL\tdirected public output mismatch\n' >"$results/verdict.tsv"
    exit 1
    ;;
  REGFILE_CAP_PASS) printf 'PASS\tregister-file capability outputs\n' >"$results/verdict.tsv" ;;
esac
