#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 SIMULATOR PROGRAM OBSERVATION_DIR" >&2
  exit 2
fi
simulator=$1
program=$2
directory=$3
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$directory"
if [[ ! -x $simulator ]]; then
  printf 'register\tobserved\nx20\tmissing\n' >"$directory/observation.tsv"
  printf 'INVALID\tsimulator_missing\n' >"$directory/verdict.tsv"
  exit 2
fi
rtl_rc=0
"$script_dir/run_simulator.sh" "$simulator" "$program" "$directory/rtl.log" || rtl_rc=$?
printf '%s\n' "$rtl_rc" >"$directory/rtl.exit"
python3 - "$directory" "$rtl_rc" <<'PY'
import pathlib, re, sys
directory = pathlib.Path(sys.argv[1])
log = (directory / "rtl.log").read_text(errors="replace")
values = re.findall(r"\bx20\s+0x([0-9a-fA-F]+)\b", log)
observed = f"{int(values[-1], 16):016x}" if values else "missing"
(directory / "observation.tsv").write_text(f"register\tobserved\nx20\t{observed}\n")
PY
run_rc=0
python3 "$script_dir/failure_cause.py" run "$directory/rtl.log" "$rtl_rc" \
  >"$directory/verdict.tsv" || run_rc=$?
if [[ $run_rc -ne 0 ]]; then
  exit "$run_rc"
fi
if [[ $rtl_rc -eq 0 ]] && grep -q '\*\*\* PASSED \*\*\*' "$directory/rtl.log" &&
    ! grep -q $'\tmissing$' "$directory/observation.tsv"; then
  printf 'PASS\tprogram_completed_with_x20\n' >"$directory/verdict.tsv"
  exit 0
fi
printf 'FAIL\tprogram_failed_or_x20_missing\n' >"$directory/verdict.tsv"
exit 1
