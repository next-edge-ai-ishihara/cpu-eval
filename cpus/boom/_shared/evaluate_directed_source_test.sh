#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE TEST_SOURCE TEST_CLASS EVIDENCE_DIR" >&2
  exit 2
fi

source_unit=$1
candidate=$2
test_source=$3
test_class=$4
evidence_dir=$5
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)

: "${BOOM_WORKTREE:?set BOOM_WORKTREE to the fixed Chipyard checkout}"
: "${BOOM_INVENTORY:?set BOOM_INVENTORY to SOURCE_UNITS.tsv}"
: "${BOOM_BLOCK_TOOL:?set BOOM_BLOCK_TOOL to source_unit_blocks.py}"
: "${BOOM_CHISEL_SOURCE:?set BOOM_CHISEL_SOURCE to the fixed Chisel source checkout}"
: "${BOOM_CHISEL_SBT:?set BOOM_CHISEL_SBT to an sbt launcher jar}"
: "${BOOM_JAVA_BIN:?set BOOM_JAVA_BIN to a Java 17 bin directory}"
: "${BOOM_SBT_IVY_HOME:?set BOOM_SBT_IVY_HOME to an isolated Ivy directory}"

mkdir -p "$evidence_dir"
exec 9>"$BOOM_WORKTREE/.cpu-eval-source-replacement.lock"
flock 9
source_record=$(python3 - "$BOOM_INVENTORY" "$source_unit" <<'PY'
import csv, sys
rows = [row for row in csv.DictReader(open(sys.argv[1]), delimiter="\t")
        if row["source_unit"] == sys.argv[2]]
if len(rows) != 1:
    raise SystemExit(f"expected one inventory row, found {len(rows)}")
row = rows[0]
print(row["source_repository"], row["definition_path"], row["source_file_sha256"], sep="\t")
PY
)
IFS=$'\t' read -r repository definition_path expected_hash <<<"$source_record"
if [[ $repository == chisel3 ]]; then
  source_path="$BOOM_CHISEL_SOURCE/$definition_path"
else
  source_path="$BOOM_WORKTREE/$definition_path"
fi
actual_hash=$(sha256sum "$source_path" | cut -d' ' -f1)
if [[ $actual_hash != "$expected_hash" ]]; then
  echo "source hash mismatch before replacement: $source_path" >&2
  printf 'INVALID\tfixed_source_hash_mismatch\n' >"$evidence_dir/verdict.tsv"
  exit 2
fi

original=$(mktemp "$evidence_dir/original.XXXXXX")
cp -- "$source_path" "$original"
chisel_dependency_patch_applied=0
restore_source() {
  if [[ -f $original ]]; then
    mv -f -- "$original" "$source_path"
  fi
  if [[ $chisel_dependency_patch_applied == 4 ]]; then
    git -C "$BOOM_WORKTREE/generators/gemmini" apply --reverse \
      "$script_dir/patches/0010-use-local-chisel-in-gemmini.patch"
    chisel_dependency_patch_applied=3
  fi
  if [[ $chisel_dependency_patch_applied == 3 ]]; then
    git -C "$BOOM_WORKTREE/generators/rocket-chip" apply --reverse \
      "$script_dir/patches/0009-use-local-chisel-in-rocket-chip.patch"
    chisel_dependency_patch_applied=2
  fi
  if [[ $chisel_dependency_patch_applied == 2 ]]; then
    git -C "$BOOM_WORKTREE/generators/rocket-chip/hardfloat" apply --reverse \
      "$script_dir/patches/0008-use-local-chisel-in-hardfloat.patch"
    chisel_dependency_patch_applied=1
  fi
  if [[ $chisel_dependency_patch_applied == 1 ]]; then
    git -C "$BOOM_WORKTREE" apply --reverse \
      "$script_dir/patches/0007-use-local-chisel-snapshot.patch"
    chisel_dependency_patch_applied=0
  fi
  restored_hash=$(sha256sum "$source_path" | cut -d' ' -f1)
  if [[ $restored_hash != "$expected_hash" ]]; then
    echo "failed to restore source: $source_path" >&2
    return 1
  fi
}
finish() {
  rc=$?
  trap - EXIT INT TERM
  if ! restore_source; then
    exit 125
  fi
  printf '%s\n' "$restored_hash" >"$evidence_dir/source-restored.sha256"
  exit "$rc"
}
trap finish EXIT INT TERM

git -C "$BOOM_WORKTREE" apply "$script_dir/patches/0007-use-local-chisel-snapshot.patch"
chisel_dependency_patch_applied=1
git -C "$BOOM_WORKTREE/generators/rocket-chip/hardfloat" apply "$script_dir/patches/0008-use-local-chisel-in-hardfloat.patch"
chisel_dependency_patch_applied=2
git -C "$BOOM_WORKTREE/generators/rocket-chip" apply "$script_dir/patches/0009-use-local-chisel-in-rocket-chip.patch"
chisel_dependency_patch_applied=3
git -C "$BOOM_WORKTREE/generators/gemmini" apply "$script_dir/patches/0010-use-local-chisel-in-gemmini.patch"
chisel_dependency_patch_applied=4


replacement_inventory="$BOOM_INVENTORY"
if [[ $source_unit == TageTable || $source_unit == TageBranchPredictorBank ]]; then
  reference_patch="$script_dir/../tage_table/patches/0002-preserve-masked-training-counters.patch"
  git -C "$BOOM_WORKTREE/generators/boom" apply --check "$reference_patch"
  git -C "$BOOM_WORKTREE/generators/boom" apply "$reference_patch"
  replacement_inventory="$evidence_dir/reference-inventory.tsv"
  python3 - "$BOOM_INVENTORY" "$source_path" "$source_unit" "$replacement_inventory" <<'PYREFERENCE'
import csv, hashlib, pathlib, re, sys
inventory, source, unit, output = sys.argv[1:]
source = pathlib.Path(source)
text = source.read_text()
with open(inventory) as stream:
    reader = csv.DictReader(stream, delimiter="\t")
    fields = reader.fieldnames
    rows = list(reader)
selected = [row for row in rows if row["source_unit"] == unit]
if len(selected) != 1:
    raise SystemExit("reference inventory must identify exactly one source unit")
match = re.search(r"^class\s+" + re.escape(unit) + r"\b", text, re.MULTILINE)
if match is None:
    raise SystemExit("reference source declaration is absent")
selected[0]["source_file_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
selected[0]["definition_line"] = str(text.count("\n", 0, match.start()) + 1)
with open(output, "w") as stream:
    writer = csv.DictWriter(stream, fields, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PYREFERENCE
fi

replacement_rc=0
python3 "$BOOM_BLOCK_TOOL" \
  --inventory "$replacement_inventory" \
  --source-root "$BOOM_WORKTREE" \
  --chisel-source-root "$BOOM_CHISEL_SOURCE" \
  --unit "$source_unit" \
  --replace "$candidate" \
  --region-output "$evidence_dir/candidate-region.json" >"$evidence_dir/replacement.tsv" || replacement_rc=$?
if [[ $replacement_rc -eq 3 ]]; then
  printf 'FAIL_CANDIDATE_COMPILE\tcandidate_scala_definition_error\n' >"$evidence_dir/verdict.tsv"
  exit 1
elif [[ $replacement_rc -ne 0 ]]; then
  exit 2
fi

export PATH="$BOOM_JAVA_BIN:$PATH"
test_command=";set boom / Test / unmanagedSources := Seq(file(\"$test_source\"));set boom / libraryDependencies += \"edu.berkeley.cs\" %% \"chisel-iotesters\" % \"2.5.0\" % Test;boom/testOnly $test_class"
set +e
(cd "$BOOM_WORKTREE" && "$BOOM_JAVA_BIN/java" \
  -Dsbt.coursier=false -Dsbt.ivy.home="$BOOM_SBT_IVY_HOME" -Dsbt.version=1.5.7 \
  -jar "$BOOM_CHISEL_SBT" "$test_command") \
  >"$evidence_dir/test.log" 2>&1
test_rc=$?
set -e
printf '%s\n' "$test_rc" >"$evidence_dir/test.exit"
verdict_rc=0
python3 "$script_dir/failure_cause.py" directed "$evidence_dir/test.log" "$test_rc" \
  "$evidence_dir/candidate-region.json" "$candidate" >"$evidence_dir/verdict.tsv" || verdict_rc=$?
sha256sum "$candidate" "$test_source" >"$evidence_dir/evidence.sha256"
exit "$verdict_rc"
