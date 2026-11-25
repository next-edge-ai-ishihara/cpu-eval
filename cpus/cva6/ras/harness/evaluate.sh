#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-ras.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
candidate=$(realpath "$1")
log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

mkdir -p "$log_root" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
invocation_log_root=$(mktemp -d "$log_root/ras-invocation-XXXXXX") || {
  echo "INVALID: cannot create an invocation log root" >&2
  exit 2
}

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_ras_cycles.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="$invocation_log_root"

set +e
"$cpu_directory/harness/evaluate_parallel.sh" ras "$candidate"
shared_rc=$?
set -e

case "$shared_rc" in
  0|1) ;;
  *)
    echo "INVALID: shared evaluator exited with $shared_rc" >&2
    exit 2
    ;;
esac

candidate_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
shopt -s nullglob
run_directories=("$invocation_log_root/ras/"*"-${candidate_sha:0:12}")
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
port_status=0
port_output=$(python3 "$cpu_directory/instr_scan/harness/evaluate_ports.py" "$candidate" --module ras 2>&1) || port_status=$?
printf '%s\n' "$port_output"
if grep -q '^FAIL_CANDIDATE_COMPILE:' <<<"$port_output"; then
  echo "FAIL: the port bench, which builds with the reference, did not build with the submission"
  exit 1
fi
exit "$port_status"
