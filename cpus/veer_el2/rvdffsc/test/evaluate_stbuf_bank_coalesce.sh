#!/usr/bin/env bash
# Two halfword stores to one DCCM word coalesce in a store-buffer entry while bank-matching
# loads delay its drain; read the word back through OpenOCD mdw once the program sets its done flag.
set -euo pipefail
export RV_ROOT="$PWD"
if ! python3 - "${BASH_SOURCE[0]}" "$PWD/testbench/asm/stbuf_bank_contend.s" <<'PY_FIXED'
import hashlib,json,pathlib,sys
script=pathlib.Path(sys.argv[1]).resolve();problem=script.parent.parent
recipe=json.loads((problem/'TEST_RECIPE.json').read_text());test=recipe['test']
checks=[(script,recipe['run_sha256']),(script,test['sha256']),(problem/test['config_path'],test['config_sha256']),(pathlib.Path(sys.argv[2]),test['program_sha256'])]
probe=recipe['clear_priority_probe']
checks.append((problem/probe['path'],probe['sha256']))
raise SystemExit(0 if all(p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==h for p,h in checks) else 2)
PY_FIXED
then
  printf 'CPU_EVAL_INVALID: fixed probe input hash mismatch\n' >&2
  exit 2
fi
for tool in verilator riscv64-unknown-elf-gcc openocd ss; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/stbuf_bank_coalesce_probe.log"
status_file="$results_dir/stbuf_bank_coalesce_probe.status"
: >"$log"

TARGET_ADDR="0xf0040010"
RELOAD_ADDR="0xf0040020"
DONE_ADDR="0xf0040030"
POLL_LIMIT=20
EXPECT_VALUE="56781234"

run_dir="$PWD/run_stbuf_bank_coalesce_probe"
rm -rf "$run_dir"
mkdir -p "$run_dir"
cp "$(dirname "${BASH_SOURCE[0]}")/stbuf_probe.cfg" "$run_dir/stbuf_probe.cfg"

build_log="$results_dir/build.log"
set +e
make -C "$run_dir" -f "$RV_ROOT/tools/Makefile" verilator-build program.hex TEST=stbuf_bank_contend \
    CONF_PARAMS="-set build_axi4 -set openocd_test" >"$build_log" 2>&1
build_status=$?
set -e
if [ "$build_status" -ne 0 ]; then
  # The candidate builds first; a later failure is in the fixed program.
  if [ "$build_status" -eq 124 ] || [ "$build_status" -eq 137 ] || [ "$build_status" -eq 143 ] ||
     [ -f "$run_dir/verilator-build" ]; then
    printf 'CPU_EVAL_INVALID: build was interrupted or the fixed program did not build (exit %s)\n' "$build_status" >>"$log"
  else
    printf 'FAIL: verilator-build failed\n' >>"$log"
  fi
  cat "$build_log" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
if ! grep -q 'verilator --cc' "$build_log"; then
  printf 'CPU_EVAL_INVALID: verilator did not run -- the fixed program did not build or stale build artifacts were reused\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

sim_log="$results_dir/sim.log"
ocd_log="$results_dir/openocd.log"
: >"$sim_log"

cleanup() {
  if [ -n "${SIM_PID:-}" ] && kill -0 "$SIM_PID" 2>/dev/null; then
    kill -9 "$SIM_PID" 2>/dev/null || true
    wait "$SIM_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [ -n "$(ss -H -ltn 'sport = :5000')" ]; then
  printf 'CPU_EVAL_INVALID: JTAG-DPI port 5000 is already in use\n' >>"$log"
  cat "$log" >&2
  printf '2\n' >"$status_file"
  exit 2
fi
(cd "$run_dir" && exec ./obj_dir/Vtb_top) >"$sim_log" 2>&1 &
SIM_PID=$!

socket_ready=0
for ((attempt=0; attempt<75; attempt++)); do
  if ! kill -0 "$SIM_PID" 2>/dev/null; then
    break
  fi
  if ss -H -ltnp 'sport = :5000' | grep -Fq "pid=${SIM_PID},"; then
    socket_ready=1
    break
  fi
  sleep 0.2
done
if [ "$socket_ready" -ne 1 ]; then
  if kill -0 "$SIM_PID" 2>/dev/null; then
    printf 'CPU_EVAL_INVALID: simulation did not open the JTAG-DPI socket on port 5000 within 15 seconds\n' >>"$log"
  else
    printf 'FAIL: simulation exited before opening the JTAG-DPI socket on port 5000\n' >>"$log"
  fi
  cat "$sim_log" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

set +e
timeout --verbose 600 openocd -d2 -f "$run_dir/stbuf_probe.cfg" \
  -c "init" \
  -c "halt; set done 0; for {set i 0} {\$i < ${POLL_LIMIT}} {incr i} {if {[lindex [read_memory ${DONE_ADDR} 32 1] 0] == 1} {set done 1; break}; resume; halt}; if {!\$done} {error \"program completion not observed\"}; echo \"program completion observed after \$i resumes\"" \
  -c "mdw ${TARGET_ADDR} 1" \
  -c "mdw ${RELOAD_ADDR} 1" \
  -c "shutdown" >"$ocd_log" 2>&1
ocd_status=$?
set -e

cat "$ocd_log" >>"$log"

if [ "$ocd_status" -eq 124 ] || [ "$ocd_status" -eq 137 ] || [ "$ocd_status" -eq 143 ]; then
  printf 'CPU_EVAL_INVALID: OpenOCD reached its wall-clock limit (exit %s)\n' "$ocd_status" >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
# The simulator is listening, so any other OpenOCD error comes from the target.
if [ "$ocd_status" -ne 0 ]; then
  printf 'FAIL\tOpenOCD reported a target error (exit %s)\n' "$ocd_status" >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi

target_line="$(grep -i "^${TARGET_ADDR}:" "$ocd_log" | tail -1 || true)"
reload_line="$(grep -i "^${RELOAD_ADDR}:" "$ocd_log" | tail -1 || true)"
if [ -z "$target_line" ] || [ -z "$reload_line" ]; then
  printf 'FAIL: no memory readback line found in OpenOCD output for one or both addresses\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

target_value="$(printf '%s' "$target_line" | awk '{print $2}' | tr 'A-F' 'a-f')"
reload_value="$(printf '%s' "$reload_line" | awk '{print $2}' | tr 'A-F' 'a-f')"
printf 'expected=%s target(drained)=%s reload(cpu-load-stashed)=%s\n' \
  "$EXPECT_VALUE" "$target_value" "$reload_value" >>"$log"

if [ "$target_value" != "$EXPECT_VALUE" ] || [ "$reload_value" != "$EXPECT_VALUE" ]; then
  printf 'FAIL\n' >>"$log"
  printf '1\n' >"$status_file"
  exit 1
fi
printf 'PASS\n' >>"$log"
printf '0\n' >"$status_file"

cleanup
trap - EXIT

probe_log="$results_dir/clear_priority_probe.log"
probe_status="$results_dir/clear_priority_probe.status"
probe="$(dirname "${BASH_SOURCE[0]}")/clear_priority_probe.sv"
snapshot="$run_dir/snapshots/default"
if ! timeout --verbose 120 verilator --binary --timing -j 2 -Wno-fatal \
    --top-module clear_priority_probe --Mdir "$run_dir/clear_priority_obj" \
    "$snapshot/common_defines.vh" "$RV_ROOT/design/lib/beh_lib.sv" "$probe" \
    >"$results_dir/clear_priority_build.log" 2>&1; then
  printf '2\n' >"$probe_status"
  exit 2
fi
if ! timeout --verbose 10 "$run_dir/clear_priority_obj/Vclear_priority_probe" >"$probe_log" 2>&1; then
  printf '2\n' >"$probe_status"
  exit 2
fi
if grep -Fxq 'CLEAR_PRIORITY_DONE mismatches=0' "$probe_log"; then
  printf '0\n' >"$probe_status"
  exit 0
fi
if grep -Eq '^CLEAR_PRIORITY_DONE mismatches=[1-3]$' "$probe_log"; then
  printf '1\n' >"$probe_status"
  exit 1
fi
printf '2\n' >"$probe_status"
exit 2
