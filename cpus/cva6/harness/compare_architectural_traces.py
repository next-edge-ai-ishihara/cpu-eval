#!/usr/bin/env python3


from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path


INSTRUCTION_RE = re.compile(
    r"^core\s+(?:INTERRUPT\s+)?(?P<hart>\d+):\s+0x(?P<pc>[0-9a-fA-F]+)\s+"
    r"\(0x(?P<instruction>[0-9a-fA-F]+)\)"
)
EFFECT_RE = re.compile(
    r"^(?:core\s+\d+:\s+)?\d+\s+0x(?P<pc>[0-9a-fA-F]+)\s+"
    r"\(0x(?P<instruction>[0-9a-fA-F]+)\)(?P<effect>.*)$"
)
EXCEPTION_RE = re.compile(
    r"^[A-Z_]+ exception @ 0x(?P<pc>[0-9a-fA-F]+) "
    r"\(0x(?P<instruction>[0-9a-fA-F]+)\)$"
)
REGISTER_RE = re.compile(r"(?:^|\s)x\s*(?P<register>\d+)\s+0x(?P<value>[0-9a-fA-F]+)(?:\s|$)")
MEMORY_RE = re.compile(
    r"(?:^|\s)mem\s+0x(?P<address>[0-9a-fA-F]+)\s+"
    r"0x(?P<value>[0-9a-fA-F]+)(?:\s|$)"
)


@dataclass
class RetiredInstruction:
    hart: int
    pc: int
    instruction: int
    register_updates: list[tuple[int, int]] = field(default_factory=list)
    memory_updates: list[tuple[int, int]] = field(default_factory=list)


def architectural_instruction_bits(instruction: int) -> int:
    """CVA6 trace lines may include an adjacent halfword with a compressed instruction."""
    if instruction & 0b11 != 0b11:
        return instruction & 0xFFFF
    return instruction


def memory_update_mask(instruction: int) -> int:
    if instruction & 0b11 != 0b11:
        funct3 = (instruction >> 13) & 0b111
        if funct3 == 0b110:
            return 0xFFFFFFFF
        if funct3 == 0b111:
            return 0xFFFFFFFFFFFFFFFF
        raise ValueError(f"memory update belongs to unsupported compressed instruction 0x{instruction:x}")
    opcode = instruction & 0x7F
    width_code = (instruction >> 12) & 0b111
    if opcode == 0x23:
        widths = {0: 1, 1: 2, 2: 4, 3: 8}
    elif opcode == 0x2F:
        widths = {2: 4, 3: 8}
    else:
        raise ValueError(f"memory update belongs to non-writing instruction 0x{instruction:x}")
    if width_code not in widths:
        raise ValueError(f"unsupported memory-update width in instruction 0x{instruction:x}")
    return (1 << (8 * widths[width_code])) - 1


def parse_trace(path: Path, *, observed_rtl: bool = False) -> list[RetiredInstruction]:
    retired: list[RetiredInstruction] = []
    current: RetiredInstruction | None = None
    for line_number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        instruction_match = INSTRUCTION_RE.match(line)
        if instruction_match:
            current = RetiredInstruction(
                hart=int(instruction_match.group("hart")),
                pc=int(instruction_match.group("pc"), 16),
                instruction=architectural_instruction_bits(
                    int(instruction_match.group("instruction"), 16)
                ),
            )
            retired.append(current)
            continue

        exception_match = EXCEPTION_RE.match(line)
        if exception_match:
            current = RetiredInstruction(
                hart=0,
                pc=int(exception_match.group("pc"), 16),
                instruction=int(exception_match.group("instruction"), 16),
            )
            retired.append(current)
            continue

        effect_match = EFFECT_RE.match(line)
        if not effect_match:
            continue
        if current is None:
            raise ValueError(f"{path}:{line_number}: effect precedes the first instruction")
        effect_pc = int(effect_match.group("pc"), 16)
        effect_instruction = architectural_instruction_bits(
            int(effect_match.group("instruction"), 16)
        )
        if (effect_pc, effect_instruction) != (current.pc, current.instruction):
            raise ValueError(f"{path}:{line_number}: effect does not belong to the preceding instruction")

        effect = effect_match.group("effect")
        register_match = REGISTER_RE.search(effect)
        if register_match:
            register = int(register_match.group("register"))
            value = int(register_match.group("value"), 16)
            current.register_updates.append((register, value))
        memory_match = MEMORY_RE.search(effect)
        if memory_match:
            value = int(memory_match.group("value"), 16)
            try:
                value &= memory_update_mask(current.instruction)
            except ValueError:
                # The reference must supply a known store width. An unexpected
                # RTL write can be compared to the absence of a reference write.
                if not observed_rtl:
                    raise
            current.memory_updates.append(
                (int(memory_match.group("address"), 16), value)
            )
            continue
        # A load's one-operand ``mem <address>`` line describes an access, not
        # an architectural memory update. Other trace annotations are ignored.

    if not retired and not observed_rtl:
        raise ValueError(f"{path}: no retired instructions found")
    return retired


def remove_idempotent_register_writes(retired: list[RetiredInstruction]) -> None:
    register_state = {index: 0 for index in range(32)}
    for item in retired:
        updates = []
        for register, value in item.register_updates:
            if register_state[register] != value:
                updates.append((register, value))
            register_state[register] = value
        item.register_updates = updates


def compare(rtl_path: Path, spike_path: Path) -> dict[str, object]:
    spike = parse_trace(spike_path)
    try:
        rtl = parse_trace(rtl_path, observed_rtl=True)
    except ValueError as error:
        # The RTL trace comes from the answer, so a malformed one is a mismatch.
        return {"verdict": "FAIL_TRACE_MISMATCH", "rtl_trace_error": str(error),
                "spike_instruction_count": len(spike), "mismatch_count": len(spike)}
    spike_start = (spike[0].pc, spike[0].instruction)
    try:
        rtl_start_index = next(
            index
            for index, item in enumerate(rtl)
            if (item.pc, item.instruction) == spike_start
        )
    except StopIteration:
        rtl_start_index = 0
    rtl_boot_instruction_count = rtl_start_index
    rtl = rtl[rtl_start_index:]
    rtl_post_termination_instruction_count = max(0, len(rtl) - len(spike))
    rtl = rtl[: len(spike)]
    remove_idempotent_register_writes(rtl)
    remove_idempotent_register_writes(spike)
    mismatch_indices = [
        index
        for index, pair in enumerate(zip(rtl, spike))
        if pair[0] != pair[1]
    ]
    if len(rtl) < len(spike):
        mismatch_indices.extend(range(min(len(rtl), len(spike)), max(len(rtl), len(spike))))
    mismatches = []
    for index in mismatch_indices[:20]:
        mismatches.append(
            {
                "index": index,
                "rtl": asdict(rtl[index]) if index < len(rtl) else None,
                "spike": asdict(spike[index]) if index < len(spike) else None,
            }
        )
    return {
        "verdict": "PASS" if not mismatch_indices else "FAIL_TRACE_MISMATCH",
        "rtl_instruction_count": len(rtl),
        "spike_instruction_count": len(spike),
        "rtl_boot_instruction_count": rtl_boot_instruction_count,
        "rtl_post_termination_instruction_count": rtl_post_termination_instruction_count,
        "rtl_register_update_count": sum(len(item.register_updates) for item in rtl),
        "spike_register_update_count": sum(len(item.register_updates) for item in spike),
        "rtl_memory_update_count": sum(len(item.memory_updates) for item in rtl),
        "spike_memory_update_count": sum(len(item.memory_updates) for item in spike),
        "mismatch_count": len(mismatch_indices),
        "mismatches": mismatches,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("rtl_trace", type=Path)
    parser.add_argument("spike_trace", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = compare(args.rtl_trace, args.spike_trace)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
