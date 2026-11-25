#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
[[ $1 == LSU ]] || { echo "Expected LSU source unit" >&2; exit 2; }
python3 - "$3" "$script_dir/TESTS.txt" <<'PY'
from pathlib import Path
import sys
def tests(path):
    return [line.split("#",1)[0].strip() for line in Path(path).read_text().splitlines()
            if line.split("#",1)[0].strip()]
if tests(sys.argv[1]) != tests(sys.argv[2]):
    print("requested tests differ from the recorded LSU suite", file=sys.stderr)
    raise SystemExit(2)
PY
export BOOM_TRACE_COMPARATOR="$script_dir/compare_lsu_traces.py"
exec "$script_dir/../_shared/evaluate_source_candidate_suite.sh" "$@"
