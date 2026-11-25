#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "usage: evaluate_primitive.sh <Ibex checkout> <candidate> <C++ harness> <top module> <results>" >&2
  exit 2
fi

ibex=$(realpath "$1")
candidate=$(realpath "$2")
harness=$(realpath "$3")
top_module=$4
results=$(realpath -m "$5")

run_primitive() {
  local output=$1
  shift
  mkdir -p "$output" || return 2
  local executable="$output/obj_dir/V$top_module"
  if ! verilator --cc --exe --build --top-module "$top_module" -Wno-fatal \
      -I"$ibex/vendor/lowrisc_ip/ip/prim/rtl" \
      "$@" --Mdir "$output/obj_dir" "$candidate" "$harness" \
      >"$output/build.log" 2>&1 || [ ! -x "$executable" ]; then
    if grep -qiE 'command not found|out of memory|cannot allocate memory|no space left on device' "$output/build.log"; then
      printf 'INVALID\tdirected primitive build environment\n' >"$output/verdict.tsv"
      return 2
    fi
    printf 'FAIL\tcandidate compile diagnostic\n' >"$output/verdict.tsv"
    return 1
  fi

  local run_status=0
  "$executable" >"$output/run.log" 2>&1 || run_status=$?
  if grep -q '^MISMATCH ' "$output/run.log"; then
    printf 'FAIL\tdirected primitive output mismatch\n' >"$output/verdict.tsv"
    return 1
  fi
  if [ "$run_status" -eq 0 ] && grep -q '^PASS$' "$output/run.log"; then
    printf 'PASS\tdirected primitive outputs\n' >"$output/verdict.tsv"
    return 0
  fi
  printf 'FAIL\tprogram did not complete\n' >"$output/verdict.tsv"
  return 1
}

case "$top_module" in
  prim_buf)
    run_primitive "$results" -GWidth=32 || exit $?
    status=0
    run_primitive "$results/width-4" -GWidth=4 -CFLAGS -DCPU_EVAL_PRIM_BUF_WIDTH_4 || status=$?
    if [ "$status" -ne 0 ]; then
      if [ -f "$results/width-4/verdict.tsv" ]; then
        cp "$results/width-4/verdict.tsv" "$results/verdict.tsv"
      else
        printf 'INVALID\tdirected primitive execution\n' >"$results/verdict.tsv"
        exit 2
      fi
    fi
    exit "$status"
    ;;
  prim_clock_gating)
    run_primitive "$results"
    ;;
  *)
    echo "unsupported primitive: $top_module" >&2
    exit 2
    ;;
esac
