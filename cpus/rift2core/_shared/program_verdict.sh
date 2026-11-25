# Program and run verdicts shared by the Rift2Core evaluators (sourced, not executed).
# Every reference program passes, so only an interruption or a tool failure is INVALID.

RUNTIME_ENVIRONMENT_ERROR='std::bad_alloc|cannot allocate memory|out of memory|no space left on device|error while loading shared libraries|input/output error|DROMAJO Init Failed|^Prase Error'
CYCLE_LIMIT_LINE='Timeout!!!!!'

# program_verdict LOG EXIT [REQUIRED_MARKER] [PERFORMANCE_LOG]
# Prints PASS, TRACE_MISMATCH, OBSERVATION_MISMATCH, CYCLE_LIMIT, INCOMPLETE, NOT_RUN or INVALID.
program_verdict() {
  local log=$1 code=$2 marker=${3:-} performance=${4:-0}
  if [ "$code" = NOT_RUN ]; then echo NOT_RUN; return; fi
  if [ ! -f "$log" ] || [[ ! "$code" =~ ^[0-9]+$ ]]; then echo INVALID; return; fi
  case "$code" in 124|137|143) echo INVALID; return ;; esac
  if grep -Eqi -- "$RUNTIME_ENVIRONMENT_ERROR" "$log"; then echo INVALID
  elif [ "$code" -eq 255 ] && grep -q '^Failed at' "$log" &&
       grep -Eq '^(failed at dromajo pc = 0x[0-9a-f]+|Fail!!!!!!)$' "$log"; then echo TRACE_MISMATCH
  elif grep -q 'CPU_EVAL_OBSERVATION_MISMATCH' "$log"; then echo OBSERVATION_MISMATCH
  elif grep -Fxq -- "$CYCLE_LIMIT_LINE" "$log"; then echo CYCLE_LIMIT
  elif [ "$code" -ne 0 ]; then echo INCOMPLETE
  elif [ "$performance" = 1 ] && ! grep -Fxq 'Pass!' "$log"; then echo INCOMPLETE
  elif [ "$performance" != 1 ] && [ "$(tail -n 1 "$log")" != 'Pass!' ]; then echo INCOMPLETE
  elif grep -q '^Failed at' "$log"; then echo TRACE_MISMATCH
  elif [ -n "$marker" ] && ! grep -Fxq -- "$marker" "$log"; then echo INCOMPLETE
  else echo PASS
  fi
}

# run_program_once LOG_DIR LOG DIRECTORY COMMAND...: a program that reaches the cycle limit takes
# about two minutes, so the programs after it are not run; the run is already a FAIL.
run_program_once() {
  local log_dir=$1 log=$2 directory=$3
  shift 3
  if [ -e "$log_dir/cycle-limit-reached" ]; then echo NOT_RUN >"$log.exit"; return; fi
  (cd "$directory" && "$@") >"$log" 2>&1
  echo $? >"$log.exit"
  if grep -Fxq -- "$CYCLE_LIMIT_LINE" "$log"; then : >"$log_dir/cycle-limit-reached"; fi
}

# run_verdict RESULTS_TSV: prints the run verdict from column 2 and returns its exit code.
run_verdict() {
  local results=$1
  if awk -F '\t' 'NR > 1 && $2 == "TRACE_MISMATCH" { found=1 } END { exit !found }' "$results"; then
    echo "FUNCTIONAL FAIL: trace mismatch"; return 1
  elif awk -F '\t' 'NR > 1 && $2 ~ /OBSERVATION_MISMATCH$/ { found=1 } END { exit !found }' "$results"; then
    echo "FUNCTIONAL FAIL: observation mismatch"; return 1
  elif awk -F '\t' 'NR > 1 && ($2 == "CYCLE_LIMIT" || $2 == "INCOMPLETE") { found=1 } END { exit !found }' "$results"; then
    echo "FUNCTIONAL FAIL: program did not complete"; return 1
  elif awk -F '\t' 'NR > 1 && $2 != "PASS" { found=1 } END { exit !found }' "$results"; then
    echo "INVALID: at least one test was interrupted"; return 2
  fi
  echo "PASS"
}

# answer_build_failure LOG REGION CANDIDATE CLASS: succeeds when a failed build step is the answer's fault.
answer_build_failure() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/candidate_error.py" "$@"
  [ $? -eq 1 ]
}
