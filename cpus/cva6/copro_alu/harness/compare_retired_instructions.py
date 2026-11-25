#!/usr/bin/env python3


from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path


RETIRED = re.compile(
    r"^(?:core\s+\d+:\s+)?3\s+0x(?P<pc>[0-9a-fA-F]+)\s+"
    r"\(0x(?P<instruction>[0-9a-fA-F]+)\)(?P<update>.*)$"
)
REGISTER_UPDATE = re.compile(
    r"^\s*(?P<bank>[xf])\s*(?P<register>\d+)\s+0x(?P<value>[0-9a-fA-F]+)"
    r"(?:\s+mem\s+0x[0-9a-fA-F]+)?\s*$"
)
MEMORY_UPDATE = re.compile(
    r"^\s*mem\s+0x(?P<address>[0-9a-fA-F]+)\s+0x(?P<value>[0-9a-fA-F]+)\s*$"
)
CSR_WRITE = re.compile(r"^\s*c(?P<csr>\d+)_[a-zA-Z0-9_]+\s+0x[0-9a-fA-F]+\s*$")


class InvalidComparison(Exception):
    """The Spike trace, the ELF or a tool cannot be used to judge the RTL trace."""


def is_cvxif_r4(instruction: int) -> bool:
    return (instruction & 0x0600707F) in {0x43, 0x47, 0x4B, 0x4F}


def store_mask(instruction: int) -> int:
    if instruction & 0b11 != 0b11:
        funct3 = (instruction >> 13) & 0b111
        widths = {0b110: 4, 0b111: 8}
        if funct3 not in widths:
            raise ValueError(
                f"memory update belongs to unsupported compressed instruction 0x{instruction:x}"
            )
        width = widths[funct3]
    else:
        if instruction & 0x7F != 0x23:
            raise ValueError(
                f"memory update belongs to non-store instruction 0x{instruction:x}"
            )
        width_code = (instruction >> 12) & 0b111
        widths = {0: 1, 1: 2, 2: 4, 3: 8}
        if width_code not in widths:
            raise ValueError(f"unsupported store width in instruction 0x{instruction:x}")
        width = widths[width_code]
    return (1 << (8 * width)) - 1


def parse(path: Path, *, rtl: bool) -> list[tuple[int, int, tuple[object, ...] | None]]:
    result = []
    for line in path.read_text(errors="replace").splitlines():
        match = RETIRED.match(line.strip())
        if not match and re.match(r"^(?:core\s+\d+:\s+)?3\s+0x", line.strip()):
            raise ValueError(f"unrecognized machine-mode retirement: {line}")
        if match:
            instruction = int(match.group("instruction"), 16)
            update_text = match.group("update")
            register = REGISTER_UPDATE.match(update_text)
            memory = MEMORY_UPDATE.match(update_text)
            csr_write = CSR_WRITE.match(update_text)
            update: tuple[object, ...] | None = None
            if register:
                bank = register.group("bank")
                # The CVA6 text tracer decodes the four CV-X-IF R4 opcodes as
                # floating-point instructions even though RVFI reports their
                # coprocessor result on the integer writeback port.
                if rtl and bank == "f" and is_cvxif_r4(instruction):
                    bank = "x"
                update = (
                    "register",
                    bank,
                    int(register.group("register")),
                    int(register.group("value"), 16),
                )
            elif memory:
                update = (
                    "memory",
                    int(memory.group("address"), 16),
                    int(memory.group("value"), 16) & store_mask(instruction),
                )
            elif csr_write:
                # Spike prints CSR writes; CVA6's text tracer prints only the
                # retired instruction. CSR values read by instructions remain
                # register updates and are compared normally.
                csr = int(csr_write.group("csr"))
                explicit_write = (
                    instruction & 0x7f == 0x73
                    and ((instruction >> 12) & 7) in {1, 2, 3, 5, 6, 7}
                    and ((instruction >> 7) & 31) == 0
                    and csr == instruction >> 20
                )
                mret_status_write = instruction == 0x30200073 and csr == 0x300
                if rtl or not (explicit_write or mret_status_write):
                    raise ValueError(f"unrecognized CSR update: {line}")
            elif update_text.strip():
                raise ValueError(f"unrecognized architectural update: {line}")
            result.append((int(match.group("pc"), 16), instruction, update))
    return result


def halt_symbols(elf: Path) -> tuple[int, int]:
    symbols = subprocess.run(
        ["readelf", "--symbols", "--wide", str(elf)],
        check=True, capture_output=True, text=True,
    ).stdout
    addresses: dict[str, set[int]] = {"tohost": set(), "self_loop": set()}
    for line in symbols.splitlines():
        fields = line.split()
        if len(fields) >= 8 and fields[7] in addresses and fields[6] != "UND":
            addresses[fields[7]].add(int(fields[1], 16))
    if any(len(values) != 1 for values in addresses.values()):
        raise ValueError("halt ELF must define unique tohost and self_loop symbols")
    return next(iter(addresses["tohost"])), next(iter(addresses["self_loop"]))


def test_elf(test_list: Path, test_name: str, output: Path) -> Path:

    import yaml

    entries = yaml.safe_load(test_list.read_text())
    if isinstance(entries, dict):
        entries = entries["testlist"]
    matches = [
        entry for entry in entries
        if entry["test"] == test_name or (
            not any(key in entry for key in ("asm_tests", "c_tests"))
            and re.fullmatch(re.escape(entry["test"]) + r"_\d+", test_name)
        )
    ]
    if len(matches) != 1:
        raise ValueError(f"expected one test-list entry for {test_name}")
    entry = matches[0]
    if "asm_tests" in entry:
        source = Path(os.path.expanduser(entry["asm_tests"].replace(
            "<path_var>", os.environ[entry["path_var"]]
        )))
        if source.suffix == ".o":
            return source
        return output / "directed_tests" / (source.stem + ".o")
    if "c_tests" in entry:
        return output / "directed_tests" / (test_name + ".o")
    return output / "asm_tests" / (test_name + ".o")


def validate_test_outputs(test_list: Path, output: Path) -> dict[str, object]:

    import yaml

    entries = yaml.safe_load(test_list.read_text())
    if isinstance(entries, dict):
        entries = entries["testlist"]
    expected = []
    for entry in entries:
        if "import" in entry:
            raise ValueError("test-list imports are unsupported")
        if entry["iterations"] <= 0:
            continue
        needs = {}
        for condition in entry.get("needs", []):
            needs.update(condition)
        if needs:
            raise ValueError("hardware-configuration conditions are unsupported")
        name = entry["test"]
        if not isinstance(name, str) or not name or Path(name).name != name:
            raise ValueError("test names must be nonempty file names")
        # --seed=1 selects one iteration. Directed tests use the test name;
        # generated tests append the iteration index in the pinned driver.
        if not any(key in entry for key in ("asm_tests", "c_tests")):
            name += "_0"
        expected.append(name + ".cv32a60x.log")
    if not expected or len(expected) != len(set(expected)):
        raise ValueError("expected test output names are empty or duplicated")
    observed = {
        simulator: sorted(path.name for path in (output / simulator).glob("*.log"))
        for simulator in ("spike_sim", "veri-testharness_sim")
    }
    result = {"expected": sorted(expected), "observed": observed}
    if any(names != sorted(expected) for names in observed.values()):
        raise ValueError("test output set differs from the selected test list: " + json.dumps(result))
    return result


def compare(
    rtl_path: Path, spike_path: Path, *, halt_elf: Path | None = None
) -> dict[str, object]:
    try:
        spike = parse(spike_path, rtl=False)
        if not spike:
            raise ValueError("Spike log contains no retired instructions")
        loop_pc = None
        if halt_elf is not None:
            tohost, loop_pc = halt_symbols(halt_elf)
            pc, instruction, update = spike[-1]
            # The selected model_test.h halts with sw x1,tohost,t1, then j self_loop.
            if (
                instruction & 0x707F != 0x2023
                or (instruction >> 20) & 0x1F != 1
                or update != ("memory", tohost, 1)
                or pc + 4 != loop_pc
            ):
                raise ValueError("Spike trace does not finish at the successful halt store")
        raw_lines = rtl_path.read_text(errors="replace").splitlines()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise InvalidComparison(str(error)) from error
    rtl = parse(rtl_path, rtl=True)

    start_pc = spike[0][0]
    try:
        rtl_start = next(index for index, item in enumerate(rtl) if item[0] == start_pc)
    except StopIteration as error:
        raise ValueError(f"RTL log does not reach Spike start PC 0x{start_pc:x}") from error

    rtl_test = rtl[rtl_start : rtl_start + len(spike)]
    rtl_tail = rtl[rtl_start + len(spike) :]
    mismatches = []
    for index, (rtl_item, spike_item) in enumerate(zip(rtl_test, spike)):
        if rtl_item != spike_item:
            mismatches.append(
                {
                    "index": index,
                    "rtl_pc": f"0x{rtl_item[0]:x}",
                    "rtl_instruction": f"0x{rtl_item[1]:08x}",
                    "rtl_update": rtl_item[2],
                    "spike_pc": f"0x{spike_item[0]:x}",
                    "spike_instruction": f"0x{spike_item[1]:08x}",
                    "spike_update": spike_item[2],
                }
            )

    if len(rtl_test) != len(spike):
        mismatches.append(
            {
                "kind": "length",
                "rtl_test_instructions": len(rtl_test),
                "spike_instructions": len(spike),
            }
        )

    raw_retired = [
        match for line in raw_lines
        if (match := RETIRED.match(line.strip()))
    ]
    allowed_loop_count = 0
    for index, (item, raw) in enumerate(
        zip(rtl_tail, raw_retired[rtl_start + len(spike) :])
    ):
        if (
            loop_pc is None
            or item[0] != loop_pc
            or item[1] not in {0xA001, 0x0000006F}
            or raw.group("update").strip()
        ):
            mismatches.append(
                {"kind": "rtl_tail", "index": index,
                 "pc": f"0x{item[0]:x}", "instruction": f"0x{item[1]:x}",
                 "raw_update": raw.group("update").strip()}
            )
        else:
            allowed_loop_count += 1

    retirement_lines = [
        index for index, line in enumerate(raw_lines) if RETIRED.match(line.strip())
    ]
    if len(rtl_test) == len(spike):
        last_compared_line = retirement_lines[rtl_start + len(spike) - 1]
        for line in raw_lines[last_compared_line + 1 :]:
            if "exception @" in line or re.match(
                r"^(?:core\s+\d+:\s+)?[012]\s+0x", line.strip()
            ):
                mismatches.append({"kind": "rtl_tail_event", "raw_line": line})

    return {
        "rtl_boot_instructions_excluded": rtl_start,
        "rtl_tail_instructions": len(rtl_tail),
        "rtl_halt_loop_instructions": allowed_loop_count,
        "rtl_test_instructions": len(rtl_test),
        "spike_instructions": len(spike),
        "rtl_register_updates": sum(
            item[2] is not None and item[2][0] == "register" for item in rtl_test
        ),
        "spike_register_updates": sum(
            item[2] is not None and item[2][0] == "register" for item in spike
        ),
        "rtl_memory_updates": sum(
            item[2] is not None and item[2][0] == "memory" for item in rtl_test
        ),
        "spike_memory_updates": sum(
            item[2] is not None and item[2][0] == "memory" for item in spike
        ),
        "mismatch_count": len(mismatches),
        "mismatches": mismatches[:20],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rtl_log", type=Path)
    parser.add_argument("spike_log", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--halt-elf", type=Path,
        help="ELF using sw x1,tohost then self_loop; allow only that halt loop tail",
    )
    args = parser.parse_args()

    status = None
    try:
        result = compare(args.rtl_log, args.spike_log, halt_elf=args.halt_elf)
    except InvalidComparison as error:
        result, status = {"invalid": str(error)}, 2
    except ValueError as error:
        result = {"error": str(error), "mismatch_count": 1}
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    raise SystemExit(status if status is not None else 1 if result["mismatch_count"] else 0)


if __name__ == "__main__":
    main()
