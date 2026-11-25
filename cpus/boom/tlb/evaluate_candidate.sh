#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 || $1 != TLB ]]; then
  echo "usage: $0 TLB CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
directory=$(cd -- "$(dirname -- "$0")" && pwd)
evidence=$5
ports="$evidence/ports"
status=0
"$directory/../_shared/evaluate_directed_source_test.sh" "$1" "$2" \
  "$directory/test/InstructionTLBTranslationTest.scala" \
  boom.tests.InstructionTLBTranslationTest "$ports" || status=$?
if [[ -f $ports/verdict.tsv ]]; then
  verdict=$(cut -f1 "$ports/verdict.tsv")
  if [[ $verdict == PASS || $verdict == FAIL ]] &&
     ! grep -Eq '(^|[[:space:]])ITLB_OBSERVATIONS_STARTED$' "$ports/test.log"; then
    printf 'FAIL\tinstruction_tlb_ports_not_observed\n' >"$evidence/verdict.tsv"
    exit 1
  fi
fi
if [[ $status -ne 0 ]]; then
  if [[ -f $ports/verdict.tsv ]]; then
    cp -- "$ports/verdict.tsv" "$evidence/verdict.tsv"
  else
    printf 'INVALID\tinstruction_tlb_ports_did_not_run\n' >"$evidence/verdict.tsv"
  fi
  exit "$status"
fi
exec "$directory/../_shared/evaluate_source_candidate_suite.sh" "$@"
