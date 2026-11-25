#!/usr/bin/env bash
set -uo pipefail

CANDIDATE=${1:-}
if [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate_store_updates.sh <candidate-cva6_hpdcache_wrapper.sv>" >&2
  exit 2
fi
CANDIDATE=$(realpath "$CANDIDATE")
HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$HARNESS_DIR/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
ENVFILE=${CVA6_ENVFILE:?Set CVA6_ENVFILE to the environment setup script}
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
CPU_REV=6348e9e684678f83b40d0520028513d06b36e7b2
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
SOURCE=core/cache_subsystem/cva6_hpdcache_wrapper.sv
TESTHARNESS=corev_apu/tb/ariane_testharness.sv
TESTLIST=$CPU_DIR/harness/testlist_store_updates.yaml
STORE_COMPARATOR=$CPU_DIR/harness/compare_store_updates.py
PRESERVE_INPUTS=$CPU_DIR/harness/preserve_comparison_inputs.sh
MEMORY_TRACE_PATCH=$CPU_DIR/harness/0001-log-dram-writes.patch
EXPECTED_TESTS=5
MEMORY_TRACE_PATCH_SHA=b79e083a7b0c93b244df434125cdfc1cefd54acc147b4e97e785f8c129aee7cb
TESTHARNESS_REFERENCE_SHA=c671b2f70ea4cd7e27b67f4764e07966abd69e18d168f3de28220b26b8bb8655
TESTHARNESS_PATCHED_SHA=978648dfc2b9016a989a594b38d1136ee6335dac0e7b685a737a086a63b4a7a2

CANDIDATE_SHA=$(sha256sum "$CANDIDATE" | cut -d' ' -f1)
RUN_ID=$(date -u +%Y-%m-%dT%H%M%SZ)-${CANDIDATE_SHA:0:12}
LOG_DIR=$LOG_ROOT/cva6_hpdcache_wrapper/$RUN_ID
mkdir -p "$LOG_DIR"
exec 9>"$REPO.cpu-eval.lock"
flock -n 9 || { echo "another evaluation owns $REPO" >&2; exit 2; }

if [ "$(git -C "$REPO" rev-parse HEAD)" != "$CPU_REV" ] || \
   [ "$(git -C "$REPO/verif/tests/riscv-arch-test" rev-parse HEAD)" != "$TEST_REV" ]; then
  echo "a checkout is not at its recorded revision" >&2
  exit 2
fi

restore_sources() {
  local source restore_tmp
  for source in "$SOURCE" "$TESTHARNESS"; do
    restore_tmp=$(mktemp -p "$(dirname "$REPO/$source")" .cpu-eval-restore-XXXXXX) || return 1
    if ! git -C "$REPO" show "$CPU_REV:$source" > "$restore_tmp" || \
       ! chmod --reference="$REPO/$source" "$restore_tmp" || \
       ! mv -f "$restore_tmp" "$REPO/$source"; then
      rm -f "$restore_tmp"
      echo "failed to restore the pinned reference source: $source" >&2
      return 1
    fi
  done
}
finish_store_evaluation() {
  local evaluation_rc=$?
  if ! restore_sources; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: failed to restore the pinned reference sources" >&2
    evaluation_rc=2
  fi
  exit "$evaluation_rc"
}
trap finish_store_evaluation EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
restore_sources || exit 2
if [ "$(sha256sum "$REPO/$TESTHARNESS" | cut -d' ' -f1)" != "$TESTHARNESS_REFERENCE_SHA" ] || \
   [ "$(sha256sum "$MEMORY_TRACE_PATCH" | cut -d' ' -f1)" != "$MEMORY_TRACE_PATCH_SHA" ]; then
  echo "recorded test-harness input does not match its SHA-256" >&2
  exit 2
fi
git -C "$REPO" apply "$MEMORY_TRACE_PATCH" || exit 2
if [ "$(sha256sum "$REPO/$TESTHARNESS" | cut -d' ' -f1)" != "$TESTHARNESS_PATCHED_SHA" ]; then
  echo "patched test harness does not match its SHA-256" >&2
  exit 2
fi
BASE=$(mktemp) || exit 2
cp "$REPO/$SOURCE" "$BASE" || exit 2
python3 "$CPU_DIR/../../tools/cva6/replace_module.py" --module cva6_hpdcache_wrapper \
  --base "$BASE" --candidate "$CANDIDATE" --output "$REPO/$SOURCE" 2>"$LOG_DIR/build.log"
integration_rc=$?
rm -f "$BASE"
if [ "$integration_rc" -eq 1 ]; then
  # The submission does not define the target module.
  cp "$LOG_DIR/build.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
  echo 1 >"$LOG_DIR/exit-code.txt"
  echo "FAIL_CANDIDATE_COMPILE: the submission does not define the target module"; exit 1
elif [ "$integration_rc" -ne 0 ]; then
  echo "INVALID: candidate integration failed" >&2
  exit 2
fi

set +u
source "$ENVFILE"
set -u
export CVA6_REPO_DIR="$REPO" TESTS_PATH="$REPO/verif/tests" RTL_PATH="$REPO/"

BUILD_KEY="$CPU_REV cva6_hpdcache_wrapper $CANDIDATE_SHA $(sha256sum "$MEMORY_TRACE_PATCH" | cut -d' ' -f1)"
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

OUTNAME=out_cpueval_cva6_hpdcache_wrapper_$(date -u +%s)
LINKER="$REPO/verif/tests/riscv-arch-test/riscv-target/spike/link.ld"
(
  cd "$REPO/verif/sim" || exit 2
  timeout 1800 python3 cva6.py --iss=veri-testharness,spike --target cv32a60x \
    --seed=1 --sv_seed=1 -o "$OUTNAME" --testlist="$TESTLIST" --iss_yaml=cva6.yaml \
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
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: CPU regression did not complete" >&2; exit 2
fi
cp "$REGR_LOG" "$LOG_DIR/iss_regr.log"

STORE_FAILURES=0
STORE_TESTS=0
mkdir -p "$LOG_DIR/store-updates" "$LOG_DIR/raw-store-update-traces"
for spike_log in "$REPO/verif/sim/$OUTNAME/spike_sim/"*.log; do
  test_name=$(basename "$spike_log" .log)
  rtl_log="$REPO/verif/sim/$OUTNAME/veri-testharness_sim/$test_name.log.iss"
  if ! "$PRESERVE_INPUTS" "$LOG_DIR/raw-store-update-traces" \
      "$test_name" "$rtl_log" "$spike_log"; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: store-update comparison inputs could not be preserved" >&2
    exit 2
  fi
  STORE_TESTS=$((STORE_TESTS + 1))
  python3 "$STORE_COMPARATOR" --rtl-memory "$rtl_log" --spike "$spike_log" \
    --exclude-address 0x80001000 --output "$LOG_DIR/store-updates/$test_name.json" || \
    STORE_FAILURES=$((STORE_FAILURES + 1))
done

SUMMARY=$(grep -E '^[0-9]+ PASSED, [0-9]+ FAILED$' "$REGR_LOG" | tail -1)
if [ -z "$SUMMARY" ] || [ "$STORE_TESTS" -ne "$EXPECTED_TESTS" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: incomplete comparison set" >&2; exit 2
fi
PASSED=$(printf '%s\n' "$SUMMARY" | sed -E 's/^([0-9]+) PASSED.*/\1/')
FAILED=$(printf '%s\n' "$SUMMARY" | sed -E 's/^[0-9]+ PASSED, ([0-9]+) FAILED$/\1/')
if [ $((PASSED + FAILED)) -ne "$EXPECTED_TESTS" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: incomplete regression" >&2; exit 2
fi
if [ "$FAILED" -eq 0 ] && [ "$STORE_FAILURES" -eq 0 ]; then
  echo 0 >"$LOG_DIR/exit-code.txt"; echo "PASS: $PASSED instruction and store-update trace comparisons matched"; exit 0
fi
echo 1 >"$LOG_DIR/exit-code.txt"
echo "FAIL: $FAILED instruction-trace comparisons and $STORE_FAILURES store-update comparisons mismatched"
exit 1
