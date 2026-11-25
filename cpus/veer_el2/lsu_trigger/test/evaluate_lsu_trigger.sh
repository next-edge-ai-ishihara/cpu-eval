#!/usr/bin/env bash
# Run the directed load and store trigger program and read its mailbox result.

set -euo pipefail
export RV_ROOT="$PWD"
python3 - "$(dirname "${BASH_SOURCE[0]}")/../TEST_RECIPE.json" <<'PY'
import hashlib, json, pathlib, sys
recipe_path = pathlib.Path(sys.argv[1])
test = json.loads(recipe_path.read_text())["test"]
path = recipe_path.parent / test["path"]
actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
if actual != test["sha256"]:
    print("CPU_EVAL_INVALID: fixed test source SHA-256 mismatch", file=sys.stderr)
    raise SystemExit(2)
PY
for tool in verilator riscv64-unknown-elf-gcc; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/lsu_trigger_addr_match.log"
status_file="$results_dir/lsu_trigger_addr_match.status"

cp "$(dirname "${BASH_SOURCE[0]}")/lsu_trigger_addr_match.s" testbench/asm/lsu_trigger_addr_match.s

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build lsu_trigger_addr_match.exe lsu_trigger_addr_match.o lsu_trigger_addr_match.map lsu_trigger_addr_match.sym lsu_trigger_addr_match.dis program.hex crt0.o

set +e
make -f tools/Makefile verilator TEST=lsu_trigger_addr_match TEST_DIR=testbench/asm >"$log" 2>&1
make_status=$?
set -e
if [ "$make_status" -eq 124 ] || [ "$make_status" -eq 137 ] || [ "$make_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: build or simulation was interrupted (exit %s)\n' "$make_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if ! grep -q 'verilator --cc' "$log"; then
  printf 'CPU_EVAL_INVALID: verilator did not run -- the fixed program did not build or stale build artifacts were reused\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'VerilatorTB: Start of sim' "$log" &&
  grep -Eq '^Hit max cycle count \([0-9]+\) \.\. stopping$' "$log"; then
  printf '1\n' >"$status_file"
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  cat "$log" >&2
  exit 1
fi
if grep -q 'Hit max cycle count' "$log"; then
  printf 'FAIL: RTL simulation reached its cycle limit before completion\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'TEST_PASSED' "$log" && grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL: the program reported both TEST_PASSED and TEST_FAILED\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'TEST_PASSED' "$log" && [ "$make_status" -ne 0 ]; then
  printf 'FAIL: TEST_PASSED followed by an abnormal make exit\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if grep -q 'TEST_PASSED' "$log"; then
  printf 'PASS\n' >>"$log"
  printf '0\n' >"$status_file"
  exit 0
fi
if grep -q 'TEST_FAILED' "$log"; then
  printf 'FAIL\n' >>"$log"
  printf '1\n' >"$status_file"
  exit 1
fi
printf 'FAIL: no TEST_PASSED or TEST_FAILED marker found in simulation output\n' >>"$log"
printf '2\n' >"$status_file"
cat "$log" >&2
exit 2
