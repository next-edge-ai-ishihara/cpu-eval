#!/usr/bin/env bash
set -uo pipefail

CANDIDATE=${1:-}
if [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <candidate-store_unit.sv>" >&2
  exit 2
fi
CANDIDATE=$(realpath "$CANDIDATE")
HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$HARNESS_DIR/../.." && pwd)
ROOT=$(cd "$CPU_DIR/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
ENVFILE=${CVA6_ENVFILE:?Set CVA6_ENVFILE to the environment setup script}
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
CPU_REV=6348e9e684678f83b40d0520028513d06b36e7b2
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
STORE_UNIT=core/store_unit.sv
TESTHARNESS=corev_apu/tb/ariane_testharness.sv
TESTLIST=$HARNESS_DIR/testlist_store_unit_with_trap.yaml
STORE_COMPARATOR=$HARNESS_DIR/compare_store_updates.py
SET_CHECKER=$ROOT/tools/cva6/check_regression_set.py
PRESERVE_INPUTS=$CPU_DIR/harness/preserve_comparison_inputs.sh
MEMORY_TRACE_PATCH=$CPU_DIR/harness/0001-log-dram-writes.patch
MEMORY_TRACE_PATCH_SHA=b79e083a7b0c93b244df434125cdfc1cefd54acc147b4e97e785f8c129aee7cb
TESTHARNESS_REFERENCE_SHA=c671b2f70ea4cd7e27b67f4764e07966abd69e18d168f3de28220b26b8bb8655
STORE_UNIT_REFERENCE_SHA=a846efab0c86729e956a59f84e225f45c873fe33830767ae2cac4f5baea5d93f
TESTHARNESS_PATCHED_SHA=978648dfc2b9016a989a594b38d1136ee6335dac0e7b685a737a086a63b4a7a2
OUTNAME=out_cpueval_store_unit
EXPECTED_TESTS=6
TESTLIST_REFERENCE_SHA=1c09cc202ff913bc67e0f53a2148c9127252415cc6f4064c58a21fb3245cec45

CANDIDATE_SHA=$(sha256sum "$CANDIDATE" | cut -d' ' -f1)
RUN_ID=$(date -u +%Y-%m-%dT%H%M%SZ)-${CANDIDATE_SHA:0:12}
LOG_DIR=$LOG_ROOT/store_unit/$RUN_ID
mkdir -p "$LOG_DIR"
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || [ ! "/proc/self/fd/9" -ef "$REPO.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $REPO" >&2
    exit 2
  fi
else
  exec 9>"$REPO.cpu-eval.lock" || exit 2
fi
if ! flock -n 9; then
  echo "evaluate.sh: another evaluation owns $REPO" >&2
  exit 2
fi

if [ ! -d "$REPO/.git" ] || [ ! -f "$ENVFILE" ]; then
  echo "evaluate.sh: CVA6 checkout or environment file is missing" >&2
  exit 2
fi
if [ "$(git -C "$REPO" rev-parse HEAD 2>/dev/null)" != "$CPU_REV" ]; then
  echo "evaluate.sh: CVA6 checkout is not at the recorded revision" >&2
  exit 2
fi
if [ "$(git -C "$REPO/verif/tests/riscv-arch-test" rev-parse HEAD 2>/dev/null)" != "$TEST_REV" ]; then
  echo "evaluate.sh: riscv-arch-test checkout is not at the recorded revision" >&2
  exit 2
fi

restore_sources() {
  local path expected temporary restored status=0
  for path in "$STORE_UNIT" "$TESTHARNESS"; do
    expected=$STORE_UNIT_REFERENCE_SHA
    [ "$path" != "$TESTHARNESS" ] || expected=$TESTHARNESS_REFERENCE_SHA
    temporary=$(mktemp -p "$(dirname "$REPO/$path")" .cpu-eval-restore-XXXXXX) || { status=1; continue; }
    if ! git -C "$REPO" show "$CPU_REV:$path" > "$temporary"; then
      rm -f "$temporary"; status=1; continue
    fi
    restored=$(sha256sum "$temporary" | cut -d' ' -f1) || { rm -f "$temporary"; status=1; continue; }
    if [ "$restored" != "$expected" ] || ! install -m 644 "$temporary" "$REPO/$path"; then
      rm -f "$temporary"; status=1; continue
    fi
    rm -f "$temporary"
    restored=$(sha256sum "$REPO/$path" | cut -d' ' -f1) || { status=1; continue; }
    [ "$restored" = "$expected" ] || status=1
  done
  return "$status"
}
finish_evaluation() {
  local evaluation_rc=$?
  trap - EXIT
  if ! restore_sources; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: failed to restore pinned sources" >&2
    evaluation_rc=2
  fi
  exit "$evaluation_rc"
}
trap finish_evaluation EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if ! restore_sources; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: initial source restoration failed" >&2
  exit 2
fi
if [ "$(sha256sum "$REPO/$TESTHARNESS" | cut -d' ' -f1)" != "$TESTHARNESS_REFERENCE_SHA" ]; then
  echo "evaluate.sh: pinned test harness does not match its recorded SHA-256" >&2
  exit 2
fi
if [ "$(sha256sum "$MEMORY_TRACE_PATCH" | cut -d' ' -f1)" != "$MEMORY_TRACE_PATCH_SHA" ]; then
  echo "evaluate.sh: memory trace patch does not match its recorded SHA-256" >&2
  exit 2
fi
git -C "$REPO" apply "$MEMORY_TRACE_PATCH" || exit 2
if [ "$(sha256sum "$REPO/$TESTHARNESS" | cut -d' ' -f1)" != "$TESTHARNESS_PATCHED_SHA" ]; then
  echo "evaluate.sh: patched test harness does not match its recorded SHA-256" >&2
  exit 2
fi

BASE=$(mktemp) || exit 2
cp "$REPO/$STORE_UNIT" "$BASE" || exit 2
python3 "$CPU_DIR/../../tools/cva6/replace_module.py" --module store_unit \
  --base "$BASE" --candidate "$CANDIDATE" --output "$REPO/$STORE_UNIT" 2>"$LOG_DIR/build.log"
integration_rc=$?
rm -f "$BASE"
if [ "$integration_rc" -eq 1 ]; then
  # The submission does not define the target module.
  cp "$LOG_DIR/build.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
  echo 1 >"$LOG_DIR/exit-code.txt"
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define store_unit"; exit 1
elif [ "$integration_rc" -ne 0 ]; then
  echo "INVALID: candidate integration failed" >&2
  exit 2
fi
BUILD_KEY="$CPU_REV $CANDIDATE_SHA $MEMORY_TRACE_PATCH_SHA"
BUILD_MARKER="$REPO/work-ver/.cpu-eval-store-unit-build-key"

set +u
# shellcheck disable=SC1090
source "$ENVFILE"
set -u
export CVA6_REPO_DIR="$REPO"
export TESTS_PATH="$REPO/verif/tests"
export STORE_TEST_ROOT="$HARNESS_DIR"
export CPATH="$REPO/verif/tests/riscv-arch-test/riscv-target/spike${CPATH:+:$CPATH}"
export RTL_PATH="$REPO/"

SELECTION=$LOG_DIR/regression-selection.json
if [ "$(sha256sum "$TESTLIST" | cut -d' ' -f1)" != "$TESTLIST_REFERENCE_SHA" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: regression test list differs from the fixed six inputs" >&2
  exit 2
fi
if ! python3 "$SET_CHECKER" --testlist "$TESTLIST" --simulation-directory "$REPO/verif/sim" \
    --target cv32a60x >"$SELECTION"; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: regression selection could not be recorded" >&2
  exit 2
fi

if [ ! -x "$REPO/work-ver/Variane_testharness" ] || \
   [ ! -f "$BUILD_MARKER" ] || \
   [ "$(cat "$BUILD_MARKER")" != "$BUILD_KEY" ]; then
  rm -rf "$REPO/work-ver"
  if ! make -C "$REPO" verilate target=cv32a60x defines= >"$LOG_DIR/build.log" 2>&1; then
    python3 "$CPU_DIR/harness/candidate_error.py" "$LOG_DIR/build.log" "$REPO/$STORE_UNIT" --directory "$REPO" --submitted "$CANDIDATE"
    build_rc=$?
    if [ "$build_rc" -eq 1 ]; then
      cp "$LOG_DIR/build.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
    fi
    echo "$build_rc" >"$LOG_DIR/exit-code.txt"
    exit "$build_rc"
  fi
  printf '%s\n' "$BUILD_KEY" >"$BUILD_MARKER"
else
  printf 'Reused build for %s\n' "$BUILD_KEY" >"$LOG_DIR/build.log"
fi

LINKER="$REPO/verif/tests/riscv-arch-test/riscv-target/spike/link.ld"
rm -rf "$REPO/verif/sim/$OUTNAME"
(
  cd "$REPO/verif/sim" || exit 2
  timeout 1800 python3 cva6.py --iss=veri-testharness,spike --target cv32a60x \
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
  python3 "$CPU_DIR/../../tools/cva6/run_failure.py" "$1" "$REPO/verif/sim" >/dev/null
  [ "$?" -eq 1 ]
}
if [ "$RUN_RC" -eq 1 ] && has_cpu_cycle_limit "$REPO/verif/sim/$OUTNAME"; then
  incomplete "CPU reached the fixed RVFI cycle limit"
fi
if [ "$RUN_RC" -eq 1 ] && rtl_run_failed "$LOG_DIR/run.log"; then
  incomplete "the RTL simulation of a fixed program did not complete"
fi
if [ "$RUN_RC" -ne 0 ] || [ ! -f "$REGR_LOG" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: CPU regression did not complete" >&2
  exit 2
fi
cp "$REGR_LOG" "$LOG_DIR/iss_regr.log"
if ! python3 "$SET_CHECKER" --selection "$SELECTION" \
    --rtl "$REPO/verif/sim/$OUTNAME/veri-testharness_sim" \
    --spike "$REPO/verif/sim/$OUTNAME/spike_sim" --report "$REGR_LOG" \
    >"$LOG_DIR/native-regression-set.json"; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: native regression output set differs" >&2
  exit 2
fi

STORE_FAILURES=0
STORE_TESTS=0
mkdir -p "$LOG_DIR/store-updates" "$LOG_DIR/raw-store-update-traces"
for spike_log in "$REPO/verif/sim/$OUTNAME/spike_sim/"*.log; do
  test_name=$(basename "$spike_log" .log)
  rtl_log="$REPO/verif/sim/$OUTNAME/veri-testharness_sim/$test_name.log.iss"
  rtl_trace="$REPO/verif/sim/$OUTNAME/veri-testharness_sim/$test_name.log"
  if ! "$PRESERVE_INPUTS" "$LOG_DIR/raw-store-update-traces" \
      "$test_name" "$rtl_log" "$spike_log"; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: store-update comparison inputs could not be preserved" >&2
    exit 2
  fi
  if ! "$PRESERVE_INPUTS" "$LOG_DIR/raw-retirement-traces" \
      "$test_name" "$rtl_trace" "$spike_log"; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: retirement comparison inputs could not be preserved" >&2
    exit 2
  fi
  STORE_TESTS=$((STORE_TESTS + 1))
  python3 "$STORE_COMPARATOR" --rtl-memory "$rtl_log" --spike "$spike_log" \
      --rtl-trace "$rtl_trace" --exclude-address 0x80001000 \
      --output "$LOG_DIR/store-updates/$test_name.json"
  comparison_rc=$?
  if [ ! -f "$LOG_DIR/store-updates/$test_name.json" ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: store-update comparison output is missing" >&2
    exit 2
  elif [ "$comparison_rc" -eq 1 ]; then
    STORE_FAILURES=$((STORE_FAILURES + 1))
  elif [ "$comparison_rc" -ne 0 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: store-update comparison input or execution failed" >&2
    exit 2
  fi
done
if [ "$STORE_TESTS" -ne "$EXPECTED_TESTS" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: expected $EXPECTED_TESTS store-update comparisons, observed $STORE_TESTS" >&2
  exit 2
fi

SUMMARY=$(grep -E '^[0-9]+ PASSED, [0-9]+ FAILED$' "$REGR_LOG" | tail -1)
if [ -z "$SUMMARY" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: regression summary is missing" >&2
  exit 2
fi
PASSED=$(printf '%s\n' "$SUMMARY" | sed -E 's/^([0-9]+) PASSED.*/\1/')
FAILED=$(printf '%s\n' "$SUMMARY" | sed -E 's/^[0-9]+ PASSED, ([0-9]+) FAILED$/\1/')
if [ $((PASSED + FAILED)) -ne "$EXPECTED_TESTS" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: expected $EXPECTED_TESTS test results, observed $((PASSED + FAILED))" >&2
  exit 2
fi
if [ "$FAILED" -eq 0 ] && [ "$STORE_FAILURES" -eq 0 ]; then
  echo 0 >"$LOG_DIR/exit-code.txt"
  echo "PASS: $PASSED instruction and store-update trace comparisons matched"
  exit 0
fi
echo 1 >"$LOG_DIR/exit-code.txt"
echo "FAIL: $FAILED instruction-trace comparisons and $STORE_FAILURES store-update comparisons mismatched"
exit 1
