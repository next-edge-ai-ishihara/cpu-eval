#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-instr_scan.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
candidate=$(realpath "$1")
log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_instr_scan_cycles.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="$log_root"

mkdir -p "$log_root" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
invocation_log_root=$(mktemp -d "$log_root/instr_scan-invocation-XXXXXX") || {
  echo "INVALID: cannot create an invocation log root" >&2
  exit 2
}
export CPU_EVAL_LOG_ROOT="$invocation_log_root"
port_log_root="$invocation_log_root"
if [[ ${log_root##*/} == runs ]]; then
  port_log_root="$(dirname "$log_root")/${invocation_log_root##*/}-ports"
fi
set +e
CPU_EVAL_LOG_ROOT="$port_log_root" python3 "$script_directory/evaluate_ports.py" "$candidate"
ports_rc=$?
if [ "$ports_rc" -ne 0 ]; then
  shopt -s nullglob
  port_runs=("$port_log_root"/instr_scan-ports-*)
  if [[ $ports_rc -eq 1 && ${#port_runs[@]} -eq 1 ]] &&
     grep -qFx 'FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv' "${port_runs[0]}/runtime.log"; then
    receipt="$invocation_log_root/instr_scan/port-compile"
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
"$cpu_directory/harness/evaluate_parallel.sh" instr_scan "$candidate"
shared_rc=$?
set -e

case "$shared_rc" in
  0|1) ;;
  *) echo "INVALID: shared evaluator exited with $shared_rc" >&2; exit 2 ;;
esac

candidate_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
shopt -s nullglob
run_directories=("$invocation_log_root/instr_scan/"*"-${candidate_sha:0:12}")
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
if [ "${#rtl_traces[@]}" -ne 1 ] || [ "${#spike_traces[@]}" -ne 1 ]; then
  echo "INVALID: one complete RTL and Spike measurement trace was not recorded" >&2
  exit 2
fi

cycle_delta=$(python3 "$cpu_directory/harness/compare_cycle_measurement.py" "${rtl_traces[0]}" "${spike_traces[0]}") || {
  extraction_rc=$?
  if [ "$extraction_rc" -eq 1 ]; then
    echo "FAIL: directed trace differed beyond the measurement values" >&2
    exit 1
  fi
  echo "INVALID: complete measurement trace with one x20 delta was not found" >&2
  exit 2
}

printf 'RTL_CYCLE_DELTA=%s\n' "$cycle_delta"
expected=49184
if [ "$cycle_delta" = "$expected" ]; then
  echo "PASS: completed RTL cycle delta matched $expected"
  exit 0
fi
echo "FAIL: completed RTL cycle delta $cycle_delta differed from $expected"
exit 1
