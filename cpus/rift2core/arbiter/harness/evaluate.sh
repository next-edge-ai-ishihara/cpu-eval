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
SHARED="$HERE/../../_shared"
source "$SHARED/program_verdict.sh"

readarray -t META < <(python3 - "$PROBLEM_DIR/TEST_RECIPE.json" <<'PY'
import json, sys
x = json.load(open(sys.argv[1]))
r = x["candidate_replacement"]
print(r["source_unit"])
print(r["path"])
print(r["revision"])
print(r["pristine_source_sha256"])
print(x["cpu_source"]["revision"])
PY
)
TARGET_CLASS="${META[0]}"
LIBRARY_PATH="${META[1]}"
EXPECTED_CHISEL="${META[2]}"
EXPECTED_PRISTINE_SHA="${META[3]}"
EXPECTED_RIFT="${META[4]}"

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
if [ -z "${ARBITER_PRISTINE:-}" ]; then echo "INVALID: set ARBITER_PRISTINE to the pinned Arbiter.scala source" >&2; exit 2; fi
if [ -z "${ARBITER_SHIM_TEMPLATE:-}" ]; then echo "INVALID: set ARBITER_SHIM_TEMPLATE to the prepared Mill shim template" >&2; exit 2; fi
if [ -z "${ARBITER_CACHE_TEMPLATE:-}" ]; then echo "INVALID: set ARBITER_CACHE_TEMPLATE to the pristine Chisel Coursier cache" >&2; exit 2; fi
CHISEL_JAR_REL="https/repo1.maven.org/maven2/org/chipsalliance/chisel_2.13/5.1.0/chisel_2.13-5.1.0.jar"

PATCH="$HERE/../../environment/rift2core-chisel5-compatibility.patch"
CHECKOUT="$EVAL_ROOT/checkout"
RUN_ID="$(date -u +%Y-%m-%dT%H%M%SZ)_${TARGET_CLASS}_$(basename "$CANDIDATE" .scala)"
LOG_DIR="$EVAL_ROOT/runs/$RUN_ID"
mkdir -p "$LOG_DIR" "$EVAL_ROOT"
exec > >(tee "$LOG_DIR/evaluate.stdout.log") 2> >(tee "$LOG_DIR/evaluate.stderr.log" >&2)
echo "[evaluate] candidate: $CANDIDATE"
echo "[evaluate] candidate sha256: $(sha256sum "$CANDIDATE" | cut -d' ' -f1)"

for path in "$REPO/.git" "$DROMAJO_DIR/build/libdromajo_cosim.a" "$VERILATOR" \
  "$MILLW" "$JAVA_HOME/bin/java" "$JAVA_HOME/bin/jar" "$FIRTOOL_DIR/firtool" \
  "$PATCH" "$TEST_IMAGE_DIR" "$ARBITER_PRISTINE" "$ARBITER_SHIM_TEMPLATE/build.sc" \
  "$ARBITER_CACHE_TEMPLATE/$CHISEL_JAR_REL" "$SHARED/replace_class.py"; do
  if [ ! -e "$path" ]; then echo "missing dependency: $path" >&2; exit 2; fi
done
if [ "$(sha256sum "$ARBITER_PRISTINE" | cut -d' ' -f1)" != "$EXPECTED_PRISTINE_SHA" ]; then
  echo "pinned $LIBRARY_PATH (chisel $EXPECTED_CHISEL) has an unexpected hash" >&2; exit 2
fi
if [ "$(git -c safe.directory="$REPO" -C "$REPO" rev-parse HEAD)" != "$EXPECTED_RIFT" ]; then
  echo "source revision mismatch" >&2; exit 2
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$FIRTOOL_DIR:$(dirname "$VERILATOR"):$PATH"

exec 9>"$EVAL_ROOT/checkout.lock"
flock 9

SHIM="$EVAL_ROOT/shim"
rm -rf "$SHIM"
mkdir -p "$SHIM"
rsync -a --exclude out --exclude 'mill.*' "$ARBITER_SHIM_TEMPLATE/" "$SHIM/"
python3 "$SHARED/replace_class.py" --class-name "$TARGET_CLASS" \
  --source "$ARBITER_PRISTINE" --candidate "$CANDIDATE" \
  --output "$SHIM/shim/src/Arbiter.scala" \
  --region-output "$LOG_DIR/candidate-region.json"
replacement_status=$?
if [ "$replacement_status" -eq 3 ]; then
  echo "FAIL_CANDIDATE_DEFINITION: invalid submitted class declaration"
  exit 1
elif [ "$replacement_status" -ne 0 ]; then
  echo "INVALID: the fixed source could not take the submitted class"; exit 2
fi
CLASSES="$SHIM/out/shim/compile.dest/classes"
(cd "$SHIM" && env -u COURSIER_CACHE ./mill -i shim.compile) >"$LOG_DIR/shim-compile.log" 2>&1
compile_rc=$?
if [ "$compile_rc" -ne 0 ] || [ ! -f "$CLASSES/chisel3/util/Arbiter.class" ]; then
  if answer_build_failure "$LOG_DIR/shim-compile.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
    echo "FAIL_CANDIDATE_COMPILE: submitted source did not compile"; exit 1
  fi
  echo "INVALID: Arbiter compile environment failed"; exit 2
fi

CACHE="$EVAL_ROOT/coursier-cache"
rm -rf "$CACHE"
rsync -a "$ARBITER_CACHE_TEMPLATE/" "$CACHE/"
(cd "$CLASSES" && "$JAVA_HOME/bin/jar" uvf "$CACHE/$CHISEL_JAR_REL" chisel3) >"$LOG_DIR/jar-splice.log" 2>&1
if [ $? -ne 0 ]; then echo "INVALID: jar splice failed"; exit 2; fi
sha256sum "$CACHE/$CHISEL_JAR_REL" >"$LOG_DIR/spliced-jar.sha256"
export COURSIER_CACHE="$CACHE"

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

(cd "$CHECKOUT" && rm -f dependencies/rocket-chip/src/main/resources/META-INF/services/firrtl.options.RegisteredLibrary && \
  rm -rf generated/Main out && echo 0.11.6 > .mill-version && \
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

rm -f "$LOG_DIR/cycle-limit-reached"
printf 'test\tverdict\texit_code\tlog_sha256\n' >"$LOG_DIR/results.tsv"
functional_fail=0

if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" "$TEST_IMAGE_DIR" "$TEST_NAME_PATTERN" "$SHARED/required-test-catalog.json" >"$LOG_DIR/selected-images.txt" <<'PY'
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
count="${#IMAGES[@]}"
if [ "$count" -eq 0 ]; then echo "INVALID: no test images"; exit 2; fi


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
  local image="$1" name log code verdict
  name="$(basename "$image" .verilog)"
  log="$LOG_DIR/run_${name}.log"
  code="$(cat "${log}.exit" 2>/dev/null || echo -1)"
  verdict="$(program_verdict "$log" "$code")"
  case "$verdict" in PASS|NOT_RUN|INVALID) ;; *) functional_fail=1 ;; esac
  printf '%s\t%s\t%s\t%s\n' "$name" "$verdict" "$code" "$(sha256sum "$log" 2>/dev/null | cut -d' ' -f1)" >>"$LOG_DIR/results.tsv"
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
sha256sum "$CANDIDATE" "$PROBLEM_DIR/TEST_RECIPE.json" "$LOG_DIR/results.tsv" >"$LOG_DIR/files.sha256"
run_verdict "$LOG_DIR/results.tsv"
exit $?
