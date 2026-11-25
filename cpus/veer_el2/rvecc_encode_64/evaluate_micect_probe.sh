#!/usr/bin/env bash
# Run the pinned icache_ecc.c program and compare the micect value it reads after
# cache warmup and before fault injection (mailbox 0x89) with the expected value.
set -euo pipefail
if [ -z "${CPU_EVAL_EXPECTED_MICECT_BEFORE:-}" ]; then
  printf 'CPU_EVAL_INVALID: CPU_EVAL_EXPECTED_MICECT_BEFORE must be the reference micect value\n' >&2
  exit 2
fi
export RV_ROOT="$PWD"
if ! python3 - "${BASH_SOURCE[0]}" "$PWD" <<'PY_FIXED'
import hashlib,json,pathlib,sys
script=pathlib.Path(sys.argv[1]).resolve();recipe=json.loads((script.parent/'TEST_RECIPE.json').read_text());test=recipe['test'];source=pathlib.Path(sys.argv[2])/test['source']
raise SystemExit(0 if source.is_file() and hashlib.sha256(source.read_bytes()).hexdigest()==test['source_sha256'] and hashlib.sha256(script.read_bytes()).hexdigest()==recipe['run_sha256'] else 2)
PY_FIXED
then
  printf 'CPU_EVAL_INVALID: fixed micect probe input hash mismatch\n' >&2
  exit 2
fi
for tool in verilator riscv64-unknown-elf-gcc; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/icache_ecc_micect_probe.log"
status_file="$results_dir/icache_ecc_micect_probe.status"

# Force recompilation of the candidate RTL.
rm -rf obj_dir
rm -f verilator-build icache_ecc.exe icache_ecc.o icache_ecc.map icache_ecc.sym icache_ecc.dis program.hex crt0.o printf.o

# The program's own delta check can fail make; the pre-injection value decides.
set +e
make -f tools/Makefile verilator TEST=icache_ecc TEST_DIR=testbench/tests/icache_ecc >"$log" 2>&1
make_status=$?
set -e
case "$make_status" in
  124|137|143)
    printf 'CPU_EVAL_INVALID: execution interrupted before completion (make exit %s)\n' "$make_status" >>"$log"
    printf '2\n' >"$status_file"
    cat "$log" >&2
    exit 2 ;;
esac
if ! grep -q 'verilator --cc' "$log"; then
  printf 'CPU_EVAL_INVALID: verilator did not run -- the fixed program did not build or stale build artifacts were reused (make exit %s)\n' "$make_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

observed="$(grep -E 'micect \(0x7F0\): before = [0-9]+, after = [0-9]+' "$log" | tail -1 | sed -E 's/.*before = ([0-9]+), after = ([0-9]+).*/\1/' || true)"
if [ -z "$observed" ]; then
  printf 'FAIL: no micect before/after line found in simulation output (make exit %s)\n' "$make_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if [ "$observed" != "$CPU_EVAL_EXPECTED_MICECT_BEFORE" ]; then
  printf 'FAIL\tmicect before-injection value differs: expected=%s observed=%s\n' \
    "$CPU_EVAL_EXPECTED_MICECT_BEFORE" "$observed" >>"$log"
  printf '1\n' >"$status_file"
  exit 1
fi
printf 'PASS\tmicect before-injection value matches: %s\n' "$observed" >>"$log"
printf '0\n' >"$status_file"
exit 0
