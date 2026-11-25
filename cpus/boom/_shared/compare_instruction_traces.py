#!/usr/bin/env python3
"""Compare a BOOM commit trace with a Spike commit log and report PASS, FAIL or INVALID."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


TRACE = re.compile(
    r"(?:core\s+\d+:\s+)?([0-3])\s+0x([0-9a-fA-F]+)\s+"
    r"\(0x([0-9a-fA-F]+)\)"
)
REGISTER_UPDATE = re.compile(r"\b([xf]\s*\d+)\s+0x([0-9a-fA-F]+)")
MEMORY_UPDATE = re.compile(
    r"\bmem\s+0x([0-9a-fA-F]+)(?:\s+0x([0-9a-fA-F]+))?"
)
BOOM_MEMORY_TRACE = re.compile(
    r"^MT\s+[0-9a-fA-F]+\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)\s+"
    r"([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)\s+"
    r"([0-9a-fA-F]+)$"
)


def normalized_hex(value: str) -> str:
    return format(int(value, 16), "x") if value else ""


def standard_opcode(instruction: str) -> int:
    return int(instruction, 16) & 0x7F


def memory_operation(instruction: str) -> str | None:
    value = int(instruction, 16)
    if value & 0x3 != 0x3:
        quadrant = value & 0x3
        funct3 = value >> 13 & 0x7
        if quadrant in {0, 2} and funct3 in {1, 2, 3}:
            if quadrant == 2 and funct3 in {2, 3} and value >> 7 & 0x1F == 0:
                return None
            return "load"
        if quadrant in {0, 2} and funct3 in {5, 6, 7}:
            return "store"
        return None
    opcode = standard_opcode(instruction)
    if opcode in {0x03, 0x07}:
        return "load"
    if opcode in {0x23, 0x27}:
        return "store"
    if opcode == 0x0F:
        return "fence"
    if opcode == 0x2F:
        return "atomic"
    return None


def store_value(data: str, size: str) -> str:
    bits = 8 * (1 << int(size, 16))
    return format(int(data, 16) & ((1 << bits) - 1), "x")


def amo_value(instruction: str, old_data: str, operand: str) -> str:
    value = int(instruction, 16)
    bits = 32 if (value >> 12 & 0x7) == 2 else 64
    mask = (1 << bits) - 1
    lhs = int(old_data, 16) & mask
    rhs = int(operand, 16) & mask
    operation = value >> 27 & 0x1F

    def signed(item: int) -> int:
        return item - (1 << bits) if item >> (bits - 1) else item

    result = {
        0x00: lambda: lhs + rhs,
        0x01: lambda: rhs,
        0x04: lambda: lhs ^ rhs,
        0x08: lambda: lhs | rhs,
        0x0C: lambda: lhs & rhs,
        0x10: lambda: lhs if signed(lhs) < signed(rhs) else rhs,
        0x14: lambda: lhs if signed(lhs) > signed(rhs) else rhs,
        0x18: lambda: min(lhs, rhs),
        0x1C: lambda: max(lhs, rhs),
    }.get(operation)
    if result is None:
        raise ValueError(f"unsupported atomic operation: {operation:#x}")
    return format(result() & mask, "x")


def records(path: Path) -> list[tuple[str, ...]]:
    result = []
    boom_memories = []
    for line in path.read_text(errors="replace").splitlines():
        boom_memory = BOOM_MEMORY_TRACE.match(line)
        if boom_memory:
            boom_memories.append(boom_memory.groups())
            continue
        match = TRACE.search(line)
        if match:
            values = list(match.groups())
            updates = REGISTER_UPDATE.findall(line[match.end() :])
            values.extend(updates[-1] if updates else ("", ""))
            memories = MEMORY_UPDATE.findall(line[match.end() :])
            memory = next((item for item in reversed(memories) if item[1]), None)
            if memory is not None:
                values.extend(memory)
            else:
                values.extend(("", ""))
            if values[3]:
                values[3] = values[3].replace(" ", "")
            for index in (1, 2, 4, 5, 6):
                values[index] = normalized_hex(values[index])
            result.append(tuple(value.lower() if value else "" for value in values))
    memory_index = 0
    for index, values in enumerate(result):
        operation = memory_operation(values[2])
        if memory_index >= len(boom_memories) or operation is None:
            continue
        command, size, address, data, old_data = boom_memories[memory_index]
        if operation == "fence" and int(command, 16) != 0x04:
            continue
        memory_index += 1
        writes_memory = (
            operation == "store" and int(command, 16) in {0x01, 0x11}
        ) or (
            operation == "atomic"
            and int(command, 16) == 0x07
            and values[4] == "0"
        )
        if writes_memory:
            updated = list(values)
            updated[5] = normalized_hex(address)
            updated[6] = store_value(data, size)
            result[index] = tuple(updated)
        elif operation == "atomic" and int(command, 16) in {0x04, *range(0x08, 0x10)}:
            updated = list(values)
            updated[5] = normalized_hex(address)
            updated[6] = amo_value(values[2], old_data, data)
            result[index] = tuple(updated)
    return result


def test_completion_index(trace: list[tuple[str, ...]]) -> int | None:
    for index, record in enumerate(trace):
        if record[2] != "73":
            continue
        recent_updates = {
            prior[3]: prior[4]
            for prior in trace[max(0, index - 4) : index]
            if prior[3]
        }
        if recent_updates.get("x17") == "5d" and recent_updates.get("x10") == "0":
            return index
    return None


def rtl_test_passed(path: Path) -> bool:
    return "*** PASSED ***" in path.read_text(errors="replace")


def alignment(
    rtl: list[tuple[str, ...]], isa: list[tuple[str, ...]], window: int = 8
) -> tuple[int, int] | None:
    if len(rtl) < window or len(isa) < window:
        return None
    starts: dict[tuple[str, ...], list[int]] = {}
    for index, record in enumerate(isa):
        starts.setdefault(record, []).append(index)
    for rtl_index, record in enumerate(rtl):
        for isa_index in starts.get(record, []):
            if rtl[rtl_index : rtl_index + window] == isa[isa_index : isa_index + window]:
                return rtl_index, isa_index
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rtl_log", type=Path)
    parser.add_argument("isa_log", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    try:
        rtl = records(args.rtl_log)
        isa = records(args.isa_log)
    except OSError as error:
        output = json.dumps({
            "verdict": "INVALID",
            "reason": "trace_input_read_error",
            "error": str(error),
        }, indent=2) + "\n"
        if args.report:
            args.report.write_text(output)
        print(output, end="")
        return 2
    completion = test_completion_index(rtl)
    compared_rtl = rtl[:completion] if completion is not None else rtl
    start = alignment(compared_rtl, isa)
    mismatch = None
    ignored_rtl_traps = 0
    if start is not None:
        rtl_start, isa_start = start
        rtl_offset = isa_offset = 0
        while rtl_start + rtl_offset < len(compared_rtl):
            observed = compared_rtl[rtl_start + rtl_offset]
            expected = isa[isa_start + isa_offset] if isa_start + isa_offset < len(isa) else None
            if observed == expected:
                rtl_offset += 1
                isa_offset += 1
                continue
            # BOOM prints a retiring ECALL/EBREAK record.  Spike transfers to
            # the trap handler without emitting a commit-log record for that
            # instruction.  Ignore only that representational difference.
            if observed[2] in {"73", "100073"} and not observed[3]:
                ignored_rtl_traps += 1
                rtl_offset += 1
                continue
            mismatch = {"rtl_offset": rtl_offset, "isa_offset": isa_offset}
            break
    test_passed = rtl_test_passed(args.rtl_log)
    passed = (
        test_passed
        and bool(rtl)
        and bool(isa)
        and start is not None
        and mismatch is None
    )
    if not isa:
        reason = "isa_trace_empty"
    elif not test_passed:
        reason = "rtl_test_program_not_passed"
    elif not rtl:
        reason = "rtl_trace_empty"
    elif start is None:
        reason = "trace_alignment_missing"
    elif mismatch is not None:
        reason = "trace_record_mismatch"
    else:
        reason = "trace_match"
    report = {
        "rtl_test_program_passed": test_passed,
        "rtl_records": len(rtl),
        "rtl_compared_records": len(compared_rtl),
        "test_completion_index": completion,
        "isa_records": len(isa),
        "rtl_alignment_index": start[0] if start is not None else None,
        "isa_alignment_index": start[1] if start is not None else None,
        "first_mismatch_index": mismatch,
        "ignored_rtl_trap_records": ignored_rtl_traps,
        "verdict": "INVALID" if not isa else "PASS" if passed else "FAIL",
        "reason": reason,
    }
    if mismatch is not None:
        rtl_start, isa_start = start
        report["expected"] = isa[isa_start + mismatch["isa_offset"]] if isa_start + mismatch["isa_offset"] < len(isa) else None
        report["observed"] = compared_rtl[rtl_start + mismatch["rtl_offset"]]
    output = json.dumps(report, indent=2) + "\n"
    if args.report:
        args.report.write_text(output)
    print(output, end="")
    return 2 if not isa else 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
