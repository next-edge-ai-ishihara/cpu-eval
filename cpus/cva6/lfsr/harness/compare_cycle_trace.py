#!/usr/bin/env python3

import argparse
from copy import deepcopy
from dataclasses import asdict
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'harness'))
from compare_architectural_traces import parse_trace, remove_idempotent_register_writes


def timing_instructions(spike):
    by_pc = {}
    for item in spike:
        by_pc.setdefault(item.pc, []).append(item)
    candidates = []
    for first in spike:
        if first.instruction != 0xB0002973:  # csrr x18, mcycle
            continue
        roles = {}
        for access in range(5):
            pc = first.pc + access * 20
            rd = 20 + access
            words = {pc: (0xB0002973, 18, 'start'),
                     pc + 8: (0xB00029F3, 19, 'end'),
                     pc + 12: (0x41298033 | rd << 7, rd, 'sub'),
                     pc + 16: (0x06400013 | rd << 15 | rd << 7, rd, 'addi')}
            call = by_pc.get(pc + 4, [])
            if len(call) != 1 or call[0].instruction & 0xFFF != 0xEF:
                break
            if any(len(by_pc.get(address, [])) != 1 or by_pc[address][0].instruction != word
                   for address, (word, _, _) in words.items()):
                break
            for address, (_, register, role) in words.items():
                roles[address] = (register, role, access)
        else:
            candidates.append(roles)
    if len(candidates) != 1:
        raise ValueError('the fixed five csrr/jal/csrr/sub/addi accesses are not uniquely present')
    return candidates[0]


class SpikeTraceError(ValueError):
    """The Spike trace of the fixed program cannot be used."""


def compare(rtl_path, spike_path, expected):
    try:
        spike = parse_trace(Path(spike_path))
        roles = timing_instructions(spike)
    except ValueError as error:
        raise SpikeTraceError(str(error)) from error
    rtl_all = parse_trace(Path(rtl_path), observed_rtl=True)
    if not rtl_all:
        raise ValueError('the RTL trace contains no retired instructions')
    start = (spike[0].pc, spike[0].instruction)
    first = next((n for n, item in enumerate(rtl_all) if (item.pc, item.instruction) == start), 0)
    rtl = rtl_all[first:first + len(spike)]
    values = {}
    arithmetic_errors = []


    state = {register: 0 for register in range(32)}
    observations = []
    for item in rtl:
        role = roles.get(item.pc)
        if role:
            register, kind, access = role
            updates = [value for rd, value in item.register_updates if rd == register]
            if len(updates) > 1:
                arithmetic_errors.append({'pc': item.pc, 'error': 'multiple effects for the timing destination'})
            value = updates[-1] if updates else state[register]
            if kind == 'sub':
                wanted = (state[19] - state[18]) & 0xFFFFFFFF
            elif kind == 'addi':
                wanted = (state[register] + 100) & 0xFFFFFFFF
                values[register] = value
            else:
                wanted = value
            if value != wanted:
                arithmetic_errors.append({'pc': item.pc, 'value': value, 'expected': wanted})
            observations.append({'pc': item.pc, 'register': register, 'role': kind,
                                 'access': access, 'value': value})
        for register, value in item.register_updates:
            state[register] = value
    rtl_normal = deepcopy(rtl)
    spike_normal = deepcopy(spike)
    # The fixed program writes x18..x24 only at these timing instructions.
    # Preserve any effect on those registers elsewhere: filtering with a
    # cleared timing state could otherwise hide an unexpected write of zero.
    for trace in [rtl_normal, spike_normal]:
        retained = []
        for item in trace:
            role = roles.get(item.pc)
            if role:
                item.register_updates = [(rd, value) for rd, value in item.register_updates if rd != role[0]]
            retained.append([(rd, value) for rd, value in item.register_updates if 18 <= rd <= 24])
        remove_idempotent_register_writes(trace)
        for item, timing_register_effects in zip(trace, retained):
            item.register_updates = [(rd, value) for rd, value in item.register_updates if not 18 <= rd <= 24]
            item.register_updates.extend(timing_register_effects)
    mismatches = []
    for index in range(max(len(rtl_normal), len(spike_normal))):
        lhs = rtl_normal[index] if index < len(rtl_normal) else None
        rhs = spike_normal[index] if index < len(spike_normal) else None
        if lhs != rhs:
            mismatches.append({'index': index, 'rtl': asdict(lhs) if lhs else None,
                               'spike': asdict(rhs) if rhs else None})
    vector = [values.get(register) for register in range(20, 25)]
    if None in vector or len(observations) != 20:
        raise ValueError('the complete five-access timing observation is missing')
    passed = not mismatches and not arithmetic_errors and vector == expected
    return {'verdict': 'PASS' if passed else 'FAIL', 'cycle_vector': vector,
            'expected_cycle_vector': expected, 'timing_observations': observations,
            'non_timing_mismatch_count': len(mismatches), 'non_timing_mismatches': mismatches,
            'arithmetic_errors': arithmetic_errors, 'rtl_instruction_count': len(rtl),
            'spike_instruction_count': len(spike), 'rtl_boot_instruction_count': first,
            'rtl_post_termination_instruction_count': max(0, len(rtl_all) - first - len(spike))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('rtl_trace', type=Path)
    parser.add_argument('spike_trace', type=Path)
    parser.add_argument('--expected', default='108,112,117,115,108')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        expected = [int(value) for value in args.expected.split(',')]
        if len(expected) != 5:
            raise SpikeTraceError('expected cycle vector must contain five values')
        result = compare(args.rtl_trace, args.spike_trace, expected)
        status = 0 if result['verdict'] == 'PASS' else 1
    except (SpikeTraceError, OSError) as error:
        result = {'verdict': 'INVALID', 'error': str(error)}
        status = 2
    except ValueError as error:
        # The Spike side is usable, so an unreadable or incomplete RTL trace is the answer's.
        result = {'verdict': 'FAIL', 'error': str(error)}
        status = 1
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    if 'cycle_vector' in result:
        print('RTL_CYCLE_VECTOR=' + ','.join(map(str, result['cycle_vector'])))
    print(result['verdict'] + ': fixed timing accesses and remaining architectural trace')
    return status


if __name__ == '__main__':
    sys.exit(main())
