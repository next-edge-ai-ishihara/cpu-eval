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
fixture="$script_dir/test/RVCExpanderDoubleMemoryTest.scala"

"$shared_dir/evaluate_source_candidate_suite.sh" \
  "$source_unit" "$candidate" "$tests_file" "$test_root" "$evidence_dir"

ports="$evidence_dir/ports"
ports_rc=0
"$shared_dir/evaluate_directed_source_test.sh" \
  "$source_unit" "$candidate" "$fixture" boom.tests.RVCExpanderDoubleMemoryTest "$ports" || ports_rc=$?

verdict=INVALID
if [[ -s $ports/verdict.tsv ]]; then
  verdict=$(cut -f1 "$ports/verdict.tsv")
fi
if [[ $ports_rc -eq 0 && $verdict != PASS ]]; then
  ports_rc=2
fi
printf 'rvc_double_memory\t%s\t%s\n' "$verdict" "$ports_rc" >>"$evidence_dir/summary.tsv"
sha256sum "$candidate" "$tests_file" "$fixture" "$evidence_dir/summary.tsv" >"$evidence_dir/combined-evidence.sha256"
exit "$ports_rc"
