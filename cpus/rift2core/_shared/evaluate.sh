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
source "$HERE/program_verdict.sh"

readarray -t META < <(python3 - "$PROBLEM_DIR/TEST_RECIPE.json" <<'PY'
import json, sys
x=json.load(open(sys.argv[1]))
r=x["candidate_replacement"]
print(r["source_unit"])
print(r["path"])
print(r["revision"])
PY
)
TARGET_CLASS="${META[0]}"
TARGET_PATH="${META[1]}"
EXPECTED_RIFT="${META[2]}"

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
PATCH="$HERE/../environment/rift2core-chisel5-compatibility.patch"
CHECKOUT="$EVAL_ROOT/checkout"
RUN_ID="$(date -u +%Y-%m-%dT%H%M%SZ)_${TARGET_CLASS}_$(basename "$CANDIDATE" .scala)"
LOG_DIR="$EVAL_ROOT/runs/$RUN_ID"
mkdir -p "$LOG_DIR" "$EVAL_ROOT"
exec > >(tee "$LOG_DIR/evaluate.stdout.log") 2> >(tee "$LOG_DIR/evaluate.stderr.log" >&2)

REQUIRED_OBSERVATION_MARKERS_FILE="$LOG_DIR/required-observation-markers.tsv"
if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" >"$REQUIRED_OBSERVATION_MARKERS_FILE" <<'PY'
import json, re, sys
markers = json.load(open(sys.argv[1])).get("required_observation_markers", {})
if not isinstance(markers, dict):
    raise ValueError("required_observation_markers must map test names to literal output lines")
for name, marker in markers.items():
    if (not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", name)
            or not isinstance(marker, str) or not marker.strip()
            or any(char in marker for char in "\r\n\t\0")):
        raise ValueError("invalid required observation marker")
    print(name + "\t" + marker)
PY
then
  echo "INVALID: required observation-marker recipe could not be decoded"
  exit 2
fi

for path in "$REPO/.git" "$DROMAJO_DIR/build/libdromajo_cosim.a" "$VERILATOR" \
  "$MILLW" "$JAVA_HOME/bin/java" "$FIRTOOL_DIR/firtool" "$PATCH" "$TEST_IMAGE_DIR"; do
  if [ ! -e "$path" ]; then echo "missing dependency: $path" >&2; exit 2; fi
done
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
# The pinned testbench uses CRLF line endings.
sed -i 's/\r$//' "$CHECKOUT/tb/verilator/diff.cpp"
if [ "${DROMAJO_RIFT_ACLINT_MAP:-0}" = 1 ]; then
  diff_cpp="$CHECKOUT/tb/verilator/diff.cpp"
  test "$(grep -c 'char \* temp\[6\];' "$diff_cpp")" -eq 1
  test "$(grep -c 'temp\[5\] = img;' "$diff_cpp")" -eq 1
  test "$(grep -c 'virt_machine_main(6,  argv_temp )' "$diff_cpp")" -eq 1
  sed -i 's/char \* temp\[6\];/char * temp[8];/' "$diff_cpp"
  sed -i '/temp\[4\] = "0x020000:0x3fffffff";/a\	temp[5] = "--clint";\n\ttemp[6] = "0x1c000:0x10000";' "$diff_cpp"
  sed -i 's/temp\[5\] = img;/temp[7] = img;/' "$diff_cpp"
  sed -i 's/virt_machine_main(6,  argv_temp )/virt_machine_main(8,  argv_temp )/' "$diff_cpp"
fi
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
readarray -t HIDE_ARGS < <(python3 - "$PROBLEM_DIR/TEST_RECIPE.json" <<'PY'
import json, sys
for name in json.load(open(sys.argv[1]))["candidate_replacement"].get("hidden_definitions", []):
    print("--hide"); print(name)
PY
)
python3 "$HERE/replace_class.py" --class-name "$TARGET_CLASS" \
  --source "$CHECKOUT/$TARGET_PATH" --candidate "$CANDIDATE" \
  --output "$CHECKOUT/$TARGET_PATH" \
  --region-output "$LOG_DIR/candidate-region.json" --hide-root "$CHECKOUT/src" "${HIDE_ARGS[@]}"
replacement_status=$?
if [ "$replacement_status" -eq 3 ]; then
  echo "FAIL_CANDIDATE_DEFINITION: invalid submitted class declaration"
  exit 1
elif [ "$replacement_status" -ne 0 ]; then
  echo "INVALID: the fixed source could not take the submitted class"; exit 2
fi

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$FIRTOOL_DIR:$(dirname "$VERILATOR"):$PATH"
(cd "$CHECKOUT" && rm -f dependencies/rocket-chip/src/main/resources/META-INF/services/firrtl.options.RegisteredLibrary && \
  # Mill's compiled classes are not removed by git restore.

  rm -rf generated/Main out && echo 0.11.6 > .mill-version && \
  ./mill -i rift2Core[chisel].test.runMain test.testMain) >"$LOG_DIR/elaborate.log" 2>&1
elaboration_status=$?
if [ "$elaboration_status" -ne 0 ] || [ ! -f "$CHECKOUT/generated/Main/Rift2Core.sv" ]; then
  if answer_build_failure "$LOG_DIR/elaborate.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
    if grep -q '\.compile Compilation failed' "$LOG_DIR/elaborate.log"; then
      cp "$LOG_DIR/elaborate.log" "$LOG_DIR/candidate-compile-error.txt" || exit 2
      echo "FAIL_CANDIDATE_COMPILE: submitted source did not compile"; exit 1
    fi
    cp "$LOG_DIR/elaborate.log" "$LOG_DIR/candidate-elaboration-error.txt" || exit 2
    echo "FAIL_ELABORATION: the design with the submitted class did not elaborate"; exit 1
  fi
  echo "INVALID: elaboration environment failed"; exit 2
fi

if ! python3 - "$PROBLEM_DIR" >"$LOG_DIR/directed-public-output-test.tsv" <<'PY'
import hashlib, json, re, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
test = json.load(open(root / "TEST_RECIPE.json")).get("directed_public_output_test")
if test is not None:
    source = (root / test["source"]).resolve()
    if (not source.is_relative_to(root) or not source.is_file()
            or hashlib.sha256(source.read_bytes()).hexdigest() != test["source_sha256"]):
        raise SystemExit("INVALID: directed public-output test source is missing or has an unexpected hash")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", test["top_module"]):
        raise SystemExit("INVALID: invalid directed public-output test top module")
    print(test["top_module"] + "\t" + str(source))
PY
then
  exit 2
fi
IFS=$'\t' read -r PUBLIC_TOP PUBLIC_TEST_CPP <"$LOG_DIR/directed-public-output-test.tsv" || true
if [ -n "${PUBLIC_TOP:-}" ]; then
  if [ ! -f "$CHECKOUT/generated/Main/$PUBLIC_TOP.sv" ]; then
    echo "FAIL_ELABORATION: the design with the submitted class did not elaborate $PUBLIC_TOP"; exit 1
  fi
  (cd "$CHECKOUT" && rm -rf generated/build/PublicOutput && mkdir -p generated/build/PublicOutput && \
    env -u VERILATOR_BIN "$VERILATOR" -Wno-fatal --timescale "1 ns / 1 ps" \
    -y "$CHECKOUT/generated/Main" -y "$CHECKOUT/tb" -y "$CHECKOUT/tb/vtb" --top-module "$PUBLIC_TOP" \
    --cc "$CHECKOUT/generated/Main/$PUBLIC_TOP.sv" \
    --exe --build "$PUBLIC_TEST_CPP" -Mdir generated/build/PublicOutput -j "$VERILATOR_JOBS") \
    >"$LOG_DIR/public_output_build.log" 2>&1
  if [ $? -ne 0 ] || [ ! -x "$CHECKOUT/generated/build/PublicOutput/V$PUBLIC_TOP" ]; then
    if answer_build_failure "$LOG_DIR/public_output_build.log" "$LOG_DIR/candidate-region.json" "$CANDIDATE" "$TARGET_CLASS"; then
      echo "FAIL_CANDIDATE_COMPILE: Verilator build of the elaborated $PUBLIC_TOP failed"; exit 1
    fi
    echo "INVALID: public-output test build failed"; exit 2
  fi
  timeout "$TIMEOUT_SEC" "$CHECKOUT/generated/build/PublicOutput/V$PUBLIC_TOP" >"$LOG_DIR/public_output_test.log" 2>&1
  public_test_status=$?
  cat "$LOG_DIR/public_output_test.log"
  if [ "$(program_verdict "$LOG_DIR/public_output_test.log" "$public_test_status")" = INVALID ]; then
    echo "INVALID: public-output test was interrupted"; exit 2
  fi
  if [ "$public_test_status" -ne 0 ]; then
    echo "FAIL: public output observation mismatch"
    exit 1
  fi
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
invalid=0

if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" "$TEST_IMAGE_DIR" "$TEST_NAME_PATTERN" "$HERE/required-test-catalog.json" >"$LOG_DIR/selected-images.txt" <<'PY'
import fnmatch, json, sys
from pathlib import Path
recipe, directory, override, catalog_path = sys.argv[1:]
images = sorted(p for p in Path(directory).iterdir() if p.is_file())
catalog = json.load(open(catalog_path))["tests"]
programs = json.load(open(recipe))["test_programs"]
patterns = programs.get("image_selection", programs["selection"])
if not patterns:
    raise SystemExit("INVALID: required test selection is empty")
def matches(pattern):
    pattern = pattern if pattern.endswith(".verilog") else pattern + ".verilog"
    return {str(p) for p in images if fnmatch.fnmatchcase(p.name, pattern)}
required = set()
for pattern in patterns:
    pattern = pattern.removesuffix(".verilog")
    available = catalog if "image_selection" not in programs else [p.stem for p in images if p.suffix == ".verilog"]
    names = [name for name in available if fnmatch.fnmatchcase(name, pattern)]
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
if ! python3 - "$PROBLEM_DIR" "$LOG_DIR/selected-images.txt" >"$LOG_DIR/directed-functional-tests.tsv" <<'PY'
import hashlib, json, re, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
names = {Path(line.strip()).stem for line in open(sys.argv[2])}
recipe = json.load(open(root / "TEST_RECIPE.json"))
names.update(test["name"] for test in recipe.get("directed_cycle_tests", []))
tests = recipe.get("directed_functional_tests", [])
if not isinstance(tests, list):
    raise SystemExit("INVALID: directed functional tests must be an array")
rows = []
for test in tests:
    if not isinstance(test, dict) or any(key not in test for key in ("name", "elf", "elf_sha256", "verilog_image", "verilog_image_sha256")):
        raise SystemExit("INVALID: directed functional test entry is missing required fields")
    name = test["name"]
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", name) or name in names:
        raise SystemExit("INVALID: duplicate or invalid directed functional test name")
    names.add(name)
    paths = []
    for key in ("elf", "verilog_image"):
        if not isinstance(test[key], str):
            raise SystemExit("INVALID: directed functional test path must be a string")
        relative = Path(test[key])
        path = (root / relative).resolve()
        if relative.is_absolute() or not path.is_relative_to(root) or not path.is_file():
            raise SystemExit(f"INVALID: directed functional test file is missing or outside the problem: {key}")
        expected = test[key + "_sha256"]
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected) or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise SystemExit(f"INVALID: directed functional test file hash mismatch: {key}")
        if path.name != name + (".verilog" if key == "verilog_image" else "") or any(c in str(path) for c in "\t\n\r"):
            raise SystemExit("INVALID: directed functional test filename does not match its name")
        paths.append(str(path))
    rows.append("\t".join([name, *paths]))
for row in rows:
    print(row)
PY
then
  exit 2
fi
declare -A DIRECTED_FUNCTIONAL_ELFS=()
while IFS=$'\t' read -r name elf image; do
  [ -n "$name" ] || continue
  DIRECTED_FUNCTIONAL_ELFS["$name"]="$elf"
  IMAGES+=("$image")
done <"$LOG_DIR/directed-functional-tests.tsv"
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
  ln -sf "${DIRECTED_FUNCTIONAL_ELFS[$name]:-$TEST_IMAGE_DIR/$name}" "$short_root/i"
  ln -sf "$image" "$short_root/i.verilog"
  run_program_once "$LOG_DIR" "$log" "$CHECKOUT" timeout "$TIMEOUT_SEC" ./generated/build/Main/VSimTop -l -d -f "$short_root/i"
}

classify_one_test() {
  local image="$1" name log code verdict required_marker
  name="$(basename "$image" .verilog)"
  log="$LOG_DIR/run_${name}.log"
  code="$(cat "${log}.exit" 2>/dev/null || echo -1)"
  if ! required_marker="$(awk -F '\t' -v name="$name" '$1 == name { print $2 }' \
      "$REQUIRED_OBSERVATION_MARKERS_FILE")"; then
    invalid=1
  fi
  verdict="$(program_verdict "$log" "$code" "$required_marker")"
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

if ! python3 - "$PROBLEM_DIR/TEST_RECIPE.json" "$LOG_DIR/directed-cycle-tests.tsv" "$LOG_DIR/directed-cycle-test-count.txt" <<'PY'
import json, sys
tests = json.load(open(sys.argv[1])).get("directed_cycle_tests", [])
rows = ["\t".join(str(test[key]) for key in (
    "name", "elf", "elf_sha256", "verilog_image", "verilog_image_sha256",
    "minimum_cycle", "maximum_cycle")) for test in tests]
with open(sys.argv[2], "w") as stream:
    for row in rows:
        stream.write(row + "\n")
with open(sys.argv[3], "w") as stream:
    stream.write(str(len(tests)) + "\n")
PY
then
  echo "INVALID: directed cycle-test recipe could not be decoded"
  exit 2
fi
directed_test_count=0
while IFS=$'\t' read -r name elf_rel elf_hash image_rel image_hash min_cycle max_cycle; do
  [ -n "$name" ] || continue
  directed_test_count=$((directed_test_count + 1))
  elf="$PROBLEM_DIR/$elf_rel"
  image="$PROBLEM_DIR/$image_rel"
  if [ ! -f "$elf" ] || [ ! -f "$image" ] \
      || [ "$(sha256sum "$elf" | cut -d' ' -f1)" != "$elf_hash" ] \
      || [ "$(sha256sum "$image" | cut -d' ' -f1)" != "$image_hash" ]; then
    echo "INVALID: directed cycle-test artifact is missing or has an unexpected hash: $name"
    invalid=1
    continue
  fi
  short_id="$(printf '%s-%s' "$EVAL_ROOT" "$name" | cksum | cut -d' ' -f1)"
  if [ -n "${SHORT_TEST_DIR:-}" ]; then
    short_root="$SHORT_TEST_DIR/$short_id"
  else
    short_root="/tmp/r2c-$short_id"
  fi
  mkdir -p "$short_root"
  ln -sf "$elf" "$short_root/i"
  ln -sf "$image" "$short_root/i.verilog"
  log="$LOG_DIR/run_${name}.log"
  run_program_once "$LOG_DIR" "$log" "$CHECKOUT" timeout "$TIMEOUT_SEC" \
    ./generated/build/Main/VSimTop -l -d -p -f "$short_root/i"
  code="$(cat "$log.exit")"
  verdict="$(program_verdict "$log" "$code" "" 1)"
  if [ "$verdict" = PASS ]; then
    cycle_status="$(python3 - "$log" "$min_cycle" "$max_cycle" <<'PY'
import re, sys
from pathlib import Path
prefix = "Simulation-Cycle(not equal to cpu-cycle) is:"
values = [line[len(prefix):] for line in Path(sys.argv[1]).read_text().splitlines()
          if line.startswith(prefix)]
if not all(re.fullmatch(r"[0-9]+", value) for value in sys.argv[2:]):
    print("RECIPE_INVALID")
elif len(values) != 1 or not re.fullmatch(r"[0-9]+", values[0]):
    print("MISSING")
else:
    cycle, minimum, maximum = map(int, [values[0], *sys.argv[2:]])
    if not all(0 <= value <= 2**64 - 1 for value in [minimum, maximum]) or minimum > maximum:
        print("RECIPE_INVALID")
    else:
        print("INSIDE" if minimum <= cycle <= maximum else "OUTSIDE")
PY
)"
    case "$cycle_status" in
      INSIDE) ;;
      OUTSIDE) verdict=EXTERNAL_OBSERVATION_MISMATCH ;;
      MISSING) verdict=INCOMPLETE ;;
      *) verdict=INVALID; invalid=1 ;;
    esac
  fi
  case "$verdict" in PASS|NOT_RUN|INVALID) ;; *) functional_fail=1 ;; esac
  printf '%s\t%s\t%s\t%s\n' "$name" "$verdict" "$code" \
    "$(sha256sum "$log" 2>/dev/null | cut -d' ' -f1)" >>"$LOG_DIR/results.tsv"
done <"$LOG_DIR/directed-cycle-tests.tsv"
if [ "$directed_test_count" -ne "$(cat "$LOG_DIR/directed-cycle-test-count.txt")" ]; then
  echo "INVALID: directed cycle-test entry count mismatch"
  invalid=1
fi

sha256sum "$CANDIDATE" "$PROBLEM_DIR/TEST_RECIPE.json" "$LOG_DIR/results.tsv" >"$LOG_DIR/files.sha256"
if [ "$invalid" -eq 1 ]; then echo "INVALID: fixed test inputs could not be used"; exit 2; fi
run_verdict "$LOG_DIR/results.tsv"
exit $?
