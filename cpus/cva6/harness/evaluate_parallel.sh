#!/usr/bin/env bash
set -uo pipefail

MODULE=${1:-}
CANDIDATE=${2:-}
if [ -z "$MODULE" ] || [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate_parallel.sh <module> <candidate-systemverilog>" >&2
  exit 2
fi

HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$HARNESS_DIR/.." && pwd)
ROOT=$(cd "$CPU_DIR/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
ENVFILE=${CVA6_ENVFILE:?Set CVA6_ENVFILE to the environment setup script}
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
CPU_REV=6348e9e684678f83b40d0520028513d06b36e7b2
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
MANIFEST=$CPU_DIR/MODULES.json
TESTLIST=${CVA6_TESTLIST:-$HARNESS_DIR/testlist_cv32a60x.yaml}
TARGET=${CVA6_TARGET:-cv32a60x}

SOURCE=$(python3 - "$MANIFEST" "$MODULE" <<'PY'
import json, sys
entries = [x for x in json.load(open(sys.argv[1]))["modules"] if x["module"] == sys.argv[2]]
if len(entries) != 1:
    raise SystemExit(2)
print(entries[0]["source_path"])
PY
) || { echo "unknown module: $MODULE" >&2; exit 2; }

CANDIDATE=$(realpath "$CANDIDATE")
RUN_ID=$(date -u +%Y-%m-%dT%H%M%SZ)
CANDIDATE_SHA=$(sha256sum "$CANDIDATE" | cut -d' ' -f1)
mkdir -p "$LOG_ROOT/$MODULE" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
LOG_DIR=$(mktemp -d "$LOG_ROOT/$MODULE/$RUN_ID-XXXXXX-${CANDIDATE_SHA:0:12}") || {
  echo "INVALID: cannot create a run log directory" >&2; exit 2;
}
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$REPO.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $REPO" >&2
    exit 2
  fi
else
  if ! { exec 9>"$REPO.cpu-eval.lock"; }; then
    echo "INVALID: cannot open evaluation lock for $REPO" >&2
    exit 2
  fi
fi
flock -n 9 || { echo "another evaluation owns $REPO" >&2; exit 2; }

if [ ! -d "$REPO/.git" ] || [ ! -f "$ENVFILE" ] || [ ! -f "$TESTLIST" ]; then
  echo "the recorded checkout, environment, or test list is missing" >&2
  exit 2
fi
if [ "$(git -C "$REPO" rev-parse HEAD)" != "$CPU_REV" ] || \
   [ "$(git -C "$REPO/verif/tests/riscv-arch-test" rev-parse HEAD)" != "$TEST_REV" ]; then
  echo "a checkout is not at its recorded revision" >&2
  exit 2
fi

read_pinned_source() {
  if git -C "$REPO" cat-file -e "$CPU_REV:$SOURCE" 2>/dev/null; then
    git -C "$REPO" show "$CPU_REV:$SOURCE"
    return $?
  fi

  prefix=
  suffix=$SOURCE
  while [ "$suffix" != "${suffix#*/}" ]; do
    component=${suffix%%/*}
    suffix=${suffix#*/}
    prefix=${prefix:+$prefix/}$component
    entry=$(git -C "$REPO" ls-tree "$CPU_REV" "$prefix")
    if [ "${entry%% *}" = 160000 ]; then
      submodule_revision=$(printf '%s\n' "$entry" | awk '{print $3}')
      if [ "$(git -C "$REPO/$prefix" rev-parse HEAD)" != "$submodule_revision" ]; then
        echo "submodule $prefix is not at its recorded revision" >&2
        return 1
      fi
      git -C "$REPO/$prefix" show "$submodule_revision:$suffix"
      return $?
    fi
  done
  return 1
}

REFERENCE_SHA=$(read_pinned_source | sha256sum | cut -d' ' -f1) || {
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: cannot read the pinned reference source" >&2
  exit 2
}
restore_source() {
  restore_tmp=$(mktemp -p "$(dirname "$REPO/$SOURCE")" .cpu-eval-restore-XXXXXX) || return 1
  if ! read_pinned_source > "$restore_tmp"; then
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
finish_evaluation() {
  evaluation_rc=$?
  if ! restore_source; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: failed to restore the pinned reference source" >&2
    evaluation_rc=2
  fi
  if [ -n "${BASE:-}" ]; then
    rm -f "$BASE"
  fi
  exit "$evaluation_rc"
}
trap finish_evaluation EXIT
trap restore_source INT TERM
restore_source || {
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: initial source restoration failed" >&2
  exit 2
}
BASE=$(mktemp) || exit 2
trap 'restore_source; rm -f "$BASE"' INT TERM
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
  if [ -d "$SPIKE_INSTALL_DIR/lib" ]; then
    export LD_LIBRARY_PATH="$SPIKE_INSTALL_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
fi
export CVA6_REPO_DIR="$REPO" TESTS_PATH="$REPO/verif/tests" RTL_PATH="$REPO/"


# Test lists resolve local assembly programs through <path_var>/cpu-eval-patches/.
TEST_SOURCE_DIR=$(dirname "$TESTLIST")
if compgen -G "$TEST_SOURCE_DIR/*.S" >/dev/null; then
  mkdir -p "$TESTS_PATH/cpu-eval-patches"
  cp "$TEST_SOURCE_DIR"/*.S "$TESTS_PATH/cpu-eval-patches/"
fi

BUILD_KEY="$CPU_REV $TARGET $MODULE $CANDIDATE_SHA"
BUILD_MARKER="$REPO/work-ver/.cpu-eval-build-key"
if [ ! -x "$REPO/work-ver/Variane_testharness" ] || [ ! -f "$BUILD_MARKER" ] || \
   [ "$(cat "$BUILD_MARKER")" != "$BUILD_KEY" ]; then
  rm -rf "$REPO/work-ver"
  make -C "$REPO" verilate target="$TARGET" defines= >"$LOG_DIR/build.log" 2>&1 || {
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

REGRESSION_DIR=$(mktemp -d "$REPO/verif/sim/out_cpueval_${MODULE}_XXXXXX") || {
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: cannot create a regression output directory" >&2; exit 2;
}
OUTNAME=${REGRESSION_DIR##*/}
LINKER="$REPO/verif/tests/riscv-arch-test/riscv-target/spike/link.ld"
ISS_YAML=cva6.yaml
SET_CHECKER="$ROOT/tools/cva6/check_regression_set.py"
SELECTION="$LOG_DIR/regression-selection.json"
if ! python3 "$SET_CHECKER" --testlist "$TESTLIST" --simulation-directory "$REPO/verif/sim" \
    --target "$TARGET" >"$SELECTION"; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: regression selection could not be recorded" >&2; exit 2
fi
TEST_JOBS=${CVA6_TEST_JOBS:-1}
case "$TEST_JOBS" in
  ''|*[!0-9]*|0) echo "CVA6_TEST_JOBS must be a positive integer" >&2; exit 2 ;;
esac

run_regression() {
  local output_name=$1 test_list=$2 run_log=$3
  (
    cd "$REPO/verif/sim" || exit 2
    timeout 3600 python3 cva6.py --iss=veri-testharness,spike --target "$TARGET" \
      --seed=1 --sv_seed=1 \
      -o "$output_name" --testlist="$test_list" --iss_yaml="$ISS_YAML" \
      --linker="$LINKER" --gcc_opts=''
  ) >"$run_log" 2>&1
}

if ! source "$ROOT/tools/cva6/cpu_cycle_limit.sh"; then
  echo 2 >"$LOG_DIR/exit-code.txt"
  echo "INVALID: CPU cycle-limit helper is missing" >&2; exit 2
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

if [ "$TEST_JOBS" -eq 1 ]; then
  run_regression "$OUTNAME" "$TESTLIST" "$LOG_DIR/run.log"
  RUN_RC=$?
  printf '%s\n' "$RUN_RC" >"$LOG_DIR/run.exit-code.txt"
  if [ "$RUN_RC" -ne 0 ]; then
    if [ "$RUN_RC" -eq 1 ] && has_cpu_cycle_limit "$REPO/verif/sim/$OUTNAME"
    then
      cp "$REPO/verif/sim/trace_rvfi_hart_00.dasm" "$LOG_DIR/cycle-limit-rvfi.dasm" 2>/dev/null || true
      incomplete "CPU reached the fixed RVFI cycle limit"
    fi
    if [ "$RUN_RC" -eq 1 ] && rtl_run_failed "$LOG_DIR/run.log"; then
      incomplete "the RTL simulation of a fixed program did not complete"
    fi
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: CPU regression exited with $RUN_RC" >&2; exit 2
  fi
  REGR_LOG="$REPO/verif/sim/$OUTNAME/iss_regr.log"
  if [ ! -f "$REGR_LOG" ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: CPU regression did not complete" >&2; exit 2
  fi
  cp "$REGR_LOG" "$LOG_DIR/iss_regr.log"
  SUMMARY=$(grep -E '^[0-9]+ PASSED, [0-9]+ FAILED$' "$REGR_LOG" | tail -1)
  selections=("$SELECTION")
else
  RUNNER_DIR=$(dirname "$REPO")/cpu-eval-prebuilt-runner
  mkdir -p "$RUNNER_DIR"
  cp "$ROOT/tools/cva6/run_prebuilt_testharness.sh" "$RUNNER_DIR/"
  chmod +x "$RUNNER_DIR/run_prebuilt_testharness.sh"
  cp "$HARNESS_DIR/cva6-prebuilt.yaml" "$REPO/verif/sim/"
  ISS_YAML=cva6-prebuilt.yaml
  SHARD_DIR="$LOG_DIR/testlists"
  python3 "$ROOT/tools/cva6/split_testlist.py" "$SHARD_DIR" \
    --jobs "$TEST_JOBS" --selection "$SELECTION" >"$LOG_DIR/split.log" || {
    echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: test list splitting failed" >&2; exit 2;
  }
  pids=()
  outputs=()
  run_exit_files=()
  shards=("$SHARD_DIR"/shard-*.yaml)
  selections=()
  partition_args=()
  for shard in "${shards[@]}"; do
    shard_name=$(basename "$shard" .yaml)
    selection="$LOG_DIR/${shard_name}.selection.json"
    if ! python3 "$SET_CHECKER" --testlist "$shard" --simulation-directory "$REPO/verif/sim" \
        --target "$TARGET" >"$selection"; then
      echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: shard selection failed" >&2; exit 2
    fi
    selections+=("$selection")
    partition_args+=(--shard "$selection")
  done
  if ! python3 "$SET_CHECKER" --selection "$SELECTION" "${partition_args[@]}" \
      >"$LOG_DIR/shard-partition.json"; then
    echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: shard selections are not a partition" >&2; exit 2
  fi
  for shard in "${shards[@]}"; do
    shard_name=$(basename "$shard" .yaml)
    output_name="$OUTNAME/$shard_name"
    run_exit_file="$LOG_DIR/${shard_name}.run.exit-code.txt"
    outputs+=("$output_name")
    run_exit_files+=("$run_exit_file")
    (
      run_regression "$output_name" "$shard" "$LOG_DIR/${shard_name}.run.log"
      printf '%s\n' "$?" >"$run_exit_file"
    ) &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  RUN_RC=0
  RTL_INCOMPLETE=0
  : >"$LOG_DIR/iss_regr.log"
  PASSED=0
  FAILED=0
  for index in "${!outputs[@]}"; do
    shard_name=$(basename "${shards[$index]}" .yaml)
    regr_log="$REPO/verif/sim/${outputs[$index]}/iss_regr.log"
    if [ -f "${run_exit_files[$index]}" ] && \
       [ "$(cat "${run_exit_files[$index]}")" -eq 1 ] && \
       has_cpu_cycle_limit "$REPO/verif/sim/${outputs[$index]}"; then
      incomplete "CPU reached the fixed RVFI cycle limit"
    fi
    if [ -f "${run_exit_files[$index]}" ] && \
       [ "$(cat "${run_exit_files[$index]}")" -eq 1 ] && \
       rtl_run_failed "$LOG_DIR/${shard_name}.run.log"; then
      RTL_INCOMPLETE=1
      continue
    fi
    if [ ! -f "${run_exit_files[$index]}" ] || [ ! -f "$regr_log" ]; then
      RUN_RC=2
      continue
    fi
    if [ "$(cat "${run_exit_files[$index]}")" -ne 0 ]; then
      RUN_RC=2
      continue
    fi
    cp "$regr_log" "$LOG_DIR/${shard_name}.iss_regr.log"
    shard_summary=$(grep -E '^[0-9]+ PASSED, [0-9]+ FAILED$' "$regr_log" | tail -1)
    if [ -z "$shard_summary" ]; then
      RUN_RC=2
      continue
    fi
    shard_passed=$(printf '%s\n' "$shard_summary" | sed -E 's/^([0-9]+) PASSED, [0-9]+ FAILED$/\1/')
    shard_failed=$(printf '%s\n' "$shard_summary" | sed -E 's/^[0-9]+ PASSED, ([0-9]+) FAILED$/\1/')
    PASSED=$((PASSED + shard_passed))
    FAILED=$((FAILED + shard_failed))
    printf '===== %s =====\n' "$shard_name" >>"$LOG_DIR/iss_regr.log"
    cat "$regr_log" >>"$LOG_DIR/iss_regr.log"
  done
  if [ "$RTL_INCOMPLETE" -ne 0 ]; then
    incomplete "the RTL simulation of a fixed program did not complete"
  fi
  if [ "$RUN_RC" -ne 0 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: a CPU regression shard did not complete" >&2; exit 2
  fi
  SUMMARY="$PASSED PASSED, $FAILED FAILED"
  printf '%s\n' "$SUMMARY" >>"$LOG_DIR/iss_regr.log"
fi

if [ -z "$SUMMARY" ]; then
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: regression summary is missing" >&2; exit 2
fi

TRACE_COMPARISON_DIR="$LOG_DIR/architectural-trace-comparisons"
RAW_TRACE_DIR="$LOG_DIR/raw-architectural-traces"
mkdir -p "$TRACE_COMPARISON_DIR"
mkdir -p "$RAW_TRACE_DIR/rtl" "$RAW_TRACE_DIR/spike"
TRACE_PASSED=0
TRACE_FAILED=0
CPU_CYCLE_LIMIT=0
if [ "$TEST_JOBS" -eq 1 ]; then
  outputs=("$OUTNAME")
fi
for index in "${!outputs[@]}"; do
  output_name=${outputs[$index]}
  if has_cpu_cycle_limit "$REPO/verif/sim/$output_name"; then
    CPU_CYCLE_LIMIT=1
  elif [ "$?" -eq 3 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: CPU cycle-limit evidence was not retained" >&2; exit 2
  fi
  rtl_directory="$REPO/verif/sim/$output_name/veri-testharness_sim"
  spike_directory="$REPO/verif/sim/$output_name/spike_sim"
  if [ ! -d "$rtl_directory" ] || [ ! -d "$spike_directory" ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: raw architectural trace directory is missing" >&2
    exit 2
  fi
  if ! python3 "$SET_CHECKER" --selection "${selections[$index]}" \
      --rtl "$rtl_directory" --spike "$spike_directory" \
      --report "$REPO/verif/sim/$output_name/iss_regr.log" \
      --alternate "${CPU_EVAL_RTL_TRACE_BASENAME:-}" >"$LOG_DIR/native-set-${index}.json"; then
    if [ "$CPU_CYCLE_LIMIT" -ne 0 ]; then
      incomplete "CPU reached the fixed RVFI cycle limit"
    fi
    echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: native regression output set differs" >&2; exit 2
  fi
  found_trace=0
  rtl_traces=("$rtl_directory"/*.log)
  if [ -n "${CPU_EVAL_RTL_TRACE_BASENAME:-}" ]; then
    rtl_traces=("$rtl_directory/$CPU_EVAL_RTL_TRACE_BASENAME")
    spike_logs=("$spike_directory"/*.log)
    if [ "${#spike_logs[@]}" -ne 1 ] || [ ! -f "${spike_logs[0]}" ]; then
      echo 2 >"$LOG_DIR/exit-code.txt"
      echo "INVALID: the alternate RTL trace requires exactly one Spike trace" >&2
      exit 2
    fi
  fi
  for rtl_trace in "${rtl_traces[@]}"; do
    [ -f "$rtl_trace" ] || continue
    found_trace=1
    trace_name=$(basename "$rtl_trace")
    if [ -n "${CPU_EVAL_RTL_TRACE_BASENAME:-}" ]; then
      spike_trace=${spike_logs[0]}
      trace_name=$(basename "$spike_trace")
    else
      spike_trace="$spike_directory/$trace_name"
    fi
    output_json="$TRACE_COMPARISON_DIR/${trace_name%.log}.json"
    if [ ! -f "$spike_trace" ]; then
      echo 2 >"$LOG_DIR/exit-code.txt"
      echo "INVALID: matching Spike trace is missing for $trace_name" >&2
      exit 2
    fi
    cp "$rtl_trace" "$RAW_TRACE_DIR/rtl/$trace_name"
    cp "$spike_trace" "$RAW_TRACE_DIR/spike/$(basename "$spike_trace")"
    python3 "$HARNESS_DIR/compare_architectural_traces.py" \
      "$rtl_trace" "$spike_trace" --output "$output_json"
    trace_rc=$?
    if [ ! -f "$output_json" ]; then
      if [ "$CPU_CYCLE_LIMIT" -ne 0 ] && [ ! -s "$rtl_trace" ] &&
         has_cpu_cycle_limit "$REPO/verif/sim/$output_name" "$trace_name"; then
        incomplete "CPU reached the fixed RVFI cycle limit"
      fi
      echo 2 >"$LOG_DIR/exit-code.txt"
      echo "INVALID: architectural trace comparison did not complete" >&2
      exit 2
    elif [ "$trace_rc" -eq 0 ]; then
      TRACE_PASSED=$((TRACE_PASSED + 1))
    else
      TRACE_FAILED=$((TRACE_FAILED + 1))
    fi
  done
  if [ "$found_trace" -eq 0 ]; then
    echo 2 >"$LOG_DIR/exit-code.txt"
    echo "INVALID: no raw architectural traces were produced" >&2
    exit 2
  fi
done
printf '%s TRACE PASSED, %s TRACE FAILED\n' "$TRACE_PASSED" "$TRACE_FAILED" \
  >>"$LOG_DIR/iss_regr.log"

FAILED=$(printf '%s\n' "$SUMMARY" | sed -E 's/^[0-9]+ PASSED, ([0-9]+) FAILED$/\1/')
if [ "$CPU_CYCLE_LIMIT" -eq 0 ] && ! python3 "$SET_CHECKER" --selection "$SELECTION" \
    --rtl "$RAW_TRACE_DIR/rtl" --spike "$RAW_TRACE_DIR/spike" \
    --report "$LOG_DIR/iss_regr.log" --comparisons "$TRACE_COMPARISON_DIR" \
    >"$LOG_DIR/collected-set.json"; then
  echo 2 >"$LOG_DIR/exit-code.txt"; echo "INVALID: collected regression output set differs" >&2; exit 2
fi
if [ "$FAILED" -eq 0 ] && [ "$TRACE_FAILED" -eq 0 ] && [ "$CPU_CYCLE_LIMIT" -eq 0 ]; then
  echo 0 >"$LOG_DIR/exit-code.txt"
  echo "PASS: $SUMMARY; $TRACE_PASSED complete architectural traces matched"
  exit 0
fi
if [ "$CPU_CYCLE_LIMIT" -ne 0 ]; then
  incomplete "CPU reached the fixed RVFI cycle limit"
fi
echo 1 >"$LOG_DIR/exit-code.txt"
echo "FAIL: $SUMMARY; $TRACE_FAILED of $((TRACE_PASSED + TRACE_FAILED)) complete architectural traces mismatched"
exit 1
