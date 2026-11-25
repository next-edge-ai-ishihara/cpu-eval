#!/usr/bin/env bash

set -uo pipefail

CANDIDATE="${1:-}"
if [ -z "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <candidate Queue class .scala>" >&2
  exit 2
fi
if [ ! -f "$CANDIDATE" ]; then
  echo "evaluate.sh: candidate file not found: $CANDIDATE" >&2
  exit 2
fi
CANDIDATE="$(cd "$(dirname "$CANDIDATE")" && pwd)/$(basename "$CANDIDATE")"

HERE="$(cd "$(dirname "$0")" && pwd)"
PROBLEM_DIR="$(cd "$HERE/.." && pwd)"
source "$PROBLEM_DIR/../_shared/program_verdict.sh"

REPO="${REPO:?Set REPO to the pinned Rift2Core checkout}"
DROMAJO_DIR="${DROMAJO_DIR:?Set DROMAJO_DIR to the built Dromajo directory}"
VERILATOR="${VERILATOR:?Set VERILATOR to the Verilator executable}"
MILLW="${MILLW:?Set MILLW to the Mill wrapper executable}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
FIRTOOL_DIR="${FIRTOOL_DIR:?Set FIRTOOL_DIR to the directory containing firtool}"
TEST_IMAGE_DIR="${TEST_IMAGE_DIR:?Set TEST_IMAGE_DIR to the fixed ELF and memory initialization files}"


if [ -z "${PRISTINE_COURSIER_CACHE:-}" ]; then echo "INVALID: set PRISTINE_COURSIER_CACHE to the pristine Chisel Coursier cache" >&2; exit 2; fi
CHISEL_JAR_REL="https/repo1.maven.org/maven2/org/chipsalliance/chisel_2.13/5.1.0/chisel_2.13-5.1.0.jar"
if [ -z "${EVAL_ROOT:-}" ]; then echo "INVALID: set EVAL_ROOT to a writable private evaluation directory" >&2; exit 2; fi
TIMEOUT_SEC="${TIMEOUT_SEC:-600}"
VERILATOR_JOBS="${VERILATOR_JOBS:-8}"
TEST_NAME_PATTERN="${TEST_NAME_PATTERN:-}"
ENV_PATCH="$PROBLEM_DIR/../environment/rift2core-chisel5-compatibility.patch"
TEMPLATE="$HERE/chisel_5.1.0_Decoupled.scala"
EXPECTED_RIFT=64b660fb70e0cab491049bdeea87c27936dcbf1e
EXPECTED_TEMPLATE_SHA=66da7df128db5aed5fb98cf90de7fcc0429524f54156e29cc49f78eb0a5d4541

for path in "$REPO/.git" "$DROMAJO_DIR/build/libdromajo_cosim.a" "$VERILATOR" \
    "$MILLW" "$JAVA_HOME/bin/java" "$FIRTOOL_DIR/firtool" "$ENV_PATCH" \
    "$TEST_IMAGE_DIR" "$TEMPLATE" "$HERE/splice_queue.py" \
    "$PRISTINE_COURSIER_CACHE/$CHISEL_JAR_REL"; do
  if [ ! -e "$path" ]; then
    echo "evaluate.sh: required dependency missing: $path" >&2
    exit 2
  fi
done
if [ "$(sha256sum "$TEMPLATE" | cut -d' ' -f1)" != "$EXPECTED_TEMPLATE_SHA" ]; then
  echo "evaluate.sh: Decoupled.scala template has an unexpected SHA-256" >&2
  exit 2
fi
if [ "$(git -c safe.directory="$REPO" -C "$REPO" rev-parse HEAD)" != "$EXPECTED_RIFT" ]; then
  echo "evaluate.sh: Rift2Core source revision mismatch" >&2
  exit 2
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$FIRTOOL_DIR:$(dirname "$VERILATOR"):$PATH"

TAG="$(basename "$CANDIDATE" .scala)"
RUN_ID="$(date -u +%Y-%m-%dT%H%M%SZ)_Queue_${TAG}"
LOG_DIR="$EVAL_ROOT/runs/$RUN_ID"
CHECKOUT="$EVAL_ROOT/checkout"
SHIM="$EVAL_ROOT/shim"
CACHE="$EVAL_ROOT/coursier-cache"
mkdir -p "$LOG_DIR" "$EVAL_ROOT"
exec > >(tee "$LOG_DIR/evaluate.stdout.log") 2> >(tee "$LOG_DIR/evaluate.stderr.log" >&2)

echo "[evaluate] candidate: $CANDIDATE"
echo "[evaluate] candidate sha256: $(sha256sum "$CANDIDATE" | cut -d' ' -f1)"
echo "[evaluate] run directory: $LOG_DIR"
echo "[provenance] Rift2Core: $REPO ($EXPECTED_RIFT)"
echo "[provenance] Chisel library source: chipsalliance/chisel 066fb4705472e07bde340810ee45eaf8c1ad9438 (v5.1.0), src/main/scala/chisel3/util/Decoupled.scala"

# One evaluation at a time per $EVAL_ROOT: the checkout, the shim module and
# the patched cache are all shared within a root.  Concurrent evaluations must
# use different EVAL_ROOT values.
exec 9>"$EVAL_ROOT/checkout.lock"
flock 9

# Validate the complete trial set before compiling the candidate or CPU.
# The shared evaluator uses the same catalog-and-recipe selection rule.
if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" "$TEST_IMAGE_DIR" "$TEST_NAME_PATTERN" "$PROBLEM_DIR/../_shared/required-test-catalog.json" >"$LOG_DIR/selected-images.txt" <<'PY'
import fnmatch, json, sys
from pathlib import Path
recipe, directory, override, catalog_path = sys.argv[1:]
images = sorted(p for p in Path(directory).iterdir() if p.is_file())
catalog = json.load(open(catalog_path))["tests"]
programs = json.load(open(recipe))["test_programs"]
patterns = programs["selection"]
if not patterns:
    raise SystemExit("INVALID: required test selection is empty")
if not all(isinstance(name, str) and name for name in catalog) or len(set(catalog)) != len(catalog):
    raise SystemExit("INVALID: fixed test catalog contains invalid or duplicate names")
required_names = set()
for pattern in patterns:
    pattern = pattern.removesuffix(".verilog")
    names = {name for name in catalog if fnmatch.fnmatchcase(name, pattern)}
    if not names:
        raise SystemExit(f"INVALID: required test selection is absent from the fixed catalog: {pattern}")
    required_names.update(names)
if len(required_names) != programs["resolved_program_count"]:
    raise SystemExit("INVALID: fixed catalog does not provide the required program count")
required = {str(Path(directory) / (name + ".verilog")) for name in required_names}
if override:
    pattern = override if override.endswith(".verilog") else override + ".verilog"
    selected = {str(p) for p in images if fnmatch.fnmatchcase(p.name, pattern)}
else:
    selected = required
if not required.issubset(selected):
    raise SystemExit("INVALID: selected images omit required tests")
for image in sorted(selected):
    path = Path(image)
    if not path.is_file() or not path.with_suffix("").is_file():
        raise SystemExit(f"INVALID: required executable or test image is missing: {path.stem}")
    print(image)
PY
then
  exit 2
fi
mapfile -t IMAGES <"$LOG_DIR/selected-images.txt"

mkdir -p "$SHIM/shim/src"
python3 "$HERE/splice_queue.py" --template "$TEMPLATE" \
  --candidate "$CANDIDATE" --output "$SHIM/shim/src/Decoupled.scala" \
  --region-output "$LOG_DIR/candidate-region.json" \
  > "$LOG_DIR/splice.log" 2>&1
splice_status=$?
if [ "$splice_status" -ne 0 ]; then
  cat "$LOG_DIR/splice.log" >&2
  if [ "$splice_status" -eq 3 ]; then
    echo "FAIL_CANDIDATE_DEFINITION: invalid submitted class declaration"; exit 1
  fi
  echo "[evaluate] INVALID -- the fixed Decoupled.scala template could not take the submitted class." >&2
  exit 2
fi
cat "$LOG_DIR/splice.log"
cp "$SHIM/shim/src/Decoupled.scala" "$LOG_DIR/Decoupled.spliced.scala"

cat > "$SHIM/build.sc" <<'BUILD'
import mill._, scalalib._

object shim extends ScalaModule {
  def scalaVersion = "2.13.10"
  def ivyDeps = Agg(ivy"org.chipsalliance::chisel:5.1.0")
  def scalacPluginIvyDeps = Agg(ivy"org.chipsalliance:::chisel-plugin:5.1.0")
}
BUILD
echo 0.11.6 > "$SHIM/.mill-version"
cp "$MILLW" "$SHIM/mill" && chmod +x "$SHIM/mill"

rm -rf "$CACHE"
rsync -a "$PRISTINE_COURSIER_CACHE/" "$CACHE/"

( cd "$SHIM" && rm -rf out && COURSIER_CACHE="$CACHE" ./mill -i shim.compile ) \
  > "$LOG_DIR/shim_compile.log" 2>&1
compile_rc=$?
if [ "$compile_rc" -ne 0 ] || [ ! -f "$SHIM/out/shim/compile.dest/classes/chisel3/util/Queue.class" ]; then
  if answer_build_failure "$LOG_DIR/shim_compile.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" Queue; then
    echo "FAIL_CANDIDATE_COMPILE: submitted source did not compile"; exit 1
  fi
  echo "[evaluate] INVALID -- the Queue compile environment failed (see $LOG_DIR/shim_compile.log)." >&2
  exit 2
fi

JAR="$CACHE/$CHISEL_JAR_REL"
CLASSES="$SHIM/out/shim/compile.dest/classes"
( cd "$CLASSES" && jar uf "$JAR" $(cd "$CLASSES" && find chisel3 -name '*.class' -printf '%p ') ) \
  > "$LOG_DIR/jar_patch.log" 2>&1
if [ $? -ne 0 ]; then
  cat "$LOG_DIR/jar_patch.log" >&2
  echo "[evaluate] INVALID -- could not patch the private chisel jar. Not a functional FAIL." >&2
  exit 2
fi
echo "[evaluate] patched $(cd "$CLASSES" && find chisel3 -name '*.class' | wc -l) class files into $JAR"


rm -f "$JAR.sha1" "$JAR.md5" "$JAR.checked" "$JAR.aux"

if [ ! -d "$CHECKOUT/.git" ]; then
  mkdir -p "$CHECKOUT"
  rsync -a --exclude generated/build --exclude out --exclude target "$REPO/" "$CHECKOUT/"
fi
if [ "$(git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" rev-parse HEAD)" != "$EXPECTED_RIFT" ]; then
  echo "evaluate.sh: evaluation checkout revision mismatch" >&2
  exit 2
fi
git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" restore -- .
git -c safe.directory="$CHECKOUT/dependencies/constellation" -C "$CHECKOUT/dependencies/constellation" restore -- .
git -c safe.directory="$CHECKOUT/dependencies/rocket-chip" -C "$CHECKOUT/dependencies/rocket-chip" restore -- .
sed -i 's/\r$//' "$CHECKOUT/tb/verilator/diff.cpp"
if ! git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply --check "$ENV_PATCH"; then
  echo "evaluate.sh: fixed environment patch does not apply to the pinned revision" >&2
  exit 2
fi
git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply "$ENV_PATCH"
while IFS=$'\t' read -r relative_patch expected_hash; do
  [ -n "$relative_patch" ] || continue
  test_patch="$PROBLEM_DIR/$relative_patch"
  if [ ! -f "$test_patch" ] || [ "$(sha256sum "$test_patch" | cut -d' ' -f1)" != "$expected_hash" ]; then
    echo "evaluate.sh: fixed test patch is missing or has an unexpected hash: $relative_patch" >&2
    exit 2
  fi
  if ! git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply --ignore-space-change --check "$test_patch"; then
    echo "evaluate.sh: fixed test patch does not apply: $relative_patch" >&2
    exit 2
  fi
  git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" apply --ignore-space-change "$test_patch"
  echo "[evaluate] applied fixed test patch: $relative_patch"
done < <(python3 - "$PROBLEM_DIR/TEST_RECIPE.json" <<'PY'
import json, sys
for patch in json.load(open(sys.argv[1])).get("fixed_test_patches", []):
    print(f'{patch["path"]}\t{patch["sha256"]}')
PY
)
cp "$MILLW" "$CHECKOUT/mill" && chmod +x "$CHECKOUT/mill"

( cd "$CHECKOUT" && \
  rm -f dependencies/rocket-chip/src/main/resources/META-INF/services/firrtl.options.RegisteredLibrary && \
  rm -rf generated/Main generated/CpuEvalQueue3 out && echo 0.11.6 > .mill-version && \
  COURSIER_CACHE="$CACHE" ./mill -i rift2Core[chisel].test.runMain test.testMain ) \
  > "$LOG_DIR/elaborate.log" 2>&1
if [ $? -ne 0 ] || [ ! -f "$CHECKOUT/generated/Main/Rift2Core.sv" ]; then
  if answer_build_failure "$LOG_DIR/elaborate.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" Queue; then
    if grep -q '\.compile Compilation failed' "$LOG_DIR/elaborate.log"; then
      echo "FAIL_CANDIDATE_COMPILE: Rift2Core did not compile against the submitted class"; exit 1
    fi
    echo "FAIL_ELABORATION: the design with the submitted class did not elaborate"; exit 1
  fi
  echo "[evaluate] INVALID -- the Chisel/CIRCT elaboration environment failed (see $LOG_DIR/elaborate.log)." >&2
  exit 2
fi

# VERILATOR_BIN collides with a wrapper-internal variable name and causes
# infinite self-recursion if inherited; unset it explicitly.
( cd "$CHECKOUT" && rm -rf generated/build/Main && mkdir -p generated/build/Main && \
  env -u VERILATOR_BIN "$VERILATOR" -Wno-fatal --timescale "1 ns / 1 ps" \
  -y "$CHECKOUT/generated/Main" -y "$CHECKOUT/tb" -y "$CHECKOUT/tb/vtb" --top-module SimTop --trace-fst \
  -CFLAGS "-I$DROMAJO_DIR/include" -LDFLAGS "-L$DROMAJO_DIR/build -ldromajo_cosim" \
  --cc "$CHECKOUT/tb/verilator/SimTop.v" +define+RANDOMIZE_GARBAGE_ASSIGN \
  +define+RANDOMIZE_INVALID_ASSIGN +define+RANDOMIZE_REG_INIT \
  +define+RANDOMIZE_MEM_INIT +define+RANDOMIZE_DELAY=0 +define+USE_POWER_PINS \
  --exe --build "$CHECKOUT/tb/verilator/sim_main.cpp" "$CHECKOUT/tb/verilator/diff.cpp" \
  -Mdir generated/build/Main -j "$VERILATOR_JOBS" ) > "$LOG_DIR/build.log" 2>&1
if [ $? -ne 0 ] || [ ! -x "$CHECKOUT/generated/build/Main/VSimTop" ]; then
  if answer_build_failure "$LOG_DIR/build.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" Queue; then
    echo "FAIL_CANDIDATE_COMPILE: Verilator build of the elaborated design failed"; exit 1
  fi
  echo "[evaluate] INVALID -- Verilator/g++ build environment failed (see $LOG_DIR/build.log)." >&2
  exit 2
fi

PROBE_SOURCE="$PROBLEM_DIR/harness/test_queue3.cpp"
PROBE_RTL="$CHECKOUT/generated/CpuEvalQueue3/CpuEvalQueue3.sv"
PROBE_BUILD="$CHECKOUT/generated/build/CpuEvalQueue3"
rm -rf "$PROBE_BUILD"
if ! env -u VERILATOR_BIN "$VERILATOR" --cc --exe --build --top-module CpuEvalQueue3 \
  -y "$(dirname "$PROBE_RTL")" --Mdir "$PROBE_BUILD" "$PROBE_RTL" "$PROBE_SOURCE" \
  > "$LOG_DIR/queue3-build.log" 2>&1; then
  if answer_build_failure "$LOG_DIR/queue3-build.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" Queue; then
    echo "FAIL_CANDIDATE_COMPILE: Verilator build of the three-entry flow Queue probe failed"; exit 1
  fi
  echo "INVALID: three-entry flow Queue probe build failed"
  exit 2
fi
cp "$PROBE_RTL" "$LOG_DIR/"

rm -f "$LOG_DIR/cycle-limit-reached"
printf 'test\tverdict\texit_code\tlog_sha256\n' > "$LOG_DIR/results.tsv"
# sim_main.cpp copies "+<path>.verilog" into a fixed 64-byte buffer, so the
# image paths handed to the simulator must stay short.

run_one_test() {
  local image="$1" name log short_id test_id short_root
  name="$(basename "$image" .verilog)"
  log="$LOG_DIR/run_${name}.log"
  short_id="$(printf '%s' "$EVAL_ROOT" | cksum | cut -d' ' -f1)"
  test_id="$(printf '%s' "$name" | cksum | cut -d' ' -f1)"
  if [ -n "${SHORT_TEST_DIR:-}" ]; then
    short_root="$SHORT_TEST_DIR/$short_id-$test_id"
  else
    short_root="/tmp/r2q-$short_id-$test_id"
  fi
  mkdir -p "$short_root"
  ln -sf "$TEST_IMAGE_DIR/$name" "$short_root/i"
  ln -sf "$image" "$short_root/i.verilog"
  run_program_once "$LOG_DIR" "$log" "$CHECKOUT" timeout "$TIMEOUT_SEC" ./generated/build/Main/VSimTop -l -d -f "$short_root/i"
}

classify_one_test() {
  local image="$1" required_marker="${2:-}" name log code verdict
  name="$(basename "$image" .verilog)"
  log="$LOG_DIR/run_${name}.log"
  code="$(cat "${log}.exit" 2>/dev/null || echo -1)"
  verdict="$(program_verdict "$log" "$code" "$required_marker")"
  printf '%s\t%s\t%s\t%s\n' "$name" "$verdict" "$code" \
    "$(sha256sum "$log" 2>/dev/null | cut -d' ' -f1)" >> "$LOG_DIR/results.tsv"
  echo "[evaluate] $name : $verdict"
}

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
probe_log="$LOG_DIR/run_queue3-ports.log"
probe_exit=0
timeout "$TIMEOUT_SEC" "$PROBE_BUILD/VCpuEvalQueue3" > "$probe_log" 2>&1 || probe_exit=$?
echo "$probe_exit" > "${probe_log}.exit"
classify_one_test queue3-ports.verilog CPU_EVAL_QUEUE3_COMPLETE
sha256sum "$CANDIDATE" "$PROBLEM_DIR/TEST_RECIPE.json" "$LOG_DIR/results.tsv" \
  "$JAR" "$PROBE_SOURCE" "$LOG_DIR/CpuEvalQueue3.sv" > "$LOG_DIR/files.sha256"

run_verdict "$LOG_DIR/results.tsv"
exit $?
