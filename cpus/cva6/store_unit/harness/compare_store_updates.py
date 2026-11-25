#!/usr/bin/env python3


from __future__ import annotations

import argparse
import dataclasses
import json
import re
import sys
from pathlib import Path


STORE_RE = re.compile(
    r"\b(?P<pc>0x[0-9a-fA-F]+)\s+\((?P<insn>0x[0-9a-fA-F]+)\)"
    r".*?\bmem\s+(?P<address>0x[0-9a-fA-F]+)\s+"
    r"(?P<value>0x[0-9a-fA-F]+)\s*$"
)
MEM_WRITE_RE = re.compile(
    r"\bCVA6_MEM_WRITE\s+(?P<address>[0-9a-fA-F]+)\s+"
    r"(?P<byte_enable>[0-9a-fA-F]+)\s+(?P<data>[0-9a-fA-F]+)\s*$"
)


@dataclasses.dataclass(frozen=True)
class StoreUpdate:
    pc: int
    instruction: int
    address: int
    value: int
    value_bytes: int


@dataclasses.dataclass(frozen=True)
class MemoryWrite:
    address: int
    byte_enable: int
    data: int


def parse_store_updates(path: Path) -> list[StoreUpdate]:
    updates: list[StoreUpdate] = []
    for line in path.read_text(errors="replace").splitlines():
        match = STORE_RE.search(line)
        if not match:
            if re.search(r"\bmem\s+0x\S+\s+0x\S+", line):
                raise ValueError(f"unrecognized store update in {path}: {line}")
            continue
        value_digits = len(match.group("value")) - 2
        if value_digits % 2 or value_digits // 2 not in (1, 2, 4, 8):
            raise ValueError(f"unsupported store width in {path}: {line}")
        updates.append(
            StoreUpdate(
                pc=int(match.group("pc"), 16),
                instruction=int(match.group("insn"), 16),
                address=int(match.group("address"), 16),
                value=int(match.group("value"), 16),
                value_bytes=value_digits // 2,
            )
        )
    return updates


def parse_memory_writes(path: Path) -> list[MemoryWrite]:
    writes: list[MemoryWrite] = []
    for line in path.read_text(errors="replace").splitlines():
        match = MEM_WRITE_RE.search(line)
        if "CVA6_MEM_WRITE" in line and not match:
            raise ValueError(f"unrecognized memory write in {path}: {line}")
        if match:
            writes.append(
                MemoryWrite(
                    address=int(match.group("address"), 16),
                    byte_enable=int(match.group("byte_enable"), 16),
                    data=int(match.group("data"), 16),
                )
            )
    return writes


def compare_store_updates(
    rtl_path: Path, spike_path: Path, exclude_addresses: set[int] | None = None,
    rtl_trace: Path | None = None,
) -> dict[str, object]:
    if not spike_path.read_text(errors="replace").strip():
        raise ValueError("empty Spike store comparison input")
    excluded = exclude_addresses or set()
    spike = [
        update for update in parse_store_updates(spike_path)
        if update.address not in excluded
    ]
    if not spike:
        raise ValueError("no payload stores found in the fixed Spike input")
    try:
        rtl = parse_memory_writes(rtl_path)
    except ValueError as error:
        # The RTL memory log comes from the answer, so an unreadable one is a mismatch.
        return {"verdict": "FAIL", "rtl_store_count": None, "spike_store_count": len(spike),
                "mismatches": [{"kind": "rtl_memory_log", "error": str(error)}]}
    mismatches: list[dict[str, object]] = []
    if len(rtl) != len(spike):
        mismatches.append(
            {"kind": "count", "rtl": len(rtl), "spike": len(spike)}
        )
    for index, (rtl_update, spike_update) in enumerate(zip(rtl, spike)):
        width = spike_update.value_bytes
        mask = (1 << (8 * width)) - 1
        bus_base = rtl_update.address & ~0x7
        offset = spike_update.address - bus_base
        expected_enable = ((1 << width) - 1) << offset if 0 <= offset <= 8 - width else -1
        fields = {
            "address": (
                bus_base + (rtl_update.byte_enable & -rtl_update.byte_enable).bit_length() - 1,
                spike_update.address,
            ),
            "byte_enable": (rtl_update.byte_enable, expected_enable),
            "value": ((rtl_update.data >> (8 * max(offset, 0))) & mask, spike_update.value & mask),
        }
        differences = {
            name: {"rtl": f"0x{actual:x}", "spike": f"0x{expected:x}"}
            for name, (actual, expected) in fields.items()
            if actual != expected
        }
        if differences:
            mismatches.append(
                {"kind": "store", "index": index, "width_bytes": width, **differences}
            )
    return {
        "verdict": "FAIL" if mismatches else "PASS",
        "rtl_store_count": len(rtl),
        "spike_store_count": len(spike),
        "mismatches": mismatches,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rtl-memory", dest="rtl", type=Path, required=True)
    parser.add_argument("--spike", type=Path, required=True)
    parser.add_argument("--rtl-trace", type=Path)
    parser.add_argument("--exclude-address", action="append", default=[])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = compare_store_updates(
            args.rtl, args.spike, {int(value, 0) for value in args.exclude_address},
            args.rtl_trace,
        )
        status = 1 if result["mismatches"] else 0
    except (OSError, ValueError, ImportError) as error:
        result = {"verdict": "INVALID", "error": str(error)}
        status = 2
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        try:
            args.output.write_text(rendered)
        except OSError as error:
            print(f"INVALID: comparison output could not be written: {error}", file=sys.stderr)
            return 2
    else:
        print(rendered, end="")
    return status


if __name__ == "__main__":
    raise SystemExit(main())
