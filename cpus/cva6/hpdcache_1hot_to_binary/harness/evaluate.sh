#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_1hot_to_binary.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)
: "${CVA6_REPO:?CVA6_REPO is required}"

candidate=$(realpath "$1")
base_log_root=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$cpu_directory/hpdcache_victim_sel/harness/testlist_victim_sel.yaml"
export CVA6_TEST_JOBS=1
mkdir -p "$base_log_root" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
invocation_log_root=$(mktemp -d "$base_log_root/hpdcache_1hot_to_binary-invocation-XXXXXX") || {
  echo "INVALID: cannot create an invocation log root" >&2
  exit 2
}
export CPU_EVAL_LOG_ROOT="$invocation_log_root"
set +e
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_1hot_to_binary "$candidate"
shared_rc=$?
set -e

case "$shared_rc" in
  0|1) ;;
  *) echo "INVALID: shared evaluator exited with $shared_rc" >&2; exit 2 ;;
esac

candidate_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
shopt -s nullglob
run_directories=("$invocation_log_root/hpdcache_1hot_to_binary/"*"-${candidate_sha:0:12}")
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
    echo "FAIL: directed trace differed beyond the measurement values" >&2
    exit 1
  fi
  echo "INVALID: complete measurement trace with one x20 delta was not found" >&2
  exit 2
}

printf 'RTL_CYCLE_DELTA=%s\n' "$cycle_delta"

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
export CPU_EVAL_LOG_ROOT="$base_log_root/standard"
set +e
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_1hot_to_binary "$candidate"
standard_rc=$?
set -e
if [ "$standard_rc" -ne 0 ] && [ "$standard_rc" -ne 1 ]; then
  exit 2
fi
[ "$standard_rc" -eq 0 ] || exit 1

port_logs="$base_log_root/onehot-ports"
mkdir -p "$port_logs" || exit 2
work=$(mktemp -d) || exit 2
trap 'find "$work" -depth -delete' EXIT
python3 "$cpu_directory/../../tools/cva6/replace_module.py" --module hpdcache_1hot_to_binary \
    --candidate "$candidate" --output "$work/candidate.sv" ||
  { echo "INVALID: cannot extract the submitted hpdcache_1hot_to_binary module" >&2; exit 2; }
hpdcache="$CVA6_REPO/core/cache_subsystem/hpdcache/rtl"
source "$cpu_directory/harness/port_observation.sh" || exit 2
observation_rc=0
port_observation "$port_logs/build.log" "$port_logs/observations.log" "$work/candidate.sv" "$candidate" 30 \
    "$work/build/Vonehot_ports_tb" verilator --binary --timing -Wno-fatal --top-module onehot_ports_tb \
     -j "${CPU_EVAL_BUILD_JOBS:-${NUM_JOBS:-1}}" --Mdir "$work/build" \
     -I"$hpdcache/include" -y "$hpdcache/src/common" \
     "$hpdcache/src/hpdcache_pkg.sv" "$work/candidate.sv" "$script_directory/onehot_ports_tb.sv" || observation_rc=$?
if [ "$observation_rc" -eq 2 ]; then
  echo "INVALID: one-hot port observation was stopped by a tool or resource failure" >&2
  exit 2
fi
if [ "$observation_rc" -ne 0 ] || grep -Fxq ONEHOT_PORTS_FAIL "$port_logs/observations.log" ||
   ! grep -Fxq ONEHOT_PORTS_PASS "$port_logs/observations.log"; then
  echo "FAIL: one-hot port output differed from the encoded index or the bench did not finish" >&2
  exit 1
fi
echo "PASS: CPU traces and one-hot port outputs match"
