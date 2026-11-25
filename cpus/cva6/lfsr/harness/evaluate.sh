#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-lfsr.sv>" >&2
  exit 2
fi

lock_repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$lock_repo.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $lock_repo" >&2
    exit 2
  fi
else
  exec 9>"$lock_repo.cpu-eval.lock" || { echo "INVALID: cannot open the evaluation lock" >&2; exit 2; }
fi
flock -n 9 || { echo "INVALID: another evaluation owns $lock_repo" >&2; exit 2; }
export CVA6_EVALUATION_LOCK_FD=9

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
candidate=$(realpath "$1")
log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
mkdir -p "$log_root" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
invocation_log_root=$(mktemp -d "$log_root/lfsr-invocation-XXXXXX") || {
  echo "INVALID: cannot create an invocation log root" >&2
  exit 2
}
export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_lfsr_icache_cycles.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="$invocation_log_root"

port_log_root="$invocation_log_root"
if [[ ${log_root##*/} == runs ]]; then
  port_log_root="$(dirname "$log_root")/${invocation_log_root##*/}-ports"
fi
ports_rc=0
CPU_EVAL_LOG_ROOT="$port_log_root" python3 "$cpu_directory/instr_scan/harness/evaluate_ports.py" "$candidate" --module lfsr || ports_rc=$?
if [ "$ports_rc" -ne 0 ]; then
  shopt -s nullglob
  port_runs=("$port_log_root"/lfsr-ports-*)
  if [[ $ports_rc -eq 1 && ${#port_runs[@]} -eq 1 ]] &&
     grep -qFx 'FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv' "${port_runs[0]}/runtime.log"; then
    receipt="$invocation_log_root/lfsr/port-compile"
    if ! mkdir -p "$receipt" ||
       ! cp -- "${port_runs[0]}/build.log" "$receipt/build.log" ||
       ! cp -- "$receipt/build.log" "$receipt/candidate-compile-error.txt" ||
       ! cp -- "${port_runs[0]}/exit-code.txt" "$receipt/exit-code.txt"; then
      echo "INVALID: failed to record the attributed port compiler error" >&2
      exit 2
    fi
  fi
  exit "$ports_rc"
fi

set +e
"$cpu_directory/harness/evaluate_parallel.sh" lfsr "$candidate"
shared_rc=$?
set -e

case "$shared_rc" in
  0|1) ;;
  *) echo "INVALID: shared evaluator exited with $shared_rc" >&2; exit 2 ;;
esac

candidate_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
shopt -s nullglob
run_directories=("$invocation_log_root/lfsr/"*"-${candidate_sha:0:12}")
if [ "${#run_directories[@]}" -ne 1 ] || [ ! -d "${run_directories[0]}" ]; then
  echo "INVALID: one shared evaluator run was not recorded" >&2
  exit 2
fi
run_directory=${run_directories[0]}
if [ "$shared_rc" -eq 1 ] && [ -f "$run_directory/candidate-compile-error.txt" ]; then
  echo "FAIL_CANDIDATE_COMPILE: shared compiler error identifies the submitted source"
  exit 1
fi
if [ "$shared_rc" -eq 1 ] && [ -d "$run_directory/cycle-limit-evidence" ] && \
   find "$run_directory/cycle-limit-evidence" -name binding.json -print -quit | grep -q .; then
  echo "FAIL: CPU reached the fixed RVFI cycle limit"
  exit 1
fi
if [ "$shared_rc" -eq 1 ] && [ -s "$run_directory/incomplete-execution.txt" ]; then
  echo "FAIL: $(cat "$run_directory/incomplete-execution.txt")"
  exit 1
fi
if [ ! -f "$run_directory/iss_regr.log" ]; then
  echo "INVALID: shared evaluator evidence is missing" >&2
  exit 2
fi
if ! grep -Eq '^(0 PASSED, 1 FAILED|1 PASSED, 0 FAILED)$' "$run_directory/iss_regr.log"; then
  echo "INVALID: the RTL-only program did not complete normally" >&2
  exit 2
fi

rtl_traces=("$run_directory/raw-architectural-traces/rtl/"*.log)
spike_traces=("$run_directory/raw-architectural-traces/spike/"*.log)
if [ "${#rtl_traces[@]}" -ne 1 ] || [ "${#spike_traces[@]}" -ne 1 ] || \
   [ ! -f "${rtl_traces[0]}" ] || [ ! -f "${spike_traces[0]}" ] || \
   [ "$(basename "${rtl_traces[0]}")" != "$(basename "${spike_traces[0]}")" ]; then
  echo "INVALID: the completed RTL trace was not recorded" >&2
  exit 2
fi

expected=108,112,117,115,108
set +e
python3 "$script_directory/compare_cycle_trace.py" "${rtl_traces[0]}" "${spike_traces[0]}" \
  --expected "$expected" --output "$run_directory/lfsr-complete-trace-comparison.json"
comparison_rc=$?
set -e
case "$comparison_rc" in
  0|1|2) exit "$comparison_rc" ;;
  *) echo "INVALID: complete trace comparison exited with $comparison_rc" >&2; exit 2 ;;
esac
