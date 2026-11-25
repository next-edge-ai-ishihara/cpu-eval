#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_core_arbiter.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_core_arbiter "$1"

logs="${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the evaluation results directory}/core-arbiter-ports"
mkdir -p "$logs" || exit 2
work=$(mktemp -d) || exit 2
trap 'find "$work" -depth -delete' EXIT
python3 "$cpu_directory/../../tools/cva6/replace_module.py" --module hpdcache_core_arbiter \
    --candidate "$1" --output "$work/candidate.sv" ||
  { echo "INVALID: cannot extract the submitted hpdcache_core_arbiter module" >&2; exit 2; }
hpdcache="${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}/core/cache_subsystem/hpdcache/rtl"
source "$cpu_directory/harness/port_observation.sh" || exit 2
observation_rc=0
port_observation "$logs/build.log" "$logs/observations.log" "$work/candidate.sv" "$1" 30 \
    "$work/build/Vcore_arbiter_ports_tb" verilator --binary --timing -Wno-fatal --top-module core_arbiter_ports_tb \
     -j "${CPU_EVAL_BUILD_JOBS:-${NUM_JOBS:-1}}" --Mdir "$work/build" \
     -I"$hpdcache/include" -y "$hpdcache/src/common" \
     "$hpdcache/src/hpdcache_pkg.sv" "$work/candidate.sv" "$script_directory/core_arbiter_ports_tb.sv" || observation_rc=$?
if [ "$observation_rc" -eq 2 ]; then
  echo "INVALID: core-arbiter port observation was stopped by a tool or resource failure" >&2
  exit 2
fi
outcomes=()
[ "$observation_rc" -ne 0 ] ||
  mapfile -t outcomes < <(grep -E '^CORE_ARB_PORTS_(PASS|FAIL)$' "$logs/observations.log")
if [ "${#outcomes[@]}" -ne 1 ] || [ "${outcomes[0]}" != CORE_ARB_PORTS_PASS ]; then
  echo "FAIL: HPDcache core-arbiter request hold or previous PMA differed or the bench did not finish" >&2
  exit 1
fi
echo "PASS: CPU traces and core-arbiter port observations match"
