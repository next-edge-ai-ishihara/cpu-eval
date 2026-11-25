#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 || $1 != BoomTileModuleImp ]]; then
  echo "usage: $0 BoomTileModuleImp CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
tests=$3
test_root=$4
evidence=$5
directory=$(cd -- "$(dirname -- "$0")" && pwd)
"$directory/../_shared/evaluate_source_candidate_suite.sh" "$@"
first=$(awk 'NF && !/^[[:space:]]*#/ { print $1; exit }' "$tests")
probe="$evidence/hartid-probe"
mkdir -p "$probe"
status=0
# The boot ROM reads mhartid within its first instructions; the probe needs no program completion.
BOOM_MAX_CYCLES=20000 BOOM_SIMULATION_WALL_SEC=600 "$directory/../_shared/run_simulator.sh" \
  "$evidence/tests/000-$first/simulator" "$test_root/rv64mi-p-hartid_observe" "$probe/rtl.log" \
  +cpu_eval_tile_hartid=1 || status=$?
python3 "$directory/hartid_check.py" check "$evidence" "$status"
