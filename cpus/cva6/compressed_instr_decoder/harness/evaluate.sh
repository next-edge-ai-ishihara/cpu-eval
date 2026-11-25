#!/usr/bin/env bash
set -uo pipefail

MODULE=compressed_instr_decoder
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
TESTLIST=${CVA6_TESTLIST:-$HARNESS_DIR/testlist_compressed_instr_decoder.yaml}
TRACE_COMPARATOR=$CPU_DIR/harness/compare_architectural_traces.py
PRESERVE_INPUTS=$CPU_DIR/harness/preserve_comparison_inputs.sh
OBSERVER_PREPARE=$HARNESS_DIR/prepare_compressed_observer.py
RESPONSE_OBSERVER=$HARNESS_DIR/observe_compressed_response.py
TEST_PATCH=$PACKAGE_DIR/tests/0001-add-compressed-cvxif-table-test.patch
TEST_OUTPUT=$REPO/verif/tests/cpu-eval-patches/compressed_instr_decoder_table.S
TEST_PATCH_SHA=fb50858d1a3adda165152f3571f5ffa5d8028118a42228742d30410eb349e3c0
TEST_OUTPUT_SHA=d43d1f1774003378202ad0a55cfa9d71e1c36a5ab492afe3b58a9fa19c88e6a9

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
   [ ! -f "$TRACE_COMPARATOR" ] || [ ! -x "$PRESERVE_INPUTS" ] || \
   [ ! -f "$TEST_PATCH" ] || [ ! -f "$OBSERVER_PREPARE" ] || [ ! -f "$RESPONSE_OBSERVER" ]; then
  echo "the recorded checkout, environment, or test list is missing" >&2
  exit 2
fi
if [ "$(git -C "$REPO" rev-parse HEAD)" != "$CPU_REV" ] || \
   [ "$(git -C "$REPO/verif/tests/riscv-arch-test" rev-parse HEAD)" != "$TEST_REV" ]; then
  echo "a checkout is not at its recorded revision" >&2
  exit 2
fi

REFERENCE_SHA=$(git -C "$REPO" show "$CPU_REV:$SOURCE" | sha256sum | cut -d' ' -f1)
restore_source() {
  restore_tmp=$(mktemp -p "$(dirname "$REPO/$SOURCE")" .cpu-eval-restore-XXXXXX)
  if ! git -C "$REPO" show "$CPU_REV:$SOURCE" > "$restore_tmp"; then
    rm -f "$restore_tmp"
    echo "failed to read the pinned reference source" >&2
    return 1
  fi
  install -m 644 "$restore_tmp" "$REPO/$SOURCE"
  rm -f "$restore_tmp"
  restored_sha=$(sha256sum "$REPO/$SOURCE" | cut -d' ' -f1)
  if [ "$restored_sha" != "$REFERENCE_SHA" ]; then
    echo "failed to restore the pinned reference source" >&2
    return 1
  fi
}
restore_source || exit 2
BASE=$(mktemp)
finish_evaluation() {
  result=$?
  trap - EXIT INT TERM
  if ! restore_source; then
    echo "INVALID: fixed reference source could not be restored" >&2
    result=2
  fi
  if ! python3 "$OBSERVER_PREPARE" "$REPO" restore; then
    echo "INVALID: fixed simulation harness could not be restored" >&2
    result=2
  fi
  rm -f "$BASE"
  printf '%s\n' "$result" >"$LOG_DIR/exit-code.txt"
  exit "$result"
}
trap finish_evaluation EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cp "$REPO/$SOURCE" "$BASE"
python3 "$ROOT/tools/cva6/replace_module.py" --module "$MODULE" \
  --base "$BASE" --candidate "$CANDIDATE" --output "$REPO/$SOURCE" 2>"$LOG_DIR/build.log"
replace_rc=$?
if [ "$replace_rc" -eq 1 ]; then
  # The submission does not define the target module.
  cp "$LOG_DIR/build.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define $MODULE"; exit 1
elif [ "$replace_rc" -ne 0 ]; then
  exit 2
fi
python3 "$OBSERVER_PREPARE" "$REPO" install || exit 2

set +u
# shellcheck disable=SC1090
source "$ENVFILE"
set -u
if [ -n "${CPU_EVAL_SPIKE_INSTALL_DIR:-}" ]; then
  export SPIKE_INSTALL_DIR="$CPU_EVAL_SPIKE_INSTALL_DIR"
  export SPIKE_PATH="$SPIKE_INSTALL_DIR/bin"
  export PATH="$SPIKE_PATH:$PATH"
fi
export NUM_JOBS=${CPU_EVAL_BUILD_JOBS:-${NUM_JOBS:-1}}
export CVA6_REPO_DIR="$REPO" TESTS_PATH="$REPO/verif/tests" RTL_PATH="$REPO/"
export TB_PATH="$REPO/verif/tb/core"


test "$(sha256sum "$TEST_PATCH" | cut -d' ' -f1)" = "$TEST_PATCH_SHA" || exit 2
rm -f "$TEST_OUTPUT"
mkdir -p "$(dirname "$TEST_OUTPUT")"
git -C "$REPO" apply --directory=verif/tests "$TEST_PATCH" \
  >"$LOG_DIR/test-reconstruction.log" 2>&1 || exit 2
test "$(sha256sum "$TEST_OUTPUT" | cut -d' ' -f1)" = "$TEST_OUTPUT_SHA" || exit 2

CANDIDATE_SHA=$(sha256sum "$CANDIDATE" | cut -d' ' -f1)
BUILD_KEY="$CPU_REV $MODULE $CANDIDATE_SHA $(sha256sum "$OBSERVER_PREPARE" | cut -d' ' -f1)"
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
(
  cd "$REPO/verif/sim" || exit 2
  timeout 3600 python3 cva6.py --iss=veri-testharness,spike --target cv32a60x \
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
FAILED=$(printf '%s\n' "$SUMMARY" | sed -E 's/^[0-9]+ PASSED, ([0-9]+) FAILED$/\1/')
TRACE_FAILURES=0
OBSERVATION_FAILURES=0
mkdir -p "$LOG_DIR/architectural-comparisons" "$LOG_DIR/raw-architectural-traces"
for spike_log in "$REPO/verif/sim/$OUTNAME"/spike_sim/*.log; do
  test_name=$(basename "$spike_log" .log)
  rtl_log="$REPO/verif/sim/$OUTNAME/veri-testharness_sim/$test_name.log"
  if ! "$PRESERVE_INPUTS" "$LOG_DIR/raw-architectural-traces" \
      "$test_name" "$rtl_log" "$spike_log"; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: comparison inputs could not be preserved" >&2
    exit 2
  fi
  if ! python3 "$TRACE_COMPARATOR" \
      "$rtl_log" "$spike_log" \
      --output "$LOG_DIR/architectural-comparisons/$test_name.json"; then
    TRACE_FAILURES=$((TRACE_FAILURES + 1))
  fi
  mkdir -p "$LOG_DIR/cpu-port-observations"
  observation_log="$LOG_DIR/cpu-port-observations/$test_name.log"
  if [ ! -f "$rtl_log.iss" ] || ! cp "$rtl_log.iss" "$observation_log"; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: compressed-interface observations could not be preserved" >&2
    exit 2
  fi
  python3 "$RESPONSE_OBSERVER" "$observation_log" \
      "$LOG_DIR/architectural-comparisons/$test_name.compression.json"
  observation_result=$?
  if [ "$observation_result" -eq 2 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: compressed-interface observations are malformed" >&2
    exit 2
  elif [ "$observation_result" -eq 1 ]; then
    OBSERVATION_FAILURES=$((OBSERVATION_FAILURES + 1))
  elif [ "$observation_result" -ne 0 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: compressed-interface observer did not complete" >&2
    exit 2
  fi
done
printf '%s\n' "$TRACE_FAILURES" >"$LOG_DIR/trace-failures.txt"
printf '%s\n' "$OBSERVATION_FAILURES" >"$LOG_DIR/compression-failures.txt"
if [ "$FAILED" -eq 0 ] && [ "$TRACE_FAILURES" -eq 0 ] && [ "$OBSERVATION_FAILURES" -eq 0 ]; then
  echo 0 >"$LOG_DIR/exit-code.txt"; echo "PASS: $SUMMARY"; exit 0
fi
echo 1 >"$LOG_DIR/exit-code.txt"
echo "FAIL: $SUMMARY, $TRACE_FAILURES architectural-trace comparisons failed, $OBSERVATION_FAILURES compressed responses differed"
exit 1
