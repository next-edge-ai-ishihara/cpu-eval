#!/usr/bin/env python3
"""Compare every directed retirement, allowing only its three cycle results."""
import argparse
from dataclasses import asdict
import importlib.util
import json
from pathlib import Path
import re
import sys


def parser_module():
    path = Path(__file__).resolve().parents[2] / 'harness/compare_architectural_traces.py'
    spec = importlib.util.spec_from_file_location('stride_trace_parser', path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def cycle_role(instruction):
    opcode = instruction & 0x7f
    rd = (instruction >> 7) & 31
    funct3 = (instruction >> 12) & 7
    rs1 = (instruction >> 15) & 31
    rs2 = (instruction >> 20) & 31
    if opcode == 0x73 and funct3 == 2 and rs1 == 0 and instruction >> 20 == 0xb00 and rd in (18, 19):
        return rd
    if opcode == 0x33 and funct3 == 0 and instruction >> 25 == 0x20 and (rd, rs1, rs2) == (20, 19, 18):
        return rd
    return None


def update_register_state(state, item):
    before = {}
    for register, value in item.register_updates:
        key = (item.hart, register)
        before.setdefault(key, state.get(key, 0))
        state[key] = value
    return {key for key, value in before.items() if state[key] != value}


class RtlTraceError(ValueError):
    """The RTL trace, which comes from the answer, cannot be compared."""


def compare(rtl_path, spike_path):
    module = parser_module()
    spike = module.parse_trace(spike_path)
    roles = [(i, cycle_role(item.instruction)) for i, item in enumerate(spike)
             if cycle_role(item.instruction) is not None]
    if [role for _, role in roles] != [18, 19, 20]:
        raise ValueError('directed cycle instruction sequence is missing or ambiguous')
    if roles[1][0] != roles[0][0] + 4 or roles[2][0] != roles[1][0] + 1:
        raise ValueError('directed cycle interval does not contain exactly three instructions')
    try:
        rtl = module.parse_trace(rtl_path, observed_rtl=True)
    except ValueError as error:
        raise RtlTraceError(str(error)) from error
    start = (spike[0].hart, spike[0].pc, spike[0].instruction)
    indices = [i for i, item in enumerate(rtl)
               if (item.hart, item.pc, item.instruction) == start]
    if not indices:
        raise RtlTraceError('RTL does not contain the Spike start instruction')
    boot = indices[0]
    post = max(0, len(rtl) - boot - len(spike))
    rtl = rtl[boot:boot + len(spike)]
    if len(rtl) != len(spike):
        raise RtlTraceError('RTL directed retirement trace is incomplete')
    mismatches = []
    values = {'rtl': {}, 'spike': {}}
    for name, trace in [('rtl', rtl), ('spike', spike)]:
        for index, role in roles:
            if index >= len(trace):
                continue
            item = trace[index]
            if cycle_role(item.instruction) != role:
                continue
            writes = [v for r, v in item.register_updates if r == role]
            if len(writes) != 1:
                error = RtlTraceError if name == 'rtl' else ValueError
                raise error(f'{name} cycle result write missing or duplicated at {index}')
            values[name][role] = writes[0]
    states = {'rtl': {}, 'spike': {}}
    role_by_index = dict(roles)
    for index in range(max(len(rtl), len(spike))):
        left = rtl[index] if index < len(rtl) else None
        right = spike[index] if index < len(spike) else None
        changed = set()
        ignored = set()
        for name, item in [('rtl', left), ('spike', right)]:
            if item is not None:
                changed |= update_register_state(states[name], item)
                role = role_by_index.get(index)
                if role is not None and cycle_role(item.instruction) == role:
                    ignored.add((item.hart, role))


        differences = [
            {'hart': hart, 'register': register,
             'rtl': states['rtl'].get((hart, register), 0),
             'spike': states['spike'].get((hart, register), 0)}
            for hart, register in sorted(changed - ignored)
            if states['rtl'].get((hart, register), 0) != states['spike'].get((hart, register), 0)
        ]
        identity_differs = left is None or right is None or (
            left.hart, left.pc, left.instruction, left.memory_updates
        ) != (right.hart, right.pc, right.instruction, right.memory_updates)
        if identity_differs or differences:
            mismatches.append({'index': index, 'rtl': asdict(left) if left else None,
                               'spike': asdict(right) if right else None,
                               'register_state_differences': differences})
    for name in ['rtl', 'spike']:
        v = values[name]
        if len(v) == 3 and v[20] != ((v[19] - v[18]) & 0xffffffff):
            mismatches.append({'reason': 'cycle_subtraction_inconsistent', 'trace': name, 'values': v})
    return {'verdict': 'FAIL' if mismatches else 'PASS',
            'rtl_instruction_count': len(rtl), 'spike_instruction_count': len(spike),
            'rtl_boot_instruction_count': boot, 'rtl_post_termination_instruction_count': post,
            'allowed_cycle_instruction_indices': [i for i, _ in roles],
            'allowed_cycle_instructions': [
                {'index': i, 'pc': spike[i].pc, 'register': role}
                for i, role in roles],
            'cycle_values': values, 'mismatch_count': len(mismatches), 'mismatches': mismatches}


def check_completion(directory, shared_rc, runner_log, result):
    text = runner_log.read_text()
    if re.search(r'(?m)^CPU_CYCLE_LIMIT:|^FAIL: CPU reached the fixed RVFI cycle limit$', text):
        return 'shared_cpu_cycle_limit'
    if int((directory / 'exit-code.txt').read_text()) != shared_rc:
        raise ValueError('shared exit-code record disagrees with the invocation')
    if int((directory / 'run.exit-code.txt').read_text()) != 0:
        return 'shared_regression_process_failure'
    report = (directory / 'iss_regr.log').read_text()
    summaries = re.findall(r'(?m)^(\d+) PASSED, (\d+) FAILED$', report)
    trace_summaries = re.findall(r'(?m)^(\d+) TRACE PASSED, (\d+) TRACE FAILED$', report)
    if len(summaries) != 1 or len(trace_summaries) != 1:
        raise ValueError('one completed directed regression and trace summary required')
    passed, failed = map(int, summaries[0])
    trace_passed, trace_failed = map(int, trace_summaries[0])
    if passed + failed != 1 or trace_passed + trace_failed != 1:
        raise ValueError('directed run must complete exactly one test and trace')
    if shared_rc == 0:
        return None if failed == trace_failed == 0 else 'shared_failure_with_success_exit'
    final = f'FAIL: {passed} PASSED, {failed} FAILED; {trace_failed} of 1 complete architectural traces mismatched'
    if final not in text.splitlines():
        return 'shared_failure_not_identified_as_completed_comparison'
    if failed == 0:
        return None
    # The fixed CSV comparator prints at most five mismatches. A permitted
    # failure has at most three, all printed and tied to the actual cycle PCs.
    failed_rows = re.findall(r'(?m)^\[FAILED\]: \d+ matched, (\d+) mismatch\s*$', report)
    blocks = re.findall(r'(?m)^Mismatch\[(\d+)\]:\n([^\n]+)\n([^\n]+)', report)
    if not failed_rows or any(int(n) != len(blocks) for n in failed_rows) or not 1 <= len(blocks) <= 3:
        return 'shared_regression_failure_not_limited_to_cycle_results'
    if [int(number) for number, _, _ in blocks] != list(range(1, len(blocks) + 1)):
        return 'shared_regression_mismatch_sequence'
    roles = {item['pc']: item['register'] for item in result['allowed_cycle_instructions']}
    seen_roles = set()
    for number, first, second in blocks:
        labels = set()
        pair_roles = set()
        for line in [first, second]:
            row = re.fullmatch(r'(spike|veri-testharness)\[\d+\] : pc\[([0-9a-fA-F]+)\] (.+)', line)
            if row is None:
                return 'shared_regression_unrecognized_mismatch'
            label, pc, body = row.groups()
            labels.add(label)
            role = roles.get(int(pc, 16))
            pair_roles.add(role)
            if role in (18, 19):
                alias = f's{role - 16}'
                pattern = rf'csrr(?:s)?\s+{alias},\s*mcycle(?:,\s*zero)?:\s+{alias}:([0-9a-fA-F]+)\s*'
            elif role == 20:
                pattern = r'sub\s+s4,\s*s3,\s*s2:\s+s4:([0-9a-fA-F]+)\s*'
            else:
                return 'shared_regression_noncycle_mismatch'
            value = re.fullmatch(pattern, body)
            trace = 'spike' if label == 'spike' else 'rtl'
            if value is None or int(value[1], 16) != result['cycle_values'][trace].get(role):
                return 'shared_regression_noncycle_or_inconsistent_effect'
        if labels != {'spike', 'veri-testharness'}:
            return 'shared_regression_mismatch_pair'
        if len(pair_roles) != 1 or pair_roles & seen_roles:
            return 'shared_regression_mismatch_cycle_identity'
        seen_roles |= pair_roles
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--shared-return-code', type=int, choices=(0, 1))
    parser.add_argument('--runner-log', type=Path)
    args = parser.parse_args()
    if (args.shared_return_code is None) != (args.runner_log is None):
        raise ValueError('shared return code and runner log must be supplied together')
    paths = []
    for name in ['rtl', 'spike']:
        files = list((args.run_directory / 'raw-architectural-traces' / name).glob('*.log'))
        if len(files) != 1:
            raise ValueError(f'exactly one {name} raw directed trace required')
        paths.append(files[0])
    try:
        result = compare(*paths)
    except RtlTraceError as error:
        args.output.write_text(json.dumps({'verdict': 'FAIL', 'rtl_trace_error': str(error)}, indent=2) + '\n')
        print(f'DIRECTED_SEMANTIC_FAIL rtl_trace_error={error}')
        return 1
    if args.shared_return_code is not None:
        reason = check_completion(args.run_directory, args.shared_return_code, args.runner_log, result)
        result['shared_completion_failure'] = reason
        if reason is not None:
            result['mismatches'].append({'reason': reason})
            result['mismatch_count'] += 1
            result['verdict'] = 'FAIL'
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    delta = result['cycle_values']['rtl'].get(20)
    print(f'RTL_CYCLE_DELTA={delta}')
    print(f"DIRECTED_SEMANTIC_{result['verdict']} instructions={result['spike_instruction_count']} mismatches={result['mismatch_count']}")
    return 1 if result['mismatch_count'] else 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f'INVALID: {error}')
        raise SystemExit(2)
