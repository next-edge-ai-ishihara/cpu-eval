#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 || $1 != BoomIOMSHR ]]; then
  echo "usage: $0 BoomIOMSHR CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
evidence=$5
directory=$(cd -- "$(dirname -- "$0")" && pwd)
status=0
"$directory/../_shared/evaluate_source_candidate_suite.sh" "$@" || status=$?
python3 "$directory/store_response_check.py" result "$evidence" "$status"
