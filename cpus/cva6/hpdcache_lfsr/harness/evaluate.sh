#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_lfsr.sv>" >&2
  exit 2
fi

lock_repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$lock_repo.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $lock_repo" >&2
    exit 2
  fi
else
  exec 9>"$lock_repo.cpu-eval.lock" || { echo "INVALID: cannot open the evaluation lock" >&2; exit 2; }
fi
flock -n 9 || { echo "INVALID: another evaluation owns $lock_repo" >&2; exit 2; }
export CVA6_EVALUATION_LOCK_FD=9
export CVA6_TARGET=cv32a60x

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)
export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4

log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the evaluation results directory}
candidate=$(realpath "$1")
work=$(mktemp -d) || exit 2
trap 'find "$work" -depth -delete' EXIT
extraction_rc=0
python3 "$cpu_directory/../../tools/cva6/replace_module.py" --module hpdcache_lfsr \
    --candidate "$candidate" --output "$work/candidate.sv" 2>"$work/build.log" || extraction_rc=$?
if [ "$extraction_rc" -ne 0 ]; then
  [ "$extraction_rc" -eq 1 ] || { echo "INVALID: cannot extract the submitted hpdcache_lfsr module" >&2; exit 2; }
  mkdir -p "$log_root/hpdcache_lfsr" || exit 2
  logs=$(mktemp -d "$log_root/hpdcache_lfsr/port-build-XXXXXX") || exit 2
  mv "$work/build.log" "$logs/build.log" || exit 2
  cp "$logs/build.log" "$logs/candidate-compile-error.txt" || exit 2
  echo 1 > "$logs/exit-code.txt" || exit 2
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define hpdcache_lfsr" >&2
  exit 1
fi
hpdcache="$lock_repo/core/cache_subsystem/hpdcache/rtl"
common_cells="$lock_repo/vendor/pulp-platform/common_cells"
build_rc=0
verilator --binary --timing -Wno-fatal --top-module lfsr_ports_tb \
     -j "${CPU_EVAL_BUILD_JOBS:-${NUM_JOBS:-1}}" --Mdir "$work/build" \
     -I"$hpdcache/include" -y "$hpdcache/src/common" \
     -I"$common_cells/include" -y "$common_cells/src" \
     "$hpdcache/src/hpdcache_pkg.sv" "$work/candidate.sv" "$script_directory/lfsr_ports_tb.sv" \
     > "$work/build.log" 2>&1 || build_rc=$?
if [ "$build_rc" -ne 0 ]; then
  build_status=2
  if ! [[ "$build_rc" =~ ^(124|126|127|137|143)$ ]]; then
    build_status=0
    python3 "$cpu_directory/harness/candidate_error.py" "$work/build.log" "$work/candidate.sv" \
      --submitted "$work/candidate.sv" || build_status=$?
  fi
  mkdir -p "$log_root/hpdcache_lfsr" || exit 2
  logs=$(mktemp -d "$log_root/hpdcache_lfsr/port-build-XXXXXX") || exit 2
  mv "$work/build.log" "$logs/build.log" || exit 2
  printf '%s\n' "$build_status" > "$logs/exit-code.txt"
  if [ "$build_status" -eq 1 ]; then
    cp "$logs/build.log" "$logs/candidate-compile-error.txt" || exit 2
    exit 1
  fi
  exit 2
fi

"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_lfsr "$candidate"
logs="$log_root/lfsr-ports"
mkdir -p "$logs" || exit 2
mv "$work/build.log" "$logs/build.log" || exit 2
runtime_rc=0
timeout 30 "$work/build/Vlfsr_ports_tb" > "$logs/observations.log" 2>&1 || runtime_rc=$?
if [[ "$runtime_rc" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: LFSR port observation was stopped from outside" >&2
  exit 2
fi
mapfile -t outcomes < <(grep -E '^LFSR_PORTS_(PASS 1 width|FAIL)$' "$logs/observations.log")
if [ "$runtime_rc" -ne 0 ] || [ "${#outcomes[@]}" -ne 1 ] || [[ ${outcomes[0]} == LFSR_PORTS_FAIL ]]; then
  echo "FAIL: LFSR reset, enable, period or linear transition did not match the contract" >&2
  exit 1
fi
echo "PASS: CPU trace and LFSR ports match"
