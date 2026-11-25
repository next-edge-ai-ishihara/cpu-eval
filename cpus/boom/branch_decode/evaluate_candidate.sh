#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 || $1 != BranchDecode ]]; then
  echo "usage: $0 BranchDecode CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
directory=$(cd -- "$(dirname -- "$0")" && pwd)
evidence=$5
port_status=0
"$directory/../_shared/evaluate_directed_source_test.sh" "$1" "$2" \
  "$directory/test/BranchDecodePortsTest.scala" boom.tests.BranchDecodePortsTest \
  "$evidence/ports" || port_status=$?
if [[ -f $evidence/ports/verdict.tsv ]]; then
  port_verdict=$(cut -f1 "$evidence/ports/verdict.tsv")
  if [[ $port_verdict == PASS || $port_verdict == FAIL ]] &&
    ! grep -Fq 'BranchDecode port observations started' "$evidence/ports/test.log"; then
    printf 'FAIL\tbranch_decode_ports_not_observed\n' >"$evidence/verdict.tsv"
    exit 1
  fi
fi
if [[ $port_status -ne 0 ]]; then
  if [[ -f $evidence/ports/verdict.tsv ]]; then
    cp "$evidence/ports/verdict.tsv" "$evidence/verdict.tsv"
  fi
  exit "$port_status"
fi
"$directory/../_shared/evaluate_source_candidate_suite.sh" "$@"
