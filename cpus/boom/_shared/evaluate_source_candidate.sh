#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE TEST_PROGRAM EVIDENCE_DIR" >&2
  exit 2
fi

source_unit=$1
candidate=$2
test_program=$3
evidence_dir=$4
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)

: "${BOOM_WORKTREE:?set BOOM_WORKTREE to the fixed Chipyard checkout}"
: "${BOOM_INVENTORY:?set BOOM_INVENTORY to SOURCE_UNITS.tsv}"
: "${BOOM_BLOCK_TOOL:?set BOOM_BLOCK_TOOL to source_unit_blocks.py}"
: "${BOOM_CHISEL_SOURCE:?set BOOM_CHISEL_SOURCE to the fixed Chisel source checkout}"
: "${BOOM_CHISEL_SBT:?set BOOM_CHISEL_SBT to an sbt launcher jar}"
: "${BOOM_JAVA_BIN:?set BOOM_JAVA_BIN to a Java 17 bin directory}"
: "${BOOM_SBT_IVY_HOME:?set BOOM_SBT_IVY_HOME to an isolated Ivy directory}"
: "${BOOM_RISCV_TOOLS:?set BOOM_RISCV_TOOLS to the Spike and fesvr prefix}"
: "${BOOM_VERILATOR_BIN:?set BOOM_VERILATOR_BIN to the Verilator bin directory}"
: "${BOOM_DTC_BIN:?set BOOM_DTC_BIN to the dtc bin directory}"
: "${BOOM_TRACE_COMPARATOR:?set BOOM_TRACE_COMPARATOR to compare_instruction_traces.py}"
: "${BOOM_CCACHE_DIR:?set BOOM_CCACHE_DIR to a compiler cache directory outside the source tree}"
: "${BOOM_BUILD_JOBS:=8}"

if [[ ! $BOOM_BUILD_JOBS =~ ^[1-9][0-9]*$ ]]; then
  echo "BOOM_BUILD_JOBS must be a positive integer" >&2
  exit 2
fi

mkdir -p "$evidence_dir"
exec 9>"$BOOM_WORKTREE/.cpu-eval-source-replacement.lock"
flock 9

source_record=$(python3 - "$BOOM_INVENTORY" "$source_unit" <<'PY'
import csv, pathlib, sys
rows = [row for row in csv.DictReader(open(sys.argv[1]), delimiter="\t")
        if row["source_unit"] == sys.argv[2]]
if len(rows) != 1:
    raise SystemExit(f"expected one inventory row, found {len(rows)}")
row = rows[0]
path = row["definition_path"]
print(row["source_repository"], path, row["source_file_sha256"], sep="\t")
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

minimum_free_bytes=${BOOM_MIN_FREE_BYTES:-8589934592}
available_bytes=$(df --output=avail -B1 "$BOOM_WORKTREE" | tail -1 | tr -d ' ')
if [[ $available_bytes -lt $minimum_free_bytes ]]; then
  echo "insufficient free space before source replacement: $available_bytes bytes" >&2
  printf 'INVALID\tinsufficient_free_space\n' >"$evidence_dir/verdict.tsv"
  exit 2
fi

original=$(mktemp "$evidence_dir/original.XXXXXX")
cp -- "$source_path" "$original"
chisel_dependency_patch_applied=0
tile_hartid_source=
restore_source() {
  if [[ -n $tile_hartid_source && -f $evidence_dir/tile-hartid-source.backup ]]; then
    mv -f -- "$evidence_dir/tile-hartid-source.backup" "$tile_hartid_source"
  fi
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

git -C "$BOOM_WORKTREE" apply \
  "$script_dir/patches/0007-use-local-chisel-snapshot.patch"
chisel_dependency_patch_applied=1
git -C "$BOOM_WORKTREE/generators/rocket-chip/hardfloat" apply \
  "$script_dir/patches/0008-use-local-chisel-in-hardfloat.patch"
chisel_dependency_patch_applied=2
git -C "$BOOM_WORKTREE/generators/rocket-chip" apply \
  "$script_dir/patches/0009-use-local-chisel-in-rocket-chip.patch"
chisel_dependency_patch_applied=3
git -C "$BOOM_WORKTREE/generators/gemmini" apply \
  "$script_dir/patches/0010-use-local-chisel-in-gemmini.patch"
chisel_dependency_patch_applied=4


replacement_inventory="$BOOM_INVENTORY"
if [[ $source_unit == BoomTileModuleImp ]]; then
  tile_hartid_source="$BOOM_WORKTREE/generators/rocket-chip/src/main/scala/subsystem/HasTiles.scala"
  cp -- "$tile_hartid_source" "$evidence_dir/tile-hartid-source.backup"
  python3 "$script_dir/../boom_tile_module_imp/hartid_check.py" prepare "$tile_hartid_source"
fi
if [[ $source_unit == BoomIOMSHR ]]; then
  replacement_inventory="$evidence_dir/iomshr-monitor-inventory.tsv"
  python3 "$script_dir/../boom_iomshr/store_response_check.py" prepare \
    "$source_path" "$BOOM_INVENTORY" "$replacement_inventory"
fi
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

sbt_version=${BOOM_SBT_VERSION:-1.5.7}
mkdir -p "$BOOM_SBT_IVY_HOME"
chisel_version=${BOOM_CHISEL_VERSION:-3.5-SNAPSHOT}
chisel_plugin_version=${BOOM_CHISEL_PLUGIN_VERSION:-$chisel_version}
chisel_plugin_scala_version=${BOOM_CHISEL_PLUGIN_SCALA_VERSION:-2.12.10}
if [[ $repository != chisel3 && -d /opt/boom-ivy-pristine ]]; then
  python3 - "$BOOM_SBT_IVY_HOME" "$chisel_version" "$chisel_plugin_version" \
    "$chisel_plugin_scala_version" "$evidence_dir/fixed-chisel-publications.json" <<'PYFIXEDCHISEL'
import hashlib, json, pathlib, re, shutil, sys
ivy, version, plugin_version, scala_version, output = sys.argv[1:]
if not all(re.fullmatch(r'[A-Za-z0-9_.-]+', value)
           for value in (version, plugin_version, scala_version)):
    raise RuntimeError('invalid Chisel publication version')
pristine = pathlib.Path('/opt/boom-ivy-pristine/local/edu.berkeley.cs')
destination = pathlib.Path(ivy) / 'local/edu.berkeley.cs'
if any(path.is_symlink() for path in (destination, *destination.parents)):
    raise RuntimeError('refusing symlink Ivy publication directory')
modules = [('chisel3_2.12', version), ('chisel3-core_2.12', version),
           ('chisel3-macros_2.12', version),
           ('chisel3-plugin_' + scala_version, plugin_version)]
def manifest(root):
    result = {}
    for module, revision in modules:
        directory = root / module / revision
        if (root / module).is_symlink() or directory.is_symlink():
            raise RuntimeError('symlink Chisel module directory')
        if not any((directory / 'jars').glob('*.jar')):
            raise RuntimeError('missing fixed Chisel JAR: ' + str(directory))
        for path in sorted(directory.rglob('*')):
            if path.is_symlink():
                raise RuntimeError('symlink in fixed Chisel publication: ' + str(path))
            if path.is_file():
                result[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result
expected = manifest(pristine)
try:
    observed = manifest(destination)
except RuntimeError:
    observed = None
restored = observed != expected
if restored:
    for module, revision in modules:
        target = destination / module / revision
        if target.is_symlink() or target.parent.is_symlink():
            raise RuntimeError('refusing symlink Chisel destination: ' + str(target))
        if target.exists():
            shutil.rmtree(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(pristine / module / revision, target)
if manifest(destination) != expected:
    raise RuntimeError('fixed Chisel publication SHA mismatch after preparation')
pathlib.Path(output).write_text(json.dumps({
    'pristine_root': str(pristine), 'ivy_root': str(destination),
    'restored': restored, 'sha256': expected}, sort_keys=True, indent=2) + '\n')
PYFIXEDCHISEL
  printf '%s\n' 'REUSE_FIXED_CHISEL: immutable image publications verified' >"$evidence_dir/chisel-publish.log"
  chisel_publish_rc=0
else
set +e
(cd "$BOOM_CHISEL_SOURCE" && \
  "$BOOM_JAVA_BIN/java" -Dsbt.coursier=false -Dsbt.ivy.home="$BOOM_SBT_IVY_HOME" \
    -jar "$BOOM_CHISEL_SBT" \
    ";clean;set every version := \"$chisel_version\";publishLocal;++$chisel_plugin_scala_version;set plugin / version := \"$chisel_plugin_version\";plugin/publishLocal") \
  >"$evidence_dir/chisel-publish.log" 2>&1
chisel_publish_rc=$?
set -e
fi
printf '%s\n' "$chisel_publish_rc" >"$evidence_dir/chisel-publish.exit"
if [[ $chisel_publish_rc -ne 0 ]]; then
  # Only a Chisel source unit places the candidate in the published library.
  if [[ $repository == chisel3 ]]; then
    cause_rc=0
    python3 "$script_dir/failure_cause.py" build --publication "$evidence_dir/chisel-publish.log" \
      "$chisel_publish_rc" "$evidence_dir/candidate-region.json" "$candidate" \
      >"$evidence_dir/verdict.tsv" || cause_rc=$?
    exit $((cause_rc == 1 ? 1 : 2))
  fi
  printf 'INVALID\tfixed_chisel_publication\n' >"$evidence_dir/verdict.tsv"
  exit 2
fi
sbt_bg_jobs="$BOOM_WORKTREE/target/bg-jobs"
dsptools_target="$BOOM_WORKTREE/tools/dsptools/src/target"
if [[ $BOOM_WORKTREE != /* || $BOOM_WORKTREE == / || ! -f "$BOOM_WORKTREE/build.sbt" ]]; then
  echo "refusing to remove SBT caches outside a Chipyard checkout: $BOOM_WORKTREE" >&2
  exit 2
fi
rm -rf "$sbt_bg_jobs"
rm -rf "$dsptools_target"
export SBT_BIN="$BOOM_JAVA_BIN/java -Dsbt.coursier=false -Dsbt.ivy.home=$BOOM_SBT_IVY_HOME -Dsbt.version=$sbt_version -jar $BOOM_CHISEL_SBT"
export PATH="$BOOM_JAVA_BIN:$PATH"

if [[ $source_unit == MaxPeriodFibonacciLFSR && ${CPU_EVAL_MAX_PERIOD_LFSR_PORTS:-0} == 1 ]]; then
  "$script_dir/../max_period_fibonacci_lfsr/evaluate_candidate.sh" --ports "$candidate" "$evidence_dir"
fi
export PATH="$BOOM_VERILATOR_BIN:$BOOM_DTC_BIN:$PATH"
if [[ $source_unit == Queue ]]; then
  bash "$script_dir/../queue/test/run_ports.sh" "$evidence_dir" "$candidate" > "$evidence_dir/queue-ports.tsv"
fi

export CCACHE_DIR="$BOOM_CCACHE_DIR"
export CCACHE_BASEDIR="$BOOM_WORKTREE"
export CCACHE_NOHASHDIR=true
export CCACHE_SLOPPINESS=pch_defines,time_macros
export VM_PARALLEL_BUILDS=1
mkdir -p "$CCACHE_DIR"
verilator_version=$("$BOOM_VERILATOR_BIN/verilator" --version)
verilator_major=$(printf '%s\n' "$verilator_version" | awk '{print $2}' | sed -E 's/^v?([0-9]+).*/\1/')
timing_flag=
if [[ $verilator_major =~ ^[0-9]+$ ]] && (( verilator_major >= 5 )); then
  timing_flag=--no-timing
fi
sim_dir="$BOOM_WORKTREE/sims/verilator"
config=${BOOM_CONFIG:-LargeBoomCommitTraceConfig}
model_dir="$sim_dir/generated-src/chipyard.TestHarness.$config/chipyard.TestHarness.$config"
generated_dir=$(dirname "$model_dir")
simulator="$sim_dir/simulator-chipyard-$config"
expected_generated_dir="$sim_dir/generated-src/chipyard.TestHarness.$config"
if [[ $generated_dir != "$expected_generated_dir" ]]; then
  echo "refusing to remove unexpected generated directory: $generated_dir" >&2
  exit 2
fi
rm -rf "$generated_dir"
rm -f "$simulator"

set +e
make -C "$sim_dir" -j"$BOOM_BUILD_JOBS" \
  CONFIG="$config" \
  OBJCACHE=ccache \
  EXTRA_SIM_CXXFLAGS="-std=c++17 -include optional -include stdexcept" \
  OPT_FAST="-Os -std=c++17" \
  VERILATOR_THREADS=1 \
  VERILATOR_OPT_FLAGS="-O3 --x-assign fast --x-initial fast --output-split 10000 --output-split-cfuncs 100 $timing_flag" \
  RISCV="$BOOM_RISCV_TOOLS" >"$evidence_dir/build.log" 2>&1 &
build_pid=$!
while kill -0 "$build_pid" 2>/dev/null; do
  if [[ -f "$model_dir/VTestHarness__pch.h" ]]; then
    ln -sfn VTestHarness__pch.h "$model_dir/VTestHarness__pch.h.fast"
    ln -sfn VTestHarness__pch.h "$model_dir/VTestHarness__pch.h.slow"
    break
  fi
  sleep 1
done
wait "$build_pid"
build_rc=$?
set -e
printf '%s\n' "$build_rc" >"$evidence_dir/build.exit"
if [[ $build_rc -ne 0 ]]; then
  cause_rc=0
  python3 "$script_dir/failure_cause.py" build "$evidence_dir/build.log" "$build_rc" \
    "$evidence_dir/candidate-region.json" "$candidate" >"$evidence_dir/verdict.tsv" || cause_rc=$?
  exit $((cause_rc == 1 ? 1 : 2))
fi

if [[ "${BOOM_PRESERVE_SIMULATOR:-0}" == 1 ]]; then
  cp --reflink=auto "$simulator" "$evidence_dir/simulator"
fi

rtl_rc=0
"$script_dir/run_simulator.sh" "$simulator" "$test_program" "$evidence_dir/rtl.log" || rtl_rc=$?
printf '%s\n' "$rtl_rc" >"$evidence_dir/rtl.exit"
run_rc=0
python3 "$script_dir/failure_cause.py" run "$evidence_dir/rtl.log" "$rtl_rc" \
  >"$evidence_dir/run-verdict.tsv" || run_rc=$?
if [[ $run_rc -ne 0 ]]; then
  mv -- "$evidence_dir/run-verdict.tsv" "$evidence_dir/verdict.tsv"
  # An interrupted trace run is still compared, because a recorded mismatch is a FAIL.
  if [[ $run_rc -ne 2 || ${BOOM_DIRECTED_PROGRAM:-0} == 1 || -n ${BOOM_DIRECTED_XREG:-} ]]; then
    exit "$run_rc"
  fi
fi
rm -f -- "$evidence_dir/run-verdict.tsv"
if [[ "${BOOM_DIRECTED_PROGRAM:-0}" == 1 ]]; then
  program_result=$(sed -nE 's/.*\*\*\* (PASSED|FAILED) \*\*\*.*/\1/p' \
    "$evidence_dir/rtl.log" | tail -1)
  printf 'expected\tobserved\nPASSED\t%s\n' "$program_result" \
    >"$evidence_dir/directed-result.tsv"
  if [[ $rtl_rc -eq 0 && $program_result == PASSED ]]; then
    comparison_rc=0
    printf 'PASS\tdirected_program_passed\n' >"$evidence_dir/verdict.tsv"
  else
    comparison_rc=1
    printf 'FAIL\tdirected_program_failed\n' >"$evidence_dir/verdict.tsv"
  fi
  printf '%s\n' "$comparison_rc" >"$evidence_dir/comparison.exit"
  sha256sum "$candidate" "$test_program" "$simulator" \
    "$evidence_dir/rtl.log" "$evidence_dir/directed-result.tsv" \
    >"$evidence_dir/evidence.sha256"
  exit "$comparison_rc"
fi
if [[ -n ${BOOM_DIRECTED_XREG:-} ]]; then
  : "${BOOM_DIRECTED_EXPECTED:?set BOOM_DIRECTED_EXPECTED with BOOM_DIRECTED_XREG}"
  directed_comparison=${BOOM_DIRECTED_COMPARISON:-directed_register}
  if [[ $directed_comparison != directed_register && $directed_comparison != directed_register_max ]]; then
    echo "unknown directed-register comparison: $directed_comparison" >&2
    exit 2
  fi
  if [[ ! $BOOM_DIRECTED_XREG =~ ^x([1-9]|[12][0-9]|3[01])$ ]]; then
    echo "BOOM_DIRECTED_XREG must name x1 through x31" >&2
    exit 2
  fi
  if [[ $rtl_rc -ne 0 ]] || ! grep -q '\*\*\* PASSED \*\*\*' "$evidence_dir/rtl.log"; then
    printf 'FAIL\trtl_program_did_not_pass\t%s\n' "$rtl_rc" >"$evidence_dir/verdict.tsv"
    exit 1
  fi
  observed=$(python3 - "$evidence_dir/rtl.log" "$BOOM_DIRECTED_XREG" <<'PY'
import re
import sys

pattern = re.compile(rf"\b{re.escape(sys.argv[2])}\s+0x([0-9a-fA-F]+)\b")
values = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as stream:
    for line in stream:
        match = pattern.search(line)
        if match:
            values.append(match.group(1).lower())
if not values:
    raise SystemExit(2)
print(values[-1])
PY
  ) || {
    printf 'FAIL\tmissing_directed_register\t%s\n' "$BOOM_DIRECTED_XREG" >"$evidence_dir/verdict.tsv"
    exit 1
  }
  expected=$(python3 - "$BOOM_DIRECTED_EXPECTED" <<'PY'
import sys
print(f"{int(sys.argv[1], 0):016x}")
PY
  ) || {
    echo "BOOM_DIRECTED_EXPECTED must be an integer literal" >&2
    exit 2
  }
  observed=$(python3 - "$observed" <<'PY'
import sys
print(f"{int(sys.argv[1], 16):016x}")
PY
  )
  printf 'register\texpected\tobserved\n%s\t%s\t%s\n' \
    "$BOOM_DIRECTED_XREG" "$expected" "$observed" >"$evidence_dir/directed-result.tsv"
  if [[ $observed == "$expected" || ( $directed_comparison == directed_register_max && $observed < $expected ) ]]; then
    comparison_rc=0
    printf 'PASS\tdirected_register_match\n' >"$evidence_dir/verdict.tsv"
  else
    comparison_rc=1
    printf 'FAIL\tdirected_register_mismatch\n' >"$evidence_dir/verdict.tsv"
  fi
  printf '%s\n' "$comparison_rc" >"$evidence_dir/comparison.exit"
  sha256sum "$candidate" "$test_program" "$simulator" \
    "$evidence_dir/rtl.log" "$evidence_dir/directed-result.tsv" \
    >"$evidence_dir/evidence.sha256"
  exit "$comparison_rc"
fi
set +e
timeout 180 "$BOOM_RISCV_TOOLS/bin/spike" --isa=rv64imafdc --log-commits \
  "$test_program" >"$evidence_dir/spike.stdout" 2>"$evidence_dir/spike.log"
spike_rc=$?
set -e
printf '%s\n' "$spike_rc" >"$evidence_dir/spike.exit"
if [[ $spike_rc -ne 0 ]]; then
  printf 'INVALID\tspike_exit\t%s\n' "$spike_rc" >"$evidence_dir/verdict.tsv"
  exit 2
fi
set +e
python3 "$BOOM_TRACE_COMPARATOR" \
  "$evidence_dir/rtl.log" "$evidence_dir/spike.log" \
  --report "$evidence_dir/comparison.json"
comparison_rc=$?
set -e
if [[ $run_rc -eq 2 ]]; then
  if [[ $comparison_rc -eq 1 ]] && python3 "$script_dir/trace_mismatch.py" "$evidence_dir/comparison.json"; then
    printf 'FAIL\ttrace_mismatch\n' >"$evidence_dir/verdict.tsv"
    comparison_rc=1
  else
    comparison_rc=2
  fi
elif [[ $comparison_rc -eq 0 && $rtl_rc -ne 0 ]]; then
  printf 'FAIL_INCOMPLETE_EXECUTION\trtl_nonzero_exit\t%s\n' "$rtl_rc" >"$evidence_dir/verdict.tsv"
  comparison_rc=1
elif [[ $comparison_rc -eq 0 ]]; then
  printf 'PASS\ttrace_match\n' >"$evidence_dir/verdict.tsv"
elif [[ $comparison_rc -eq 1 ]]; then
  printf 'FAIL\ttrace_mismatch\n' >"$evidence_dir/verdict.tsv"
else
  printf 'INVALID\ttrace_comparison_error\n' >"$evidence_dir/verdict.tsv"
  comparison_rc=2
fi
printf '%s\n' "$comparison_rc" >"$evidence_dir/comparison.exit"
sha256sum "$candidate" "$test_program" "$simulator" \
  "$evidence_dir/rtl.log" "$evidence_dir/spike.log" \
  >"$evidence_dir/evidence.sha256"
exit "$comparison_rc"
