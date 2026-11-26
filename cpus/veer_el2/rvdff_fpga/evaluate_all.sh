#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
results_dir=${CPU_EVAL_RESULTS_DIR:?CPU_EVAL_RESULTS_DIR is required}
export MAKEFLAGS="${MAKEFLAGS:-} VERILATOR=$here/test/verilate_with_storage_observer.sh"
bash "$here/../_shared/run_fixed_test.sh"
python3 - "$results_dir" <<'PYTHON'
from pathlib import Path
import re
import sys

log = Path(sys.argv[1]) / "riscv_arithmetic_basic_test.log"
pattern = re.compile(
    r"RVDFF_FPGA_STORAGE instance=\S+ samples=(\d+) transitions=(\d+) "
    r"closed_enable_transitions=(\d+) mismatches=(\d+)"
)
observations = [tuple(map(int, match.groups())) for match in pattern.finditer(log.read_text())]
totals = [sum(values) for values in zip(*observations)]
if not observations or not totals[0] or not totals[1]:
    print("FAIL: no active rvdff_fpga storage observation was collected")
    raise SystemExit(2)
samples, transitions, closed, mismatches = totals
print(f"RVDFF_FPGA_RESULT instances={len(observations)} samples={samples} "
      f"transitions={transitions} closed_enable_transitions={closed} mismatches={mismatches}")
raise SystemExit(1 if mismatches else 0)
PYTHON
