#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE EVIDENCE_DIR" >&2
  exit 2
fi
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
if [[ $1 != NullLocalBranchPredictorBank ]]; then
  echo "unexpected source unit: $1" >&2
  exit 2
fi
exec bash "$script_dir/../_shared/evaluate_directed_source_test.sh" \
  "$1" "$2" "$script_dir/tests/NullLocalBranchPredictorBankPortTest.scala" \
  boom.tests.NullLocalBranchPredictorBankPortTest "$3"
