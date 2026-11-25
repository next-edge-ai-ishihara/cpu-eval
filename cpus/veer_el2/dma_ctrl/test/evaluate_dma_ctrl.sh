#!/usr/bin/env bash
# Write and read back a DCCM word through the debug module abstract memory access
# (OpenOCD mww/mdw over JTAG remote_bitbang, openocd_test configuration).
set -euo pipefail
export RV_ROOT="$PWD"
for tool in verilator riscv64-unknown-elf-gcc openocd ss; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/dma_ctrl_dbg_mem_probe.log"
status_file="$results_dir/dma_ctrl_dbg_mem_probe.status"
: >"$log"

DCCM_ADDR="0xf0040000"
WRITE_VALUE="5a5a1234"
EXPECT_LINE="${DCCM_ADDR}: ${WRITE_VALUE}"

run_dir="$PWD/run_dma_probe"
rm -rf "$run_dir"
mkdir -p "$run_dir"
cp "$(dirname "${BASH_SOURCE[0]}")/dma_probe.cfg" "$run_dir/dma_probe.cfg"

build_log="$results_dir/build.log"
set +e
make -C "$run_dir" -f "$RV_ROOT/tools/Makefile" verilator-build program.hex TEST=infinite_loop \
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

set +e
bash "$(dirname "${BASH_SOURCE[0]}")/run_dma_axi_probe.sh" "$run_dir/snapshots/default" >>"$log" 2>&1
axi_status=$?
set -e
if [ "$axi_status" -ne 0 ]; then
  printf '%s\n' "$axi_status" >"$status_file"
  cat "$log" >&2
  exit "$axi_status"
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
timeout --verbose 600 openocd -d2 -f "$run_dir/dma_probe.cfg" \
  -c "init" -c "halt" \
  -c "mww ${DCCM_ADDR} 0x${WRITE_VALUE}" \
  -c "mdw ${DCCM_ADDR} 1" \
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

readback_line="$(grep -i "^${DCCM_ADDR}:" "$ocd_log" | tail -1 || true)"
if [ -z "$readback_line" ]; then
  printf 'FAIL: no memory readback line found in OpenOCD output\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

readback_value="$(printf '%s' "$readback_line" | awk '{print $2}' | tr 'A-F' 'a-f')"
printf 'expected=%s actual=%s\n' "$WRITE_VALUE" "$readback_value" >>"$log"

if [ "$readback_value" = "$WRITE_VALUE" ]; then
  printf 'PASS\n' >>"$log"
  printf '0\n' >"$status_file"
  exit 0
fi
printf 'FAIL\n' >>"$log"
printf '1\n' >"$status_file"
exit 1
