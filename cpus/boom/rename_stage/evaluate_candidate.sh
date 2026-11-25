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
requested_tests_file=$tests_file
python3 "$shared_dir/evaluation_policy.py" \
  --cpu-dir "$script_dir/.." --problem rename_stage \
  --output "$evidence_dir/current-policy"
python3 - "$requested_tests_file" "$evidence_dir/current-policy/tests.txt" "$evidence_dir/current-policy/policy.tsv" <<'PYTESTS'
from pathlib import Path
import csv, sys
def tests(path):
    return [line.split("#",1)[0].strip() for line in Path(path).read_text().splitlines()
            if line.split("#",1)[0].strip()]
requested=tests(sys.argv[1])
recorded=tests(sys.argv[2])
if requested != recorded:
    raise SystemExit("requested tests differ from the recorded rename policy")
loop="rv64mi-p-loop_branch_cycles"
if loop not in recorded:
    raise SystemExit("recorded loop observation is absent")
selected=[test for test in recorded if test != loop]
Path(sys.argv[2]).write_text("\n".join(selected)+"\n")
policy=Path(sys.argv[3])
rows=list(csv.reader(policy.open(),delimiter="\t"))
filtered=[rows[0]]+[row for row in rows[1:] if row[0] != loop]
with policy.open("w") as stream:
    csv.writer(stream,delimiter="\t",lineterminator="\n").writerows(filtered)
PYTESTS
tests_file="$evidence_dir/current-policy/tests.txt"
export BOOM_TEST_POLICY="$evidence_dir/current-policy/policy.tsv"
set +e
"$shared_dir/evaluate_source_candidate_suite.sh" \
  "$source_unit" "$candidate" "$tests_file" "$test_root" "$evidence_dir/cpu"
cpu_rc=$?
set -e
printf '%s\n' "$cpu_rc" >"$evidence_dir/cpu.exit"
printf 'test\tverdict\texit_code\n' >"$evidence_dir/summary.tsv"
if [[ -f $evidence_dir/cpu/summary.tsv ]]; then
  tail -n +2 "$evidence_dir/cpu/summary.tsv" >>"$evidence_dir/summary.tsv"
else
  printf 'cpu_suite\tINVALID\t%s\n' "$cpu_rc" >>"$evidence_dir/summary.tsv"
fi
first=$(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$tests_file" | head -1)
simulator="$evidence_dir/cpu/tests/000-$first/simulator"
observation_rc=0
"$shared_dir/observe_program.sh" "$simulator" "$test_root/rv64mi-p-loop_branch_cycles" \
  "$evidence_dir/cycle-observation" || observation_rc=$?
observation_verdict=$(cut -f1 "$evidence_dir/cycle-observation/verdict.tsv" 2>/dev/null || printf INVALID)
printf 'cycle_observation_completed\t%s\t%s\n' "$observation_verdict" "$observation_rc" \
  >>"$evidence_dir/summary.tsv"
sha256sum "$candidate" "$requested_tests_file" "$tests_file" \
  "$evidence_dir/summary.tsv" >"$evidence_dir/evidence.sha256"
[[ $cpu_rc -eq 0 && $observation_rc -eq 0 ]] &&
  awk -F '\t' 'NR > 1 { seen++; if ($2 != "PASS") bad++ } END { exit (!seen || bad) }' \
    "$evidence_dir/summary.tsv"
