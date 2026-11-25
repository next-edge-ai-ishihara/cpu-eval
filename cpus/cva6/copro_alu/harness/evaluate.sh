#!/usr/bin/env bash
set -uo pipefail

MODULE=${CPU_EVAL_MODULE:-copro_alu}
CANDIDATE=${1:-}
if [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <candidate-systemverilog>" >&2
  exit 2
fi

HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE_DIR=$(cd "$HARNESS_DIR/.." && pwd)
CPU_DIR=$(cd "$PACKAGE_DIR/.." && pwd)
ROOT=$(cd "$CPU_DIR/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
ENVFILE=${CVA6_ENVFILE:?Set CVA6_ENVFILE to the environment setup script}
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
CPU_REV=6348e9e684678f83b40d0520028513d06b36e7b2
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
MANIFEST=$CPU_DIR/MODULES.json
TESTLIST=${CVA6_TESTLIST:-$HARNESS_DIR/testlist_copro_alu.yaml}
TEST_OUTPUT_DIR=$REPO/verif/tests/cpu-eval-patches
TEST_BASIS=$REPO/verif/tests/custom/cv_xif/cvxif_add_nop.S
TEST_PATCH_0=$PACKAGE_DIR/tests/0000-adapt-cvxif-add-nop-to-arch-test.patch
TEST_PATCH_1=$PACKAGE_DIR/tests/0001-expand-custom3-operations.patch
TEST_PATCH_2=$PACKAGE_DIR/tests/0002-add-r4-operations.patch
PRESERVE_INPUTS=$CPU_DIR/harness/preserve_comparison_inputs.sh

SOURCE=$(python3 - "$MANIFEST" "$MODULE" <<'PY'
import json, sys
entries = [x for x in json.load(open(sys.argv[1]))["modules"] if x["module"] == sys.argv[2]]
if len(entries) != 1:
    raise SystemExit(2)
print(entries[0]["source_path"])
PY
) || { echo "unknown module: $MODULE" >&2; exit 2; }

CANDIDATE=$(realpath "$CANDIDATE")
RUN_ID=$(date -u +%Y-%m-%dT%H%M%SZ)-$(sha256sum "$CANDIDATE" | cut -c1-12)
LOG_DIR=$LOG_ROOT/$MODULE/$RUN_ID
mkdir -p "$LOG_DIR"
exec 9>"$REPO.cpu-eval.lock"
flock -n 9 || { echo "another evaluation owns $REPO" >&2; exit 2; }

if [ ! -d "$REPO/.git" ] || [ ! -f "$ENVFILE" ] || [ ! -f "$TESTLIST" ] || \
   [ ! -f "$TEST_BASIS" ] || [ ! -f "$TEST_PATCH_0" ] || \
   [ ! -f "$TEST_PATCH_1" ] || [ ! -f "$TEST_PATCH_2" ] || \
   [ ! -x "$PRESERVE_INPUTS" ]; then
  echo "the recorded checkout, environment, or test list is missing" >&2
  exit 2
fi
if [ "$(git -C "$REPO" rev-parse HEAD)" != "$CPU_REV" ] || \
   [ "$(git -C "$REPO/verif/tests/riscv-arch-test" rev-parse HEAD)" != "$TEST_REV" ]; then
  echo "a checkout is not at its recorded revision" >&2
  exit 2
fi

REFERENCE_SHA=$(git -C "$REPO" show "$CPU_REV:$SOURCE" | sha256sum | cut -d' ' -f1) || {
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: cannot read the pinned reference source" >&2
  exit 2
}
restore_source() {
  restore_tmp=$(mktemp -p "$(dirname "$REPO/$SOURCE")" .cpu-eval-restore-XXXXXX) || return 1
  if ! git -C "$REPO" show "$CPU_REV:$SOURCE" > "$restore_tmp"; then
    rm -f "$restore_tmp"
    echo "failed to read the pinned reference source" >&2
    return 1
  fi
  if ! install -m 644 "$restore_tmp" "$REPO/$SOURCE"; then
    rm -f "$restore_tmp"
    return 1
  fi
  rm -f "$restore_tmp"
  restored_sha=$(sha256sum "$REPO/$SOURCE" | cut -d' ' -f1) || return 1
  if [ "$restored_sha" != "$REFERENCE_SHA" ]; then
    echo "failed to restore the pinned reference source" >&2
    return 1
  fi
}
OBSERVER_INSTALLED=0
finish_evaluation() {
  evaluation_rc=$?
  if ! restore_source; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: failed to restore the pinned reference source" >&2
    evaluation_rc=2
  fi
  if [ "$OBSERVER_INSTALLED" -eq 1 ] && \
     ! python3 "$OBSERVER_DIR/prepare_cpu_observer.py" "$REPO" restore; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: failed to restore the CPU observation harness" >&2
    evaluation_rc=2
  fi
  if [ -n "${BASE:-}" ]; then rm -f "$BASE"; fi
  exit "$evaluation_rc"
}
trap finish_evaluation EXIT
trap 'exit 2' INT TERM
restore_source || {
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: initial source restoration failed" >&2
  exit 2
}
BASE=$(mktemp) || exit 2
if [ "$MODULE" = cvxif_issue_register_commit_if_driver ]; then
  OBSERVER_DIR="$CPU_DIR/cvxif_issue_register_commit_if_driver/harness"
  OBSERVER_INSTALLED=1
  python3 "$OBSERVER_DIR/prepare_cpu_observer.py" "$REPO" install || exit 2
  cp "$REPO/corev_apu/tb/ariane_testharness.sv" "$LOG_DIR/observed-testharness.sv" || exit 2
fi
cp "$REPO/$SOURCE" "$BASE"
python3 "$ROOT/tools/cva6/replace_module.py" --module "$MODULE" \
  --base "$BASE" --candidate "$CANDIDATE" --output "$REPO/$SOURCE" 2>"$LOG_DIR/build.log"
replace_rc=$?
if [ "$replace_rc" -eq 1 ]; then
  # The submission does not define the target module.
  cp "$LOG_DIR/build.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
  echo 1 >"$LOG_DIR/exit-code.txt"
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define $MODULE"; exit 1
elif [ "$replace_rc" -ne 0 ]; then
  exit 2
fi

set +u
# shellcheck disable=SC1090
source "$ENVFILE"
set -u
if [ -n "${CPU_EVAL_SPIKE_INSTALL_DIR:-}" ]; then
  export SPIKE_INSTALL_DIR="$CPU_EVAL_SPIKE_INSTALL_DIR"
  export SPIKE_PATH="$SPIKE_INSTALL_DIR/bin"
  export PATH="$SPIKE_PATH:$PATH"
  export LD_LIBRARY_PATH="$SPIKE_INSTALL_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
export NUM_JOBS=${CPU_EVAL_BUILD_JOBS:-${NUM_JOBS:-1}}
export CVA6_REPO_DIR="$REPO" TESTS_PATH="$REPO/verif/tests" RTL_PATH="$REPO/"
export TB_PATH="$REPO/verif/tb/core"



if ! {
  test "$(sha256sum "$TEST_BASIS" | cut -d' ' -f1)" = f158e2729f94cbe058d135f63121cb97d0f45a6e94a71b67a8bfc388facc7c59 &&
  test "$(sha256sum "$TEST_PATCH_0" | cut -d' ' -f1)" = af9d4a2442e0af0f3e71edcb4146ddbd5d6a47f07abbe226aac3f628f5b9b1b6 &&
  test "$(sha256sum "$TEST_PATCH_1" | cut -d' ' -f1)" = 9103fc99b9f6105dc39c5d7ea7874c2c44625151f1005480b057057abee2a234 &&
  test "$(sha256sum "$TEST_PATCH_2" | cut -d' ' -f1)" = 38f7baafbde228d9da44a68922bfa2a1a7276225cafb3f8cdb09326b9dacf319 &&
  mkdir -p "$TEST_OUTPUT_DIR" &&
  rm -f "$TEST_OUTPUT_DIR/copro_alu_custom3.S" "$TEST_OUTPUT_DIR/copro_alu_all_ops.S" &&
  cp "$TEST_BASIS" "$TEST_OUTPUT_DIR/copro_alu_custom3.S" &&
  git -C "$REPO" apply --directory=verif/tests/cpu-eval-patches "$TEST_PATCH_0" &&
  git -C "$REPO" apply --directory=verif/tests/cpu-eval-patches "$TEST_PATCH_1" &&
  test "$(sha256sum "$TEST_OUTPUT_DIR/copro_alu_custom3.S" | cut -d' ' -f1)" = 747298950724d3b1679e2d0102274b742ef23919837caf1f5853e6a8741b6568 &&
  cp "$TEST_OUTPUT_DIR/copro_alu_custom3.S" "$TEST_OUTPUT_DIR/copro_alu_all_ops.S" &&
  git -C "$REPO" apply --directory=verif/tests/cpu-eval-patches "$TEST_PATCH_2" &&
  test "$(sha256sum "$TEST_OUTPUT_DIR/copro_alu_all_ops.S" | cut -d' ' -f1)" = 8480494585b19d414b50589bd3fbd9f9c5140731e4f0ac53f82b8d1b5b40bd99;
}; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: problem-specific test reconstruction failed" >&2
  exit 2
fi

CANDIDATE_SHA=$(sha256sum "$CANDIDATE" | cut -d' ' -f1)
if [ "$MODULE" = cvxif_fu ]; then
  cp "$TEST_OUTPUT_DIR/copro_alu_all_ops.S" "$TEST_OUTPUT_DIR/cvxif_fu_rejection.S" || exit 2
  git -C "$REPO" apply --directory=verif/tests/cpu-eval-patches \
    "$CPU_DIR/cvxif_fu/tests/0001-add-rejected-custom-instruction.patch" || exit 2
  cmp -s "$TEST_OUTPUT_DIR/cvxif_fu_rejection.S" \
    "$CPU_DIR/cvxif_fu/tests/cvxif_fu_rejection.S" || exit 2
fi
if [ "$MODULE" = cvxif_issue_register_commit_if_driver ]; then
  cp "$TEST_OUTPUT_DIR/copro_alu_all_ops.S" "$TEST_OUTPUT_DIR/commit_notifications.S" || exit 2
  git -C "$REPO" apply --directory=verif/tests/cpu-eval-patches \
    "$CPU_DIR/cvxif_issue_register_commit_if_driver/tests/0001-add-commit-notifications.patch" || exit 2
  cmp -s "$TEST_OUTPUT_DIR/commit_notifications.S" \
    "$CPU_DIR/cvxif_issue_register_commit_if_driver/tests/commit_notifications.S" || exit 2
fi
BUILD_KEY="$CPU_REV $MODULE $CANDIDATE_SHA"
if [ "$MODULE" = cvxif_issue_register_commit_if_driver ]; then
  BUILD_KEY="$BUILD_KEY $(sha256sum "$REPO/corev_apu/tb/ariane_testharness.sv" | cut -d' ' -f1)"
fi
BUILD_MARKER="$REPO/work-ver/.cpu-eval-build-key"
if [ ! -x "$REPO/work-ver/Variane_testharness" ] || [ ! -f "$BUILD_MARKER" ] || \
   [ "$(cat "$BUILD_MARKER")" != "$BUILD_KEY" ]; then
  rm -rf "$REPO/work-ver"
  make -C "$REPO" verilate target=cv32a60x defines= >"$LOG_DIR/build.log" 2>&1 || {
    python3 "$CPU_DIR/harness/candidate_error.py" "$LOG_DIR/build.log" "$REPO/$SOURCE" --directory "$REPO" --submitted "$CANDIDATE"
    build_rc=$?
    if [ "$build_rc" -eq 1 ]; then
      cp "$LOG_DIR/build.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
    fi
    echo "$build_rc" >"$LOG_DIR/exit-code.txt"
    exit "$build_rc";
  }
  printf '%s\n' "$BUILD_KEY" >"$BUILD_MARKER"
else
  printf 'Reused build for %s\n' "$BUILD_KEY" >"$LOG_DIR/build.log"
fi

OUTNAME=out_cpueval_${MODULE}_$(date -u +%s)
LINKER="$REPO/verif/tests/riscv-arch-test/riscv-target/spike/link.ld"
SIMULATION_PREFIX=()
if [ "$MODULE" = cvxif_issue_register_commit_if_driver ]; then
  if ! command -v stdbuf >/dev/null; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: stdbuf is required for CPU notification observation" >&2
    exit 2
  fi
  SIMULATION_PREFIX=(stdbuf -oL -eL)
fi
(
  cd "$REPO/verif/sim" || exit 2
  timeout 3600 "${SIMULATION_PREFIX[@]}" python3 cva6.py --iss=veri-testharness,spike --target cv32a60x \
    --seed=1 --sv_seed=1 \
    -o "$OUTNAME" --testlist="$TESTLIST" --iss_yaml=cva6.yaml \
    --linker="$LINKER" --gcc_opts=''
) >"$LOG_DIR/run.log" 2>&1
RUN_RC=$?
REGR_LOG="$REPO/verif/sim/$OUTNAME/iss_regr.log"
if ! source "$CPU_DIR/../../tools/cva6/cpu_cycle_limit.sh"; then
  echo "INVALID: CPU cycle-limit helper is missing" >&2
  exit 2
fi
# The fixed programs complete on the reference RTL, so a run that does not complete is a FAIL.
incomplete() {
  printf '%s\n' "$1" >"$LOG_DIR/incomplete-execution.txt"
  echo 1 >"$LOG_DIR/exit-code.txt"
  echo "FAIL: $1" >&2; exit 1
}
rtl_run_failed() {
  python3 "$ROOT/tools/cva6/run_failure.py" "$1" "$REPO/verif/sim" >/dev/null
  [ "$?" -eq 1 ]
}
if [ "$RUN_RC" -eq 1 ] && has_cpu_cycle_limit "$REPO/verif/sim/$OUTNAME"; then
  incomplete "CPU reached the fixed RVFI cycle limit"
fi
if [ "$RUN_RC" -eq 1 ] && rtl_run_failed "$LOG_DIR/run.log"; then
  incomplete "the RTL simulation of a fixed program did not complete"
fi
if [ "$RUN_RC" -ne 0 ] || [ ! -f "$REGR_LOG" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: CPU regression did not complete" >&2; exit 2
fi
cp "$REGR_LOG" "$LOG_DIR/iss_regr.log"
SUMMARY=$(grep -E '^[0-9]+ PASSED, [0-9]+ FAILED$' "$REGR_LOG" | tail -1)
if [ -z "$SUMMARY" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: regression summary is missing" >&2; exit 2
fi
if ! python3 - "$HARNESS_DIR/compare_retired_instructions.py" "$TESTLIST" \
    "$REPO/verif/sim/$OUTNAME" "$LOG_DIR/test-output-inventory.json" <<'PY'
from pathlib import Path
import json
import runpy
import sys
check = runpy.run_path(sys.argv[1])["validate_test_outputs"]
result = check(Path(sys.argv[2]), Path(sys.argv[3]))
Path(sys.argv[4]).write_text(json.dumps(result, indent=2) + "\n")
PY
then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: selected test outputs are incomplete or ambiguous" >&2
  exit 2
fi
TRACE_FAILURES=0
mkdir -p "$LOG_DIR/trace-comparisons" "$LOG_DIR/raw-architectural-traces"
for spike_log in "$REPO/verif/sim/$OUTNAME"/spike_sim/*.log; do
  test_name=$(basename "$spike_log" .log)
  if ! halt_elf=$(python3 - "$HARNESS_DIR/compare_retired_instructions.py" \
      "$TESTLIST" "${test_name%.cv32a60x}" "$REPO/verif/sim/$OUTNAME" <<'PY'
from pathlib import Path
import runpy
import sys
resolve = runpy.run_path(sys.argv[1])["test_elf"]
print(resolve(Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])))
PY
  ); then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: test ELF could not be resolved" >&2
    exit 2
  fi
  rtl_log="$REPO/verif/sim/$OUTNAME/veri-testharness_sim/$test_name.log"
  if [ "$MODULE" = cvxif_issue_register_commit_if_driver ]; then
    mkdir -p "$LOG_DIR/cpu-port-observations"
    if [ ! -f "$rtl_log.iss" ] || ! cp "$rtl_log.iss" "$LOG_DIR/cpu-port-observations/$test_name.log"; then
      echo 2 >"$LOG_DIR/exit-code.txt"
      echo "INVALID: CPU port observation log could not be preserved" >&2
      exit 2
    fi
  fi
  if ! "$PRESERVE_INPUTS" "$LOG_DIR/raw-architectural-traces" \
      "$test_name" "$rtl_log" "$spike_log"; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: comparison inputs could not be preserved" >&2
    exit 2
  fi
  comparison_rc=0
  python3 "$HARNESS_DIR/compare_retired_instructions.py" \
    "$rtl_log" "$spike_log" \
    --halt-elf "$halt_elf" \
    --output "$LOG_DIR/trace-comparisons/$test_name.json" || comparison_rc=$?
  if [ "$comparison_rc" -eq 1 ]; then
    TRACE_FAILURES=$((TRACE_FAILURES + 1))
  elif [ "$comparison_rc" -ne 0 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: the Spike trace or test ELF of $test_name cannot be compared" >&2
    exit 2
  fi
done
printf '%s\n' "$TRACE_FAILURES" >"$LOG_DIR/trace-failures.txt"
if [ "$TRACE_FAILURES" -eq 0 ]; then
  if [ "$MODULE" = copro_alu ]; then
    DESTINATION_TOP=copro_alu_destination_test
    DESTINATION_BUILD=$(mktemp -d "$REPO/work-ver/copro-alu-destination.XXXXXX") || exit 2
    DESTINATION_LOG=$LOG_DIR/destination-observations.log
    destination_rc=0
    destination_stopped=0
    verilator --binary --timing -Wno-fatal --top-module "$DESTINATION_TOP" \
        -j "$NUM_JOBS" --Mdir "$DESTINATION_BUILD" \
        "$REPO/core/cvxif_example/include/cvxif_instr_pkg.sv" "$REPO/$SOURCE" \
        "$HARNESS_DIR/$DESTINATION_TOP.sv" >"$LOG_DIR/destination-build.log" 2>&1 ||
      destination_rc=$?
    # The fixed bench runs with the reference module, so only a tool, resource or kill stop is INVALID.
    if [ "$destination_rc" -eq 0 ]; then
      timeout 30 "$DESTINATION_BUILD/V$DESTINATION_TOP" >"$DESTINATION_LOG" 2>&1 || destination_rc=$?
    else
      python3 "$CPU_DIR/harness/candidate_error.py" "$LOG_DIR/destination-build.log" "$REPO/$SOURCE" \
        --submitted "$CANDIDATE" >/dev/null
      [ "$?" -eq 1 ] || destination_stopped=1
    fi
    case "$destination_rc" in 124|126|127|137|143) destination_stopped=1 ;; esac
    rm -rf "$DESTINATION_BUILD"
    if [ "$destination_stopped" -ne 0 ]; then
      echo 2 >"$LOG_DIR/exit-code.txt"
      echo "INVALID: copro_alu destination observation was stopped by a tool or resource failure" >&2
      exit 2
    fi
    if [ "$destination_rc" -ne 0 ] || ! grep -Fxq COPRO_ALU_DESTINATION_PASS "$DESTINATION_LOG" ||
       grep -Fxq COPRO_ALU_DESTINATION_FAIL "$DESTINATION_LOG"; then
      echo 1 >"$LOG_DIR/exit-code.txt"
      echo "FAIL: copro_alu destination observation did not pass" >&2
      exit 1
    fi
  fi
  echo 0 >"$LOG_DIR/exit-code.txt"
  echo "PASS: simulation completed and all architectural trace entries match"
  exit 0
fi
echo 1 >"$LOG_DIR/exit-code.txt"
echo "FAIL: simulation completed and $TRACE_FAILURES architectural trace comparisons failed"
exit 1
