#!/usr/bin/env python3
"""Record the CVA6 regression tests that the upstream driver selects and check that every selected test left traces."""
import argparse
import ast
import hashlib
import json
import logging
import os
from pathlib import Path
import re
import sys
import yaml


def selection(testlist, simulation_directory, target):
    driver = Path(simulation_directory) / 'cva6.py'
    source = driver.read_text()
    node = next(n for n in ast.parse(source).body
                if isinstance(n, ast.FunctionDef) and n.name == 'openhw_process_regression_list')
    inputs = {}
    def read_yaml(name):
        path = Path(name).resolve()
        data = path.read_bytes()
        inputs[str(path)] = hashlib.sha256(data).hexdigest()
        return yaml.safe_load(data)
    scope = {'read_yaml': read_yaml, 're': re, 'logging': logging}
    exec(compile(ast.Module(body=[node], type_ignores=[]), str(driver), 'exec'), scope)
    selected = []
    original_cwd = Path.cwd()
    testlist = str(Path(testlist).resolve())
    simulation_directory = str(Path(simulation_directory).resolve())
    try:
        os.chdir(simulation_directory)
        scope['openhw_process_regression_list'](testlist, 'all', 1, selected, simulation_directory)
    finally:
        os.chdir(original_cwd)
    names = []
    for entry in selected:
        if 'asm_tests' not in entry or 'gen_test' in entry or 'c_tests' in entry or entry.get('needs'):
            raise ValueError('selection requires directed assembly without configuration conditions')
        if 'path_var' not in entry or 'gcc_opts' not in entry:
            raise ValueError('directed entry lacks the driver path fields')
        name = entry['test'] + '.' + target + '.log'
        if Path(name).name != name:
            raise ValueError('test output name is not a basename')
        names.append(name)
    if not names or len(names) != len(set(names)):
        raise ValueError('empty selection or duplicate logical trace names')
    return {'target': target, 'names': names, 'entries': selected, 'inputs': inputs,
            'driver': str(driver), 'driver_sha256': hashlib.sha256(source.encode()).hexdigest(),
            'selector_sha256': hashlib.sha256(ast.get_source_segment(source, node).encode()).hexdigest()}


def partition(original, shards):
    expected = set(original['names'])
    seen = set()
    for shard in shards:
        names = set(shard['names'])
        if seen & names:
            raise ValueError('overlapping shard selections')
        seen |= names
    if seen != expected:
        raise ValueError('shard selections do not equal the original selection')
    return {'complete': True, 'shards': len(shards), 'names': sorted(seen)}


def check(selected, rtl, spike, report, comparisons=None, alternate=None):
    expected = set(selected['names'])
    if alternate and (len(expected) != 1 or Path(alternate).name != alternate):
        raise ValueError('alternate RTL basename requires a single selected logical trace')
    rtl_names = {alternate} if alternate else expected
    mapping = {next(iter(expected)): alternate} if alternate else {name: name for name in expected}
    result = {'mapping': mapping, 'differences': {}}
    for label, directory, wanted, pattern in [('rtl', rtl, rtl_names, '*.log'), ('spike', spike, expected, '*.log')]:
        path = Path(directory)
        if not path.is_dir():
            raise ValueError(label + ' trace directory is missing')
        actual = {p.name for p in path.glob(pattern) if p.is_file()}
        if label == 'rtl' and alternate:
            result['ignored_rtl_names'] = sorted(actual - {alternate})
            actual = {alternate} if (path / alternate).is_file() else set()
        result['differences'][label] = {'missing': sorted(wanted - actual), 'extra': sorted(actual - wanted)}
    if comparisons is not None:
        wanted = {name.removesuffix('.log') + '.json' for name in rtl_names}
        actual = {p.name for p in Path(comparisons).glob('*.json') if p.is_file()}
        result['differences']['comparisons'] = {'missing': sorted(wanted - actual), 'extra': sorted(actual - wanted)}
    summaries = re.findall(r'^(\d+) PASSED, (\d+) FAILED$', Path(report).read_text(), re.M)
    if not summaries:
        raise ValueError('regression summary is missing')
    passed, failed = map(int, summaries[-1])
    result['summary'] = {'passed': passed, 'failed': failed}
    result['complete'] = passed + failed == len(expected) and not any(
        d['missing'] or d['extra'] for d in result['differences'].values())
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--testlist')
    parser.add_argument('--simulation-directory')
    parser.add_argument('--target', default='cv32a60x')
    parser.add_argument('--selection')
    parser.add_argument('--shard', action='append', default=[])
    parser.add_argument('--rtl')
    parser.add_argument('--spike')
    parser.add_argument('--report')
    parser.add_argument('--comparisons')
    parser.add_argument('--alternate', default='')
    args = parser.parse_args()
    try:
        if args.testlist:
            result = selection(args.testlist, args.simulation_directory, args.target)
        elif args.shard:
            result = partition(json.loads(Path(args.selection).read_text()),
                               [json.loads(Path(p).read_text()) for p in args.shard])
        else:
            result = check(json.loads(Path(args.selection).read_text()), args.rtl, args.spike,
                           args.report, args.comparisons, args.alternate)
        status = 0 if result.get('complete', True) else 2
    except (ValueError, OSError, KeyError, TypeError, RecursionError, yaml.YAMLError) as error:
        result = {'complete': False, 'error': str(error)}
        status = 2
    print(json.dumps(result, indent=2))
    return status


if __name__ == '__main__':
    sys.exit(main())
