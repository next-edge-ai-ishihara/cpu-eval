#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
source_unit=$1
candidate=$2
tests_file=$3
test_root=$4
evidence_dir=$5
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
shared_dir="$script_dir/../_shared"
mkdir -p "$evidence_dir"
set +e
"$shared_dir/evaluate_source_candidate_suite.sh" \
  "$source_unit" "$candidate" "$tests_file" "$test_root" "$evidence_dir/cpu"
cpu_rc=$?
"$shared_dir/evaluate_directed_source_test.sh" \
  "$source_unit" "$candidate" "$script_dir/test/FTQPublicContractTest.scala" \
  boom.tests.FTQPublicContractTest "$evidence_dir/public-output"
unit_rc=$?
set -e
printf '%s\n' "$cpu_rc" >"$evidence_dir/cpu.exit"
printf '%s\n' "$unit_rc" >"$evidence_dir/public-output.exit"
printf 'test\tverdict\texit_code\n' >"$evidence_dir/summary.tsv"
if [[ -f $evidence_dir/cpu/summary.tsv ]]; then
  tail -n +2 "$evidence_dir/cpu/summary.tsv" >>"$evidence_dir/summary.tsv"
else
  printf 'cpu_suite\tINVALID\t%s\n' "$cpu_rc" >>"$evidence_dir/summary.tsv"
fi
unit_verdict=INVALID
if [[ -f $evidence_dir/public-output/verdict.tsv ]]; then
  unit_verdict=$(cut -f1 "$evidence_dir/public-output/verdict.tsv")
fi
printf 'ftq_pc_redirect_history_and_commit\t%s\t%s\n' "$unit_verdict" "$unit_rc" >>"$evidence_dir/summary.tsv"
first=$(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$tests_file" | head -1)
simulator="$evidence_dir/cpu/tests/000-$first/simulator"
observation_rc=0
"$shared_dir/observe_program.sh" "$simulator" "$test_root/rv64mi-p-fetch_target_queue_cycles" \
  "$evidence_dir/cycle-observation" || observation_rc=$?
printf 'cycle_observation_completed\t%s\t%s\n' \
  "$(cut -f1 "$evidence_dir/cycle-observation/verdict.tsv" 2>/dev/null || printf INVALID)" "$observation_rc" \
  >>"$evidence_dir/summary.tsv"
sha256sum "$candidate" "$tests_file" "$script_dir/test/FTQPublicContractTest.scala" \
  "$evidence_dir/summary.tsv" >"$evidence_dir/evidence.sha256"
[[ $cpu_rc -eq 0 && $unit_rc -eq 0 && $unit_verdict == PASS && $observation_rc -eq 0 ]] &&
  awk -F '\t' 'NR > 1 { seen++; if ($2 != "PASS") bad++ } END { exit (!seen || bad) }' \
    "$evidence_dir/summary.tsv"
