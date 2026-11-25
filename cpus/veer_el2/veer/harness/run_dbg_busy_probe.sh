#!/usr/bin/env bash
# Read abstract-command completion and mcycle data through OpenOCD.
set -uo pipefail
export RV_ROOT="$PWD"
for tool in verilator riscv64-unknown-elf-gcc openocd ss; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'CPU_EVAL_INVALID: required tool is not on PATH: %s\n' "$tool" >&2
    exit 2
  }
done
if ! verilator --version 2>&1 | grep -q ' 5\.036 '; then
  printf 'CPU_EVAL_INVALID: wrong verilator on PATH (expected 5.036): %s\n' "$(verilator --version 2>&1)" >&2
  exit 2
fi
results_dir="${CPU_EVAL_RESULTS_DIR:-$PWD/cpu-eval-results}"
mkdir -p "$results_dir"
log="$results_dir/dbg_busy_probe.log"
status_file="$results_dir/dbg_busy_probe.status"
: >"$log"

run_dir="$PWD/run_dbg_busy_probe"
rm -rf "$run_dir"
mkdir -p "$run_dir"
cp "$(dirname "${BASH_SOURCE[0]}")/reg_probe.cfg" "$run_dir/reg_probe.cfg"

build_log="$results_dir/dbg_busy_probe_build.log"
make -C "$run_dir" -f "$RV_ROOT/tools/Makefile" verilator-build program.hex TEST=infinite_loop \
    CONF_PARAMS="-set build_axi4 -set openocd_test" >"$build_log" 2>&1
build_status=$?
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

sim_log="$results_dir/dbg_busy_probe_sim.log"
ocd_log="$results_dir/dbg_busy_probe_openocd.log"
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
timeout --verbose 600 openocd -d3 -f "$run_dir/reg_probe.cfg" \
  -c "init" -c "halt" \
  -c "riscv dmi_write 0x17 0x220b00" \
  -c "sleep 50" \
  -c "riscv dmi_read 0x16" \
  -c "riscv dmi_read 0x4" \
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

# Read abstractcs and data0 after the mcycle Access Register command.
extract_after() {
  awk -v marker="$1" '
    BEGIN{found=0}
    { if (index($0, "command - " marker) > 0) { found=1; next } }
    found && index($0, "command -") > 0 { found=0 }
    found && match($0, /configuration_output_handler\(\): (0x[0-9a-fA-F]+)/, m) { print m[1]; exit }
  ' "$ocd_log"
}
abstractcs_hex="$(extract_after 'riscv dmi_read 0x16')"
data0_hex="$(extract_after 'riscv dmi_read 0x4')"
printf 'abstractcs=%s data0=%s\n' "${abstractcs_hex:-NONE}" "${data0_hex:-NONE}" >>"$log"
if [ -z "$abstractcs_hex" ] || [ -z "$data0_hex" ]; then
  printf 'FAIL: no abstractcs or data0 value found in OpenOCD output\n' >>"$log"
  printf '2\n' >"$status_file"
  cat "$log" >&2
  exit 2
fi
busy=$(( (abstractcs_hex) >> 12 & 1 ))
printf 'busy=%s\n' "$busy" >>"$log"
if [ "$busy" -ne 0 ]; then
  printf 'FAIL\tabstract command is still busy at the mcycle-read observation (abstractcs=%s)\n' "$abstractcs_hex" >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi
command_error=$(( (abstractcs_hex) >> 8 & 7 ))
if [ "$command_error" -ne 0 ]; then
  printf 'FAIL\tabstract command reported an error (cmderr=%s)\n' "$command_error" >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi
if [ "$((data0_hex))" -eq 0 ]; then
  printf 'FAIL\tcompleted mcycle readback (data0) is zero; this probe expects a nonzero count\n' >>"$log"
  printf '1\n' >"$status_file"
  cat "$log" >&2
  exit 1
fi
printf 'PASS\tmcycle_data0=%s\n' "$data0_hex" >>"$log"
printf '0\n' >"$status_file"
cat "$log" >&2
exit 0
