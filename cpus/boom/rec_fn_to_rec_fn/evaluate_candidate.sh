#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 || $1 != RecFNToRecFN ]]; then
  echo "usage: $0 RecFNToRecFN CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
ports="$5/ports"
status=0
bash "$script_dir/../_shared/evaluate_directed_source_test.sh" \
  "$1" "$2" "$script_dir/tests/RecFNToRecFNNaNTest.scala" \
  boom.tests.RecFNToRecFNNaNTest "$ports" || status=$?
if [[ $status -ne 0 ]]; then
  if [[ -f $ports/verdict.tsv ]]; then
    cp -- "$ports/verdict.tsv" "$5/verdict.tsv"
  else
    printf 'INVALID\tport_test_did_not_run\n' >"$5/verdict.tsv"
  fi
  exit "$status"
fi
exec bash "$script_dir/../_shared/evaluate_source_candidate_suite.sh" "$@"
