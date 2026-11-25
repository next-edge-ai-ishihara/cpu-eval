#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 || $1 != IssueSlot ]]; then
  echo "usage: $0 IssueSlot CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
directory=$(cd -- "$(dirname -- "$0")" && pwd)
evidence=$5
test_source="$directory/test/IssueSlotSpeculationTest.scala"
shared="$directory/../_shared"

"$shared/evaluate_source_candidate_suite.sh" "$@"

ports="$evidence/speculation"
status=0
"$shared/evaluate_directed_source_test.sh" "$1" "$2" "$test_source" \
  boom.tests.IssueSlotSpeculationTest "$ports" || status=$?

verdict=INVALID
if [[ -s $ports/verdict.tsv ]]; then
  verdict=$(cut -f1 "$ports/verdict.tsv")
fi
if [[ $verdict == PASS || $verdict == FAIL ]] &&
  ! grep -qF 'IssueSlot speculation observations started' "$ports/test.log"; then
  verdict=FAIL
  status=1
fi
if [[ $verdict == INVALID ]]; then
  status=2
fi
printf 'issue_slot_speculative_issue_retry\t%s\t%s\n' "$verdict" "$status" >>"$evidence/summary.tsv"
sha256sum "$2" "$3" "$test_source" "$evidence/summary.tsv" >"$evidence/combined-evidence.sha256"
exit "$status"
