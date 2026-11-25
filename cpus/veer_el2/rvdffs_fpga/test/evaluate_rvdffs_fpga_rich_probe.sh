#!/usr/bin/env bash
# Build and run rvdffs_fpga_rich_probe.s and read three program results
# from DCCM through JTAG/OpenOCD. Before this script runs, the caller must
# install the submitted rvdffs_fpga module in design/lib/beh_lib.sv.
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
log="$results_dir/rvdffs_fpga_rich_probe.log"
status_file="$results_dir/rvdffs_fpga_rich_probe.status"
: >"$log"

DCCM_ADDR="0xf0040000"
EXPECT_ICACHE_TOTAL_DEC=64   # CALL_COUNT

run_dir="$PWD/run_rich_probe"
rm -rf "$run_dir"
mkdir -p "$run_dir"
script_dir="$(dirname "${BASH_SOURCE[0]}")"
port_build_log="$results_dir/port-build.log"
port_log="$results_dir/ports.log"
if ! verilator --binary --timing -j 4 --top-module rvdffs_fpga_ports -Wno-fatal \
    -DRV_FPGA_OPTIMIZE -DTEC_RV_ICG=clockhdr --Mdir "$run_dir/ports" \
    "$RV_ROOT/design/lib/beh_lib.sv" "$script_dir/rvdffs_fpga_ports.sv" \
    >"$port_build_log" 2>&1; then
  cat "$port_build_log" >&2
  printf '2\n' >"$status_file"
  exit 2
fi
if ! "$run_dir/ports/Vrvdffs_fpga_ports" >"$port_log" 2>&1; then
  cat "$port_log" >&2
  printf '2\n' >"$status_file"
  exit 2
fi
if grep -Eq '^PORT_CHECKS_COMPLETE mismatches=[1-9][0-9]*$' "$port_log"; then
  cat "$port_log" >&2
  printf '1\n' >"$status_file"
  exit 1
fi
if ! grep -Fxq 'PORT_CHECKS_COMPLETE mismatches=0' "$port_log"; then
  cat "$port_log" >&2
  printf '2\n' >"$status_file"
  exit 2
fi

cp "$script_dir/dccm_probe.cfg" "$run_dir/dccm_probe.cfg"
mkdir -p testbench/asm
cp "$script_dir/rvdffs_fpga_rich_probe.s" testbench/asm/rvdffs_fpga_rich_probe.s

build_log="$results_dir/build.log"
set +e
make -C "$run_dir" -f "$RV_ROOT/tools/Makefile" verilator-build program.hex \
    TEST=rvdffs_fpga_rich_probe \
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
timeout --verbose 600 openocd -d2 -f "$run_dir/dccm_probe.cfg" \
  -c "init" \
  -c 'halt; set done 0; for {set i 0} {$i < 20} {incr i} {if {[lindex [read_memory 0xf0040030 32 1] 0] == 1} {set done 1; break}; resume; halt}; if {!$done} {error "program completion not observed"}; echo "program completion observed after $i resumes"' \
  -c "mdw ${DCCM_ADDR} 3" \
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

read -r icache_total call1_cycles callN_cycles <<<"$(printf '%s' "$readback_line" | awk '{print $2, $3, $4}' | tr 'A-F' 'a-f')"
printf 'icache_total=%s call1_cycles=%s callN_cycles=%s\n' \
  "$icache_total" "$call1_cycles" "$callN_cycles" >>"$log"

if [ -z "$icache_total" ] || [ -z "$call1_cycles" ] || [ -z "$callN_cycles" ]; then
  printf 'FAIL: could not parse all three readback words\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi

icache_total_dec=$((16#$icache_total))
if [ "$icache_total_dec" -ne "$EXPECT_ICACHE_TOTAL_DEC" ]; then
  printf 'FAIL: icache call total %d (0x%s) != expected %d (content corruption)\n' \
    "$icache_total_dec" "$icache_total" "$EXPECT_ICACHE_TOTAL_DEC" >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi

# The intervals include caller instructions at different addresses.
call1_dec=$((16#$call1_cycles))
callN_dec=$((16#$callN_cycles))
if [ "$call1_dec" -le "$callN_dec" ]; then
  printf 'FAIL: call#1 cycles (%d) not > call#%s cycles (%d) (icache timing anomaly)\n' \
    "$call1_dec" "64" "$callN_dec" >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi

printf 'PASS (self-check: icache total and timing hold)\n' >>"$log"
printf '0\n' >"$status_file"
exit 0
