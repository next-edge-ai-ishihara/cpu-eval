#!/usr/bin/env bash

set -uo pipefail

PROBLEM_DIR="${1:-}"
CANDIDATE="${2:-}"
if [ ! -f "$PROBLEM_DIR/TEST_RECIPE.json" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <problem-directory> <candidate.scala>" >&2
  exit 2
fi
PROBLEM_DIR="$(cd "$PROBLEM_DIR" && pwd)"
CANDIDATE="$(cd "$(dirname "$CANDIDATE")" && pwd)/$(basename "$CANDIDATE")"
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../../_shared/program_verdict.sh"

readarray -t META < <(python3 - "$PROBLEM_DIR/TEST_RECIPE.json" <<'PY'
import json, sys
x=json.load(open(sys.argv[1]))
r=x["candidate_replacement"]
print(r["source_unit"])
print(r["revision"])
print(r["library"]["artifact_version"])
print(r["library"]["jar_sha256"])
PY
)
TARGET_CLASS="${META[0]}"
EXPECTED_RIFT="${META[1]}"
CHISEL_VERSION="${META[2]}"
CHISEL_JAR_SHA256="${META[3]}"

REPO="${REPO:?Set REPO to the pinned Rift2Core checkout}"
DROMAJO_DIR="${DROMAJO_DIR:?Set DROMAJO_DIR to the built Dromajo directory}"
VERILATOR="${VERILATOR:?Set VERILATOR to the Verilator executable}"
MILLW="${MILLW:?Set MILLW to the Mill wrapper executable}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
FIRTOOL_DIR="${FIRTOOL_DIR:?Set FIRTOOL_DIR to the directory containing firtool}"
TEST_IMAGE_DIR="${TEST_IMAGE_DIR:?Set TEST_IMAGE_DIR to the fixed ELF and memory initialization files}"
TEST_NAME_PATTERN="${TEST_NAME_PATTERN:-}"
STOP_AFTER_FUNCTIONAL_FAIL="${STOP_AFTER_FUNCTIONAL_FAIL:-0}"
VERILATOR_JOBS="${VERILATOR_JOBS:-8}"
EVAL_ROOT="${EVAL_ROOT:?Set EVAL_ROOT to the evaluation output directory}"
TIMEOUT_SEC="${TIMEOUT_SEC:-600}"
SHIM="$EVAL_ROOT/shim"
PRISTINE_CACHE="${PRISTINE_CACHE:-${PRISTINE_COURSIER_CACHE:?Set PRISTINE_COURSIER_CACHE to the prepared Chisel cache}}"
PATCH="$HERE/../../environment/rift2core-chisel5-compatibility.patch"
CHECKOUT="$EVAL_ROOT/checkout"
CACHE="$EVAL_ROOT/coursier-cache"
RUN_ID="$(date -u +%Y-%m-%dT%H%M%SZ)_${TARGET_CLASS}_$(basename "$CANDIDATE" .scala)"
LOG_DIR="$EVAL_ROOT/runs/$RUN_ID"
mkdir -p "$LOG_DIR" "$EVAL_ROOT"
exec > >(tee "$LOG_DIR/evaluate.stdout.log") 2> >(tee "$LOG_DIR/evaluate.stderr.log" >&2)

CHISEL_REL="https/repo1.maven.org/maven2/org/chipsalliance/chisel_2.13/$CHISEL_VERSION"
CHISEL_JAR="$CHISEL_REL/chisel_2.13-$CHISEL_VERSION.jar"

for path in "$REPO/.git" "$DROMAJO_DIR/build/libdromajo_cosim.a" "$VERILATOR" \
  "$MILLW" "$JAVA_HOME/bin/java" "$FIRTOOL_DIR/firtool" "$PATCH" "$TEST_IMAGE_DIR" \
  "$PRISTINE_CACHE/$CHISEL_JAR"; do
  if [ ! -e "$path" ]; then echo "missing dependency: $path" >&2; exit 2; fi
done
if [ "$(sha256sum "$PRISTINE_CACHE/$CHISEL_JAR" | cut -d' ' -f1)" != "$CHISEL_JAR_SHA256" ]; then
  echo "pinned Chisel jar hash mismatch" >&2
  exit 2
fi
if [ "$(git -c safe.directory="$REPO" -C "$REPO" rev-parse HEAD)" != "$EXPECTED_RIFT" ]; then
  echo "source revision mismatch" >&2; exit 2
fi

exec 9>"$EVAL_ROOT/checkout.lock"
flock 9
if [ ! -d "$CHECKOUT/.git" ]; then
  mkdir -p "$CHECKOUT"
  rsync -a --exclude generated/build --exclude out --exclude target "$REPO/" "$CHECKOUT/"
fi
if [ "$(git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" rev-parse HEAD)" != "$EXPECTED_RIFT" ]; then
  echo "evaluation checkout revision mismatch" >&2; exit 2
fi

git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" restore -- .
git -c safe.directory="$CHECKOUT/dependencies/constellation" -C "$CHECKOUT/dependencies/constellation" restore -- .
git -c safe.directory="$CHECKOUT/dependencies/rocket-chip" -C "$CHECKOUT/dependencies/rocket-chip" restore -- .
sed -i 's/\r$//' "$CHECKOUT/tb/verilator/diff.cpp"
if ! git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply --check "$PATCH"; then
  echo "fixed environment patch does not apply" >&2; exit 2
fi
git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply "$PATCH"
if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" >"$LOG_DIR/fixed-test-patches.tsv" <<'PY'
import json, sys
patches = json.load(open(sys.argv[1])).get("fixed_test_patches", [])
rows = [f'{patch["path"]}\t{patch["sha256"]}' for patch in patches]
for row in rows:
    print(row)
PY
then
  echo "INVALID: fixed test-patch recipe could not be decoded"
  exit 2
fi
while IFS=$'\t' read -r relative_patch expected_hash; do
  [ -n "$relative_patch" ] || continue
  test_patch="$PROBLEM_DIR/$relative_patch"
  if [ ! -f "$test_patch" ] || [ "$(sha256sum "$test_patch" | cut -d' ' -f1)" != "$expected_hash" ]; then
    echo "fixed test patch is missing or has an unexpected hash: $relative_patch" >&2
    exit 2
  fi
  if ! git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply --ignore-space-change --check "$test_patch"; then
    echo "fixed test patch does not apply: $relative_patch" >&2
    exit 2
  fi
  git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply --ignore-space-change "$test_patch"
done <"$LOG_DIR/fixed-test-patches.tsv"
cp "$MILLW" "$CHECKOUT/mill" && chmod +x "$CHECKOUT/mill"

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$FIRTOOL_DIR:$(dirname "$VERILATOR"):$PATH"

echo "[evaluate] candidate: $CANDIDATE"
sha256sum "$CANDIDATE"
mkdir -p "$SHIM/shim/src"
cat >"$SHIM/build.sc" <<EOF
import mill._, scalalib._

object shim extends ScalaModule {
  def scalaVersion = "2.13.10"
  def ivyDeps = Agg(ivy"org.chipsalliance::chisel:$CHISEL_VERSION")
  def scalacPluginIvyDeps = Agg(ivy"org.chipsalliance:::chisel-plugin:$CHISEL_VERSION")
}
EOF
echo 0.11.6 >"$SHIM/.mill-version"
cp "$MILLW" "$SHIM/mill" && chmod +x "$SHIM/mill"
python3 - "$HERE/../../../.." "$CANDIDATE" "$SHIM/shim/src/MaxPeriodFibonacciLFSR.scala" "$TARGET_CLASS" "$LOG_DIR/candidate-region.json" 2>"$LOG_DIR/prepare.log" <<'PY'
import json, pathlib, sys
sys.path.insert(0, sys.argv[1])
from tools.evaluation.scala_compile_diagnostics import source_region
from tools.submission.scala_definition import prepare_submission
try:
    candidate = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
except UnicodeDecodeError as error:
    raise SystemExit(f"FAIL_CANDIDATE_DEFINITION: {error}")
header = "// SPDX-License-Identifier: Apache-2.0\n\npackage chisel3.util.random\n\nimport chisel3._\n\n"
source = pathlib.Path(sys.argv[3])
try:
    prepared = prepare_submission(candidate, sys.argv[4], header)
except ValueError as error:
    # A missing declaration is the answer's fault; an ambiguous match stays INVALID.
    if "was not found" in str(error) and f"`{sys.argv[4]}`" not in candidate:
        raise SystemExit(f"FAIL_CANDIDATE_DEFINITION: {error}")
    raise
source.write_text(prepared, encoding="utf-8")
start = prepared.index(candidate)
region = source_region(source, prepared, start, start + len(candidate))
pathlib.Path(sys.argv[5]).write_text(json.dumps(region) + "\n", encoding="utf-8")
PY
prepare_status=$?
cat "$LOG_DIR/prepare.log" >&2
case "$prepare_status" in
  0) ;;
  1) if grep -q '^FAIL_CANDIDATE_DEFINITION:' "$LOG_DIR/prepare.log"; then
       echo "FAIL_CANDIDATE_DEFINITION: invalid submitted class declaration"; exit 1
     fi
     echo "INVALID: candidate could not be prepared"; exit 2 ;;
  *) echo "INVALID: candidate could not be prepared"; exit 2 ;;
esac
# Mill may reuse a recorded successful compile while its task cache remains.

rm -rf "$SHIM/out/shim"
(cd "$SHIM" && ./mill -i shim.compile) >"$LOG_DIR/shim_compile.log" 2>&1
compile_rc=$?
if [ "$compile_rc" -ne 0 ] || [ ! -f "$SHIM/out/shim/compile.dest/classes/chisel3/util/random/$TARGET_CLASS.class" ]; then
  if answer_build_failure "$LOG_DIR/shim_compile.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
    echo "FAIL_CANDIDATE_COMPILE: submitted source did not compile"; exit 1
  fi
  echo "INVALID: the pinned Chisel compile environment failed"; exit 2
fi
rm -rf "$CACHE"
mkdir -p "$CACHE/$CHISEL_REL"
cp -a "$PRISTINE_CACHE/$CHISEL_REL/." "$CACHE/$CHISEL_REL/"
chmod u+w "$CACHE/$CHISEL_JAR"
python3 - "$CACHE/$CHISEL_JAR" "$SHIM/out/shim/compile.dest/classes" "$TARGET_CLASS" \
  >"$LOG_DIR/splice.log" 2>&1 <<'PY'
import os, shutil, sys, zipfile
jar, classes, target = sys.argv[1], sys.argv[2], sys.argv[3]
pkg = "chisel3/util/random/"
root = os.path.join(classes, *pkg.rstrip("/").split("/"))
new = {
    pkg + name: open(os.path.join(root, name), "rb").read()
    for name in sorted(os.listdir(root))
    if name.endswith(".class")
}
if not any(name == pkg + target + ".class" or name.startswith(pkg + target + "$") for name in new):
    raise SystemExit("no %s class files were produced" % target)
replaced, added, dropped = [], [], []
tmp = jar + ".tmp"
with zipfile.ZipFile(jar) as src, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as dst:
    for item in src.infolist():
        n = item.filename
        if n in new:
            dst.writestr(item, new.pop(n)); replaced.append(n)
            continue
        if n.startswith(pkg + target) and n.endswith(".class"):
            dropped.append(n)
            continue
        dst.writestr(item, src.read(n))
    for n, data in sorted(new.items()):
        dst.writestr(n, data); added.append(n)
shutil.move(tmp, jar)
print("replaced:", " ".join(replaced))
print("added:", " ".join(added) or "(none)")
print("dropped:", " ".join(dropped) or "(none)")
PY
if [ $? -ne 0 ]; then echo "INVALID: jar splice failed"; cat "$LOG_DIR/splice.log"; exit 2; fi
export COURSIER_CACHE="$CACHE"

(cd "$CHECKOUT" && rm -f dependencies/rocket-chip/src/main/resources/META-INF/services/firrtl.options.RegisteredLibrary && \
  rm -rf generated/Main generated/CpuEvalLfsr16 out && echo 0.11.6 > .mill-version && \
  ./mill -i rift2Core[chisel].test.runMain test.testMain) >"$LOG_DIR/elaborate.log" 2>&1
if [ $? -ne 0 ] || [ ! -f "$CHECKOUT/generated/Main/Rift2Core.sv" ]; then
  if answer_build_failure "$LOG_DIR/elaborate.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
    if grep -q '\.compile Compilation failed' "$LOG_DIR/elaborate.log"; then
      echo "FAIL_CANDIDATE_COMPILE: Rift2Core did not compile against the submitted class"; exit 1
    fi
    echo "FAIL_ELABORATION: the design with the submitted class did not elaborate"; exit 1
  fi
  echo "INVALID: elaboration environment failed"; exit 2
fi
if [ -f "$CHECKOUT/generated/Main/$TARGET_CLASS.sv" ]; then
  cp "$CHECKOUT/generated/Main/$TARGET_CLASS.sv" "$LOG_DIR/$TARGET_CLASS.sv"
fi
for extra in "$CHECKOUT/generated/Main/${TARGET_CLASS}"_*.sv; do
  [ -f "$extra" ] && cp "$extra" "$LOG_DIR/"
done

(cd "$CHECKOUT" && rm -rf generated/build/Main && mkdir -p generated/build/Main && \
  env -u VERILATOR_BIN "$VERILATOR" -Wno-fatal --timescale "1 ns / 1 ps" \
  -y "$CHECKOUT/generated/Main" -y "$CHECKOUT/tb" -y "$CHECKOUT/tb/vtb" --top-module SimTop --trace-fst \
  -CFLAGS "-I$DROMAJO_DIR/include" -LDFLAGS "-L$DROMAJO_DIR/build -ldromajo_cosim" \
  --cc "$CHECKOUT/tb/verilator/SimTop.v" +define+RANDOMIZE_GARBAGE_ASSIGN \
  +define+RANDOMIZE_INVALID_ASSIGN +define+RANDOMIZE_REG_INIT \
  +define+RANDOMIZE_MEM_INIT +define+RANDOMIZE_DELAY=0 +define+USE_POWER_PINS \
  --exe --build "$CHECKOUT/tb/verilator/sim_main.cpp" "$CHECKOUT/tb/verilator/diff.cpp" \
  -Mdir generated/build/Main -j "$VERILATOR_JOBS") >"$LOG_DIR/build.log" 2>&1
if [ $? -ne 0 ] || [ ! -x "$CHECKOUT/generated/build/Main/VSimTop" ]; then
  if answer_build_failure "$LOG_DIR/build.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
    echo "FAIL_CANDIDATE_COMPILE: Verilator build of the elaborated design failed"; exit 1
  fi
  echo "INVALID: Verilator build failed"; exit 2
fi

PROBE_SOURCE="$PROBLEM_DIR/harness/test_lfsr16.cpp"
PROBE_RTL="$CHECKOUT/generated/CpuEvalLfsr16/CpuEvalLfsr16.sv"
PROBE_BUILD="$CHECKOUT/generated/build/CpuEvalLfsr16"
rm -rf "$PROBE_BUILD"
if ! env -u VERILATOR_BIN "$VERILATOR" --cc --exe --build --top-module CpuEvalLfsr16 \
  -y "$(dirname "$PROBE_RTL")" --Mdir "$PROBE_BUILD" "$PROBE_RTL" "$PROBE_SOURCE" \
  >"$LOG_DIR/lfsr16-build.log" 2>&1; then
  if answer_build_failure "$LOG_DIR/lfsr16-build.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
    echo "FAIL_CANDIDATE_COMPILE: Verilator build of the width-16 probe failed"; exit 1
  fi
  echo "INVALID: width-16 probe build failed"; exit 2
fi
cp "$PROBE_RTL" "$LOG_DIR/"

rm -f "$LOG_DIR/cycle-limit-reached"
printf 'test\tverdict\texit_code\tobservation_markers\tlog_sha256\n' >"$LOG_DIR/results.tsv"
functional_fail=0

if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" "$TEST_IMAGE_DIR" "$TEST_NAME_PATTERN" "$HERE/../../_shared/required-test-catalog.json" >"$LOG_DIR/selected-images.txt" <<'PY'
import fnmatch, json, sys
from pathlib import Path
recipe, directory, override, catalog_path = sys.argv[1:]
images = sorted(p for p in Path(directory).iterdir() if p.is_file())
catalog = json.load(open(catalog_path))["tests"]
patterns = json.load(open(recipe))["test_programs"]["selection"]
if not patterns:
    raise SystemExit("INVALID: required test selection is empty")
def matches(pattern):
    pattern = pattern if pattern.endswith(".verilog") else pattern + ".verilog"
    return {str(p) for p in images if fnmatch.fnmatchcase(p.name, pattern)}
required = set()
for pattern in patterns:
    pattern = pattern.removesuffix(".verilog")
    names = [name for name in catalog if fnmatch.fnmatchcase(name, pattern)]
    if not names:
        raise SystemExit(f"INVALID: required test selection is absent from the fixed catalog: {pattern}")
    for name in names:
        image = Path(directory) / (name + ".verilog")
        if not image.is_file() or not (Path(directory) / name).is_file():
            raise SystemExit(f"INVALID: required executable or test image is missing: {name}")
        required.add(str(image))
selected = matches(override) if override else required
if not required.issubset(selected):
    raise SystemExit("INVALID: selected images omit required tests")
for image in sorted(selected):
    print(image)
PY
then
  exit 2
fi
mapfile -t IMAGES <"$LOG_DIR/selected-images.txt"


run_one_test() {
  local image="$1" name log short_id test_id short_root
  name="$(basename "$image" .verilog)"
  log="$LOG_DIR/run_${name}.log"
  short_id="$(printf '%s' "$EVAL_ROOT" | cksum | cut -d' ' -f1)"
  test_id="$(printf '%s' "$name" | cksum | cut -d' ' -f1)"
  if [ -n "${SHORT_TEST_DIR:-}" ]; then
    short_root="$SHORT_TEST_DIR/$short_id-$test_id"
  else
    short_root="/tmp/r2c-$short_id-$test_id"
  fi
  mkdir -p "$short_root"
  ln -sf "$TEST_IMAGE_DIR/$name" "$short_root/i"
  ln -sf "$image" "$short_root/i.verilog"
  run_program_once "$LOG_DIR" "$log" "$CHECKOUT" timeout "$TIMEOUT_SEC" ./generated/build/Main/VSimTop -l -d -f "$short_root/i"
}

classify_one_test() {
  local image="$1" required_marker="${2:-}" name log code markers verdict
  name="$(basename "$image" .verilog)"
  log="$LOG_DIR/run_${name}.log"
  code="$(cat "${log}.exit" 2>/dev/null || echo -1)"
  markers="$(grep -c 'CPU_EVAL_OBSERVATION_MISMATCH' "$log" 2>/dev/null)"
  verdict="$(program_verdict "$log" "$code" "$required_marker")"
  case "$verdict" in PASS|NOT_RUN|INVALID) ;; *) functional_fail=1 ;; esac
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$verdict" "$code" "$markers" "$(sha256sum "$log" | cut -d' ' -f1)" >>"$LOG_DIR/results.tsv"
}

if [ "$STOP_AFTER_FUNCTIONAL_FAIL" = 1 ]; then

  for image in "${IMAGES[@]}"; do
    run_one_test "$image"
    classify_one_test "$image"
    if [ "$functional_fail" -eq 1 ]; then break; fi
  done
else
  TEST_PARALLELISM="${TEST_PARALLELISM:-8}"
  running=0
  test_pids=()
  for image in "${IMAGES[@]}"; do
    run_one_test "$image" &
    test_pids+=("$!")
    running=$((running + 1))
    if [ "$running" -ge "$TEST_PARALLELISM" ]; then
      wait -n
      running=$((running - 1))
    fi
  done
  # The tee subprocesses wait for this script to close stdout and stderr.

  for pid in "${test_pids[@]}"; do
    wait "$pid" 2>/dev/null
  done
  for image in "${IMAGES[@]}"; do
    classify_one_test "$image"
  done
fi

probe_log="$LOG_DIR/run_lfsr16-ports.log"
probe_exit=0
timeout "$TIMEOUT_SEC" "$PROBE_BUILD/VCpuEvalLfsr16" >"$probe_log" 2>&1 || probe_exit=$?
echo "$probe_exit" >"${probe_log}.exit"
classify_one_test lfsr16-ports.verilog CPU_EVAL_LFSR16_COMPLETE
sha256sum "$CANDIDATE" "$PROBLEM_DIR/TEST_RECIPE.json" "$LOG_DIR/results.tsv" \
  "$CACHE/$CHISEL_JAR" "$PROBE_SOURCE" "$LOG_DIR/CpuEvalLfsr16.sv" >"$LOG_DIR/files.sha256"
run_verdict "$LOG_DIR/results.tsv"
exit $?
