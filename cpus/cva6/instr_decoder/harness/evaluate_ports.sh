#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate_ports.sh <candidate-instr_decoder.sv>" >&2
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
run_directory=$(mktemp -d "$log_root/instr-decoder-ports-XXXXXX") || exit 2
echo "instr-decoder port-test logs: $run_directory"
export CCACHE_DIR=${CCACHE_DIR:-$run_directory/ccache}
verilator=${VERILATOR:-verilator}
if ! "$verilator" --version > "$run_directory/tool.log" 2>&1; then
  echo "INVALID: Verilator is unavailable" >&2
  exit 2
fi
core_revision=6348e9e684678f83b40d0520028513d06b36e7b2
sources=(core/include/config_pkg.sv core/include/cv32a60x_config_pkg.sv
         core/include/build_config_pkg.sv core/cvxif_example/include/cvxif_instr_pkg.sv
         core/include/cvxif_types.svh)
for source in "${sources[@]}"; do
  if ! GIT_NO_LAZY_FETCH=1 git -C "$CVA6_REPO" show "$core_revision:$source" \
      > "$run_directory/${source##*/}" 2>> "$run_directory/source.log"; then
    echo "INVALID: fixed CVA6 configuration or CV-X-IF sources are unavailable" >&2
    exit 2
  fi
done
if ! cp "$candidate" "$run_directory/candidate.sv" || \
   ! cp "$script_directory/instr_decoder_ports_tb.sv" "$run_directory/tb.sv"; then
  echo "INVALID: cannot copy port-test inputs" >&2
  exit 2
fi
(cd "$run_directory" && sha256sum candidate.sv tb.sv "${sources[@]##*/}" > inputs.sha256) || exit 2
set +e
timeout 120 "$verilator" --binary --timing --assert -j 2 --top-module tb \
  --Mdir "$run_directory/obj" -Wno-fatal -I"$run_directory" \
  "$run_directory/config_pkg.sv" "$run_directory/cv32a60x_config_pkg.sv" \
  "$run_directory/build_config_pkg.sv" "$run_directory/cvxif_instr_pkg.sv" \
  "$run_directory/candidate.sv" "$run_directory/tb.sv" > "$run_directory/build.log" 2>&1
build_rc=$?
set -e
if [[ "$build_rc" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: instr-decoder port-test build wall-clock timeout" >&2
  exit 2
fi
if [ "$build_rc" -ne 0 ]; then
  classification=0
  python3 "$script_directory/../../harness/candidate_error.py" \
    "$run_directory/build.log" "$run_directory/candidate.sv" --directory "$run_directory" --submitted "$candidate" \
    || classification=$?
  if [ "$classification" -eq 1 ]; then
    module_logs="$log_root/instr_decoder"
    mkdir -p "$module_logs" || exit 2
    compile_log=$(mktemp -d "$module_logs/instr-decoder-ports-XXXXXX") || exit 2
    cp "$run_directory/build.log" "$compile_log/build.log" || exit 2
    cp "$run_directory/build.log" "$compile_log/candidate-compile-error.txt" || exit 2
    printf '%s\n' 1 > "$compile_log/exit-code.txt" || exit 2
    rm -rf -- "$run_directory" || exit 2
    echo "instr-decoder compile-error logs: $compile_log"
    exit 1
  fi
  exit 2
fi
set +e
timeout 30 "$run_directory/obj/Vtb" > "$run_directory/runtime.log" 2>&1
runtime_rc=$?
set -e
if [[ "$runtime_rc" =~ ^(124|126|127|137|143)$ ]]; then
  echo "INVALID: instr-decoder port-test wall-clock timeout" >&2
  exit 2
fi
if [ "$runtime_rc" -eq 0 ] && \
   grep -qx 'SUMMARY checks=367 errors=0' "$run_directory/runtime.log" && \
   grep -qx 'INSTR_DECODER_PORT_TEST_COMPLETE' "$run_directory/runtime.log"; then
  echo "PASS: instr-decoder port contract"
else
  echo "FAIL: instr-decoder port contract" >&2
  exit 1
fi
