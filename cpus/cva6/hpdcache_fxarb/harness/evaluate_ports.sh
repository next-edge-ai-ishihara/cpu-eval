#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate_ports.sh <candidate-hpdcache_fxarb.sv>" >&2
  exit 2
fi
if [ -z "${CVA6_REPO:-}" ]; then
  echo "INVALID: CVA6_REPO is required" >&2
  exit 2
fi
script_directory=$(cd "$(dirname "$0")" && pwd)
candidate=$(realpath "$1")
log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
mkdir -p "$log_root" || exit 2
run_directory=$(mktemp -d "$log_root/fxarb-ports-XXXXXX") || exit 2
echo "fxarb port-test logs: $run_directory"
export CCACHE_DIR=${CCACHE_DIR:-$run_directory/ccache}
verilator=${VERILATOR:-verilator}
if ! "$verilator" --version > "$run_directory/tool.log" 2>&1; then
  echo "INVALID: Verilator is unavailable" >&2
  exit 2
fi
if ! GIT_NO_LAZY_FETCH=1 git -C "$CVA6_REPO/core/cache_subsystem/hpdcache" show \
  f404e7ebbda8baa4af3729535f520a6b12a06d03:rtl/src/common/hpdcache_prio_1hot_encoder.sv \
  > "$run_directory/encoder.sv" 2> "$run_directory/source.log"; then
  echo "INVALID: fixed priority encoder is unavailable" >&2
  exit 2
fi
extraction_rc=0
python3 "$script_directory/../../../../tools/cva6/replace_module.py" --module hpdcache_fxarb \
  --candidate "$candidate" --output "$run_directory/candidate.sv" 2>"$run_directory/extraction.log" ||
  extraction_rc=$?
if [ "$extraction_rc" -eq 1 ]; then
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define hpdcache_fxarb" >&2
  exit 1
elif [ "$extraction_rc" -ne 0 ]; then
  echo "INVALID: cannot extract the submitted hpdcache_fxarb module" >&2
  exit 2
fi
if ! cp "$script_directory/fxarb_ports_tb.sv" "$run_directory/tb.sv"; then
  echo "INVALID: cannot copy port-test inputs" >&2
  exit 2
fi
sha256sum "$run_directory/candidate.sv" "$run_directory/encoder.sv" "$run_directory/tb.sv" \
  > "$run_directory/inputs.sha256"
set +e
timeout 120 "$verilator" --binary --timing --assert -j 2 --top-module tb \
  --Mdir "$run_directory/obj" -Wno-fatal "$run_directory/candidate.sv" \
  "$run_directory/encoder.sv" "$run_directory/tb.sv" > "$run_directory/build.log" 2>&1
build_rc=$?
set -e
if [[ "$build_rc" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: fxarb port-test build wall-clock timeout" >&2
  exit 2
fi
if [ "$build_rc" -ne 0 ]; then
  classification=0
  python3 "$script_directory/../../harness/candidate_error.py" \
    "$run_directory/build.log" "$run_directory/candidate.sv" --directory "$run_directory" \
    --submitted "$run_directory/candidate.sv" \
    || classification=$?
  if [ "$classification" -eq 1 ]; then
    module_logs="$log_root/hpdcache_fxarb"
    mkdir -p "$module_logs" || exit 2
    compile_log=$(mktemp -d "$module_logs/fxarb-ports-XXXXXX") || exit 2
    cp "$run_directory/build.log" "$compile_log/build.log" || exit 2
    cp "$run_directory/build.log" "$compile_log/candidate-compile-error.txt" || exit 2
    printf '%s\n' 1 > "$compile_log/exit-code.txt" || exit 2
    rm -rf -- "$run_directory" || exit 2
    echo "fxarb compile-error logs: $compile_log"
    exit 1
  fi
  exit 2
fi
set +e
timeout 30 "$run_directory/obj/Vtb" > "$run_directory/runtime.log" 2>&1
runtime_rc=$?
set -e
if [[ "$runtime_rc" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: fxarb port-test wall-clock timeout" >&2
  exit 2
fi
if [ "$runtime_rc" -eq 0 ] && \
   grep -qx 'SUMMARY checks=261 errors=0' "$run_directory/runtime.log" && \
   grep -qx 'FXARB_PORT_TEST_COMPLETE' "$run_directory/runtime.log"; then
  echo "PASS: fxarb port contract"
else
  echo "FAIL: fxarb port contract" >&2
  exit 1
fi
