#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-systemverilog>" >&2
  exit 2
fi
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
mkdir -p "$LOG_ROOT/cvxif_fu"
WORK=$(mktemp -d "$LOG_ROOT/.cvxif-fu.XXXXXX") || exit 2
trap 'rm -rf "$WORK"' EXIT
if CPU_EVAL_LOG_ROOT="$WORK" \
  CVA6_TESTLIST=${CVA6_TESTLIST:-$SCRIPT_DIR/testlist_cvxif_fu.yaml} \
  CPU_EVAL_MODULE=cvxif_fu \
  "$SCRIPT_DIR/../../copro_alu/harness/evaluate.sh" "$1" |
  sed '/^PASS: simulation completed and all architectural trace entries match$/d'; then
  cpu_status=0
else
  statuses=("${PIPESTATUS[@]}")
  [ "${statuses[1]}" -eq 0 ] || exit 2
  cpu_status=${statuses[0]}
fi

shopt -s nullglob
runs=("$WORK/cvxif_fu/"*)
if [ "${#runs[@]}" -eq 1 ] && [ -d "${runs[0]}" ]; then
  LOG_DIR=$LOG_ROOT/cvxif_fu/$(basename "${runs[0]}")-${WORK##*.}
  mv -T "${runs[0]}" "$LOG_DIR" || exit 2
elif [ "$cpu_status" -eq 0 ]; then
  echo "INVALID: successful CPU run evidence is missing" >&2
  exit 2
fi
[ "$cpu_status" -eq 0 ] || exit "$cpu_status"
if [ "$(cat "$LOG_DIR/exit-code.txt")" != 0 ]; then
  echo "INVALID: successful CPU run exit code is missing" >&2
  exit 2
fi

REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
INCLUDE=$REPO/core/include
TOP=cvxif_fu_result_ready_test
CPU_REV=6348e9e684678f83b40d0520028513d06b36e7b2
if ! {
  git -C "$REPO" show "$CPU_REV:core/cvxif_fu.sv" > "$WORK/reference.sv" &&
  python3 "$ROOT/tools/cva6/replace_module.py" --module cvxif_fu \
    --base "$WORK/reference.sv" --candidate "$1" --output "$WORK/cvxif_fu.sv";
} > "$LOG_DIR/result-ready-build.log" 2>&1; then
  echo 2 > "$LOG_DIR/exit-code.txt"
  echo "INVALID: cvxif_fu result-ready inputs could not be prepared" >&2
  exit 2
fi
# The fixed bench runs with the reference module, so only a tool, resource or kill stop is INVALID.
observation_rc=0
observation_stopped=0
verilator --binary --timing -Wno-fatal --top-module "$TOP" \
  -j "${CPU_EVAL_BUILD_JOBS:-${NUM_JOBS:-1}}" --Mdir "$WORK/build" -I"$INCLUDE" \
  "$INCLUDE"/{config_pkg,cv32a60x_config_pkg,build_config_pkg,riscv_pkg,ariane_pkg}.sv \
  "$WORK/cvxif_fu.sv" "$SCRIPT_DIR/$TOP.sv" >> "$LOG_DIR/result-ready-build.log" 2>&1 || observation_rc=$?
if [ "$observation_rc" -eq 0 ]; then
  timeout 30 "$WORK/build/V$TOP" > "$LOG_DIR/result-ready-observations.log" 2>&1 || observation_rc=$?
else
  python3 "$SCRIPT_DIR/../../harness/candidate_error.py" "$LOG_DIR/result-ready-build.log" \
    "$WORK/cvxif_fu.sv" --submitted "$1" >/dev/null || [ "$?" -eq 1 ] || observation_stopped=1
fi
case "$observation_rc" in 124|126|127|137|143) observation_stopped=1 ;; esac
if [ "$observation_stopped" -ne 0 ]; then
  echo 2 > "$LOG_DIR/exit-code.txt"
  echo "INVALID: cvxif_fu result-ready observation was stopped by a tool or resource failure" >&2
  exit 2
fi
if [ "$observation_rc" -ne 0 ] || ! grep -Fxq CVXIF_FU_RESULT_READY_PASS "$LOG_DIR/result-ready-observations.log" ||
   grep -Fxq CVXIF_FU_RESULT_READY_FAIL "$LOG_DIR/result-ready-observations.log"; then
  echo 1 > "$LOG_DIR/exit-code.txt"
  echo "FAIL: cvxif_fu result-ready observation did not pass" >&2
  exit 1
fi
echo "PASS: CPU traces and CV-X-IF result readiness match"
