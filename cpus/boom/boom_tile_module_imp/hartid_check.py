"""Read mhartid during boot under a nonzero simulated subsystem prefix."""

import hashlib
import json
from pathlib import Path
import re
import sys


UPSTREAM = "40f28ae245f6bfc4c1edd9980024379c2006d0a62396c68f81bb2cc346147a13"
DEFAULT = b"default = Some(() => 0.U(p(MaxHartIdBits).W)),"
SIMULATED = (
    b'default = Some(() => freechips.rocketchip.util.PlusArg("cpu_eval_tile_hartid", '
    b'width = p(MaxHartIdBits))),'
)


def prepare(path):
    source = Path(path)
    original = source.read_bytes()
    if hashlib.sha256(original).hexdigest() != UPSTREAM or original.count(DEFAULT) != 1:
        raise SystemExit("hart ID probe requires the pinned Rocket Chip subsystem source")
    source.write_bytes(original.replace(DEFAULT, SIMULATED))


def check(evidence, status):
    evidence = Path(evidence)
    trace = (evidence / "hartid-probe/rtl.log").read_bytes()
    # The fixed boot ROM reads mhartid into a0 before it branches on the hart ID.
    values = re.findall(rb"(?m)^3 0x0*10004 \(0xf1402573\) x10 0x([0-9a-fA-F]+)\s*$", trace)
    observed = int(values[0], 16) if values else None
    if status in {124, 137, 143}:
        verdict, detail, result = "INVALID", "nonzero_hart_id_probe_interrupted", 2
    elif status not in {0, 2} or observed is None:
        verdict, detail, result = "FAIL", "nonzero_hart_id_observation_missing", 1
    elif observed != 1:
        verdict, detail, result = "FAIL", "nonzero_hart_id_mismatch", 1
    else:
        verdict, detail, result = "PASS", "nonzero_hart_id_observed", 0
    report = {"requested_hart_id": 1, "observed_hart_id": observed, "rtl_exit": status, "verdict": verdict}
    (evidence / "hartid-probe/result.json").write_text(json.dumps(report, indent=2) + "\n")
    (evidence / "verdict.tsv").write_text(f"{verdict}\t{detail}\n")
    return result


if __name__ == "__main__":
    operation, *arguments = sys.argv[1:]
    if operation == "prepare":
        prepare(*arguments)
    elif operation == "check":
        raise SystemExit(check(arguments[0], int(arguments[1])))
    else:
        raise SystemExit(f"unknown operation: {operation}")
