#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 5 ]] || { echo "usage: $0 SOURCE_UNIT CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2; exit 2; }
source_unit=$1; candidate=$2; tests_file=$3; test_root=$4; evidence_dir=$5
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
shared_dir="$script_dir/../_shared"
mkdir -p "$evidence_dir"
python3 "$shared_dir/evaluation_policy.py" --cpu-dir "$script_dir/.." --problem i_cache_module --output "$evidence_dir/current-policy"
python3 - "$tests_file" "$evidence_dir/current-policy/tests.txt" "$evidence_dir/current-policy/policy.tsv" <<'PYPOLICY'
import csv, pathlib, sys
def tests(p):
 return [v.split("#",1)[0].strip() for v in pathlib.Path(p).read_text().splitlines() if v.split("#",1)[0].strip()]
expected=["rv64mi-p-cache_replacement_cycles"]
if tests(sys.argv[1]) != expected or tests(sys.argv[2]) != expected:
 raise SystemExit("requested tests differ from recorded ICache program")
with open(sys.argv[3],"w") as stream:
 writer=csv.writer(stream,delimiter="\t",lineterminator="\n")
 writer.writerow(["test","mode","register","expected"])
 writer.writerow([expected[0],"directed_program","",""])
PYPOLICY
export BOOM_TEST_POLICY="$evidence_dir/current-policy/policy.tsv"
export CPU_EVAL_ICACHE_TARGET="$evidence_dir/public-output/treadle"
set +e
"$shared_dir/evaluate_source_candidate_suite.sh" "$source_unit" "$candidate" "$evidence_dir/current-policy/tests.txt" "$test_root" "$evidence_dir/cpu"
cpu_rc=$?
"$shared_dir/evaluate_directed_source_test.sh" "$source_unit" "$candidate" "$script_dir/test/ICachePublicContractTest.scala" boom.tests.ICachePublicContractTest "$evidence_dir/public-output"
unit_rc=$?
set -e
printf '%s\n' "$cpu_rc" >"$evidence_dir/cpu.exit"
printf '%s\n' "$unit_rc" >"$evidence_dir/public-output.exit"
printf 'test\tverdict\texit_code\n' >"$evidence_dir/summary.tsv"
if [[ -f $evidence_dir/cpu/summary.tsv ]]; then
 tail -n +2 "$evidence_dir/cpu/summary.tsv" >>"$evidence_dir/summary.tsv"
else
 printf 'cpu_program\tINVALID\t%s\n' "$cpu_rc" >>"$evidence_dir/summary.tsv"
fi
unit_verdict=INVALID
if [[ -f $evidence_dir/public-output/verdict.tsv ]]; then unit_verdict=$(cut -f1 "$evidence_dir/public-output/verdict.tsv"); fi
printf 'icache_public_relationships\t%s\t%s\n' "$unit_verdict" "$unit_rc" >>"$evidence_dir/summary.tsv"
python3 - "$evidence_dir" <<'PYOBSERVATION'
import pathlib,re,sys
d=pathlib.Path(sys.argv[1]);p=d/"cpu/tests/000-rv64mi-p-cache_replacement_cycles/rtl.log"
s=p.read_text(errors="replace") if p.is_file() else ""
v=re.findall(r"\bx20\s+0x([0-9a-fA-F]+)\b",s)
(d/"cycle-observation.tsv").write_text("register\tobserved\nx20\t"+(f"{int(v[-1],16):016x}" if v else "missing")+"\n")
PYOBSERVATION
sha256sum "$candidate" "$tests_file" "$script_dir/test/ICachePublicContractTest.scala" "$evidence_dir/summary.tsv" "$evidence_dir/cycle-observation.tsv" >"$evidence_dir/evidence.sha256"
[[ $cpu_rc -eq 0 && $unit_rc -eq 0 && $unit_verdict == PASS ]] &&
 awk -F '\t' 'NR > 1 {seen++; if ($2 != "PASS") bad++} END {exit (!seen || bad)}' "$evidence_dir/summary.tsv"
