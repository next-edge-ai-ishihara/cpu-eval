#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "usage: run_prebuilt_testharness.sh <CVA6 checkout> <Spike tools> <ISA> <ELF> <simulator options> <post-run pattern> <log>" >&2
  exit 2
fi

repo=$(realpath "$1")
tools=$(realpath "$2")
isa=$3
elf=$(realpath "$4")
simulator_options=$5
post_run_pattern=$6
log=$(realpath -m "$7")
run_directory=$(dirname "$log")
simulator="$repo/work-ver/Variane_testharness"
nm_tool=${RISCV:?RISCV is not set}/bin/${CV_SW_PREFIX:-riscv64-unknown-elf-}nm

# Exit 127 for a missing fixed tool so the caller keeps the run INVALID.
for tool in "$simulator" "$tools/spike-dasm" "$nm_tool"; do
  test -x "$tool" || { echo "fixed tool is missing: $tool" >&2; exit 127; }
done
mkdir -p "$run_directory"
tohost_address=$($nm_tool -B "$elf" | awk '$3 == "tohost" { print $1; exit }')
test -n "$tohost_address" || { echo "fixed program has no tohost symbol: $elf" >&2; exit 127; }

read -r -a option_array <<<"$simulator_options"
(
  cd "$run_directory"
  rm -f trace_rvfi_hart_00.dasm
  simulator_status=0
  "$simulator" "$elf" "${option_array[@]}" \
    "++$elf" \
    "+elf_file=$elf" \
    "+core_name=cv32a60x" \
    "+tohost_addr=$tohost_address" \
    "+signature=$elf.signature_output" \
    "+UVM_TESTNAME=uvmt_cva6_firmware_test_c" \
    "+report_file=$log.yaml" || simulator_status=$?
  # A start failure or an external kill is not the answer's fault; any other end
  # leaves the trace, possibly empty, to the architectural comparison.
  case "$simulator_status" in
    124|126|127|137|143)
      echo "simulator did not run to its end: status $simulator_status" >&2
      exit "$simulator_status" ;;
  esac
  if [ ! -f trace_rvfi_hart_00.dasm ]; then
    echo "simulator exited with status $simulator_status before opening the architectural trace" >&2
    : >trace_rvfi_hart_00.dasm
  fi
  "$tools/spike-dasm" --isa="$isa" <trace_rvfi_hart_00.dasm >"$log"
  if [ "$simulator_status" -ne 0 ]; then
    printf 'simulator exited with status %s after producing an architectural trace\n' \
      "$simulator_status" >&2
  fi
  grep "$post_run_pattern" trace_rvfi_hart_00.dasm || true
)
