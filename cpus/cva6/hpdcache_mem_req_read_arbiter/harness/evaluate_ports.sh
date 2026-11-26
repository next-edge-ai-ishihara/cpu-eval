#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate_ports.sh <candidate-hpdcache_mem_req_read_arbiter.sv>" >&2
  exit 2
fi
if [ -z "${CVA6_REPO:-}" ] || [ -z "${CPU_EVAL_LOG_ROOT:-}" ]; then
  echo "INVALID: CVA6_REPO and CPU_EVAL_LOG_ROOT are required" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
candidate=$(realpath "$1")
mkdir -p "$CPU_EVAL_LOG_ROOT" || exit 2
run_directory=$(mktemp -d "$CPU_EVAL_LOG_ROOT/read-arbiter-ports-XXXXXX") || exit 2
echo "Read arbiter port-test logs: $run_directory"
export CCACHE_DIR=${CCACHE_DIR:-$run_directory/ccache}
verilator=${VERILATOR:-verilator}
if ! "$verilator" --version >"$run_directory/tool.log" 2>&1; then
  echo "INVALID: Verilator is unavailable" >&2
  exit 2
fi

hpdcache="$CVA6_REPO/core/cache_subsystem/hpdcache"
revision=f404e7ebbda8baa4af3729535f520a6b12a06d03
sources=()
for name in hpdcache_fxarb hpdcache_prio_1hot_encoder hpdcache_mux hpdcache_1hot_to_binary; do
  source="$run_directory/$name.sv"
  if ! GIT_NO_LAZY_FETCH=1 git -C "$hpdcache" show "$revision:rtl/src/common/$name.sv" \
    >"$source" 2>>"$run_directory/source.log"; then
    echo "INVALID: fixed dependency $name is unavailable" >&2
    exit 2
  fi
  sources+=("$source")
done
extraction_rc=0
python3 "$script_directory/../../../../tools/cva6/replace_module.py" --module hpdcache_mem_req_read_arbiter \
  --candidate "$candidate" --output "$run_directory/candidate.sv" >"$run_directory/extraction.log" 2>&1 ||
  extraction_rc=$?
if [ "$extraction_rc" -eq 1 ]; then
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define hpdcache_mem_req_read_arbiter" >&2
  exit 1
elif [ "$extraction_rc" -ne 0 ]; then
  echo "INVALID: cannot extract the submitted read arbiter module" >&2
  exit 2
fi
if ! cp "$script_directory/read_arbiter_ports_tb.sv" "$run_directory/tb.sv"; then
  echo "INVALID: cannot copy port-test inputs" >&2
  exit 2
fi
sha256sum "$run_directory/candidate.sv" "$run_directory/tb.sv" "${sources[@]}" >"$run_directory/inputs.sha256"

build_status=0
timeout 120 "$verilator" --binary --timing --assert -j 2 --top-module tb \
  --Mdir "$run_directory/obj" -Wno-fatal "$run_directory/candidate.sv" \
  "${sources[@]}" "$run_directory/tb.sv" >"$run_directory/build.log" 2>&1 || build_status=$?
if [[ "$build_status" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: read arbiter port-test build timed out" >&2
  exit 2
fi
if [ "$build_status" -ne 0 ]; then
  classification=0
  python3 "$script_directory/../../harness/candidate_error.py" "$run_directory/build.log" \
    "$run_directory/candidate.sv" --directory "$run_directory" \
    --submitted "$run_directory/candidate.sv" || classification=$?
  if [ "$classification" -ne 1 ]; then
    exit 2
  fi
  module_logs="$CPU_EVAL_LOG_ROOT/hpdcache_mem_req_read_arbiter"
  mkdir -p "$module_logs" || exit 2
  compile_log=$(mktemp -d "$module_logs/read-arbiter-ports-XXXXXX") || exit 2
  mv "$run_directory/build.log" "$compile_log/build.log" || exit 2
  cp "$compile_log/build.log" "$compile_log/candidate-compile-error.txt" || exit 2
  printf '%s\n' 1 > "$compile_log/exit-code.txt" || exit 2
  rm -rf -- "$run_directory" || exit 2
  echo "Read arbiter compile-error logs: $compile_log"
  exit 1
fi

runtime_status=0
timeout 30 "$run_directory/obj/Vtb" >"$run_directory/runtime.log" 2>&1 || runtime_status=$?
if [[ "$runtime_status" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: read arbiter port-test simulation timed out" >&2
  exit 2
fi
if [ "$runtime_status" -eq 0 ] &&
   grep -qx 'SUMMARY checks=8 errors=0' "$run_directory/runtime.log" &&
   grep -qx 'READ_ARBITER_PORT_TEST_COMPLETE' "$run_directory/runtime.log"; then
  echo "PASS: read arbiter port contract"
else
  echo "FAIL: read arbiter port contract" >&2
  exit 1
fi
