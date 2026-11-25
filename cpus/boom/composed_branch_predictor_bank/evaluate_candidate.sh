#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 || $1 != ComposedBranchPredictorBank ]]; then
  echo "usage: $0 ComposedBranchPredictorBank CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
shared="$source_dir/../_shared"
evidence=$5
ports="$evidence/public-ports"
test_source="$source_dir/test/ComposedPredictorPortsTest.scala"
mkdir -p "$ports"
unit_status=0
"$shared/evaluate_directed_source_test.sh" \
  "$1" "$2" "$test_source" boom.tests.ComposedPredictorPortsTest "$ports" \
  2>"$ports/driver.stderr" || unit_status=$?
summary="$evidence/summary.tsv"
unit_verdict=INVALID
if [[ -f $ports/verdict.tsv ]]; then
  unit_verdict=$(cut -f1 "$ports/verdict.tsv")
fi
printf 'test\tverdict\texit_code\ncomposed_predictor_ports\t%s\t%s\n' "$unit_verdict" "$unit_status" >"$summary"
if [[ $unit_verdict != PASS || $unit_status -ne 0 ]]; then
  case "$unit_verdict" in
    FAIL*) cp "$ports/verdict.tsv" "$evidence/verdict.tsv"; exit 1 ;;
    *) exit 2 ;;
  esac
fi

cpu_status=0
"$shared/evaluate_source_candidate_suite.sh" "$1" "$2" "$3" "$4" "$evidence/cpu" || cpu_status=$?
if [[ -f $evidence/cpu/summary.tsv ]]; then
  tail -n +2 "$evidence/cpu/summary.tsv" >>"$summary"
fi
if [[ -f $evidence/cpu/verdict.tsv ]]; then
  cp "$evidence/cpu/verdict.tsv" "$evidence/verdict.tsv"
fi
exit "$cpu_status"
