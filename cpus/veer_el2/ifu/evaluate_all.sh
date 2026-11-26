#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
results_dir=${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}
export MAKEFLAGS="${MAKEFLAGS:-} VERILATOR=$here/test/verilate_with_redirect_observer.sh"
bash "$here/../_shared/run_fixed_test.sh"
python3 - "$results_dir" <<'PY'
from pathlib import Path
import re
import sys

log = Path(sys.argv[1]) / "riscv_arithmetic_basic_test.log"
pattern = re.compile(r"^IFU_FETCH_REDIRECT expected=([0-9a-f]{8}) actual=([0-9a-f]{8})$")
observations = []
for line in log.read_text(errors="replace").splitlines():
    match = pattern.fullmatch(line)
    if match:
        observations.append(match.groups())
if not observations:
    print("FAIL: no instruction fetch redirect observation was collected")
    raise SystemExit(2)

mismatches = 0
for expected, actual in observations:
    if expected != actual:
        mismatches += 1
        print(f"IFU_FETCH_REDIRECT_MISMATCH expected={expected} actual={actual}")
print(f"IFU_FETCH_REDIRECT_RESULT checked={len(observations)} mismatches={mismatches}")
raise SystemExit(1 if mismatches else 0)
PY
