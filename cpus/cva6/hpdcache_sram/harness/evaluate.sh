#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_sram.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)
: "${CVA6_REPO:?CVA6_REPO is required}"

candidate=$(realpath "$1")
base_log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

export CVA6_TESTLIST="$script_directory/testlist_sram.yaml"
export CVA6_TEST_JOBS=1
mkdir -p "$base_log_root" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
invocation_log_root=$(mktemp -d "$base_log_root/hpdcache_sram-invocation-XXXXXX") || {
  echo "INVALID: cannot create an invocation log root" >&2
  exit 2
}
export CPU_EVAL_LOG_ROOT="$invocation_log_root"
set +e
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_sram "$candidate"
shared_rc=$?
set -e

case "$shared_rc" in
  0|1) ;;
  *) echo "INVALID: shared evaluator exited with $shared_rc" >&2; exit 2 ;;
esac

candidate_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
shopt -s nullglob
run_directories=("$invocation_log_root/hpdcache_sram/"*"-${candidate_sha:0:12}")
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
  echo "INVALID: directed-test evidence is missing" >&2
  exit 2
fi
if ! grep -Eq '^(0 PASSED, 1 FAILED|1 PASSED, 0 FAILED)$' "$run_directory/iss_regr.log"; then
  echo "INVALID: the cycle-measurement program did not complete normally" >&2
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
    echo "FAIL: directed trace differed beyond timing-register values" >&2
    exit 1
  fi
  echo "INVALID: complete timing-only comparison with one x20 delta was not found" >&2
  exit 2
}

printf 'RTL_CYCLE_DELTA=%s\n' "$cycle_delta"
expected=1034
directed_rc=0
if [ "$cycle_delta" != "$expected" ]; then
  echo "FAIL: completed RTL cycle delta $cycle_delta differed from $expected"
  directed_rc=1
fi

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
export CPU_EVAL_LOG_ROOT="$base_log_root/standard"
set +e
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_sram "$candidate"
standard_rc=$?
set -e
# A definite mismatch outranks a check that could not finish.
if [ "$directed_rc" -ne 0 ] || [ "$standard_rc" -eq 1 ]; then
  exit 1
fi
if [ "$standard_rc" -ne 0 ]; then
  exit 2
fi
