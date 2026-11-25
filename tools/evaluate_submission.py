#!/usr/bin/env python3
"""Evaluate CPU-Eval answers, or show archived verdicts and comparison errors."""

import argparse
from collections import deque
import csv
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import uuid

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/evaluation'))
from prepare_evaluation_job import problem_rows
ERROR = re.compile(r'mismatch|missmatch|Failed at| ref pc=|FAILURE|expected.*(?:actual|got|observed)|(?:actual|got|observed).*expected', re.I)
COMPILE_ERROR = re.compile(r'^\[error\]|%Error')


def show(archive):
    verdicts = []
    partial_verdicts = []
    expected = set()
    collection_error = False
    with tarfile.open(archive, 'r:*') as stored:
        passed = set()
        for member in stored:
            if member.isfile() and member.name.endswith('/evaluation-verdicts.tsv'):
                with stored.extractfile(member) as raw:
                    passed.update(f"{Path(member.name).parent}/driver/{row['problem']}__sample-{int(row['sample_index']):02d}/"
                                  for row in csv.DictReader(io.TextIOWrapper(raw), delimiter='\t')
                                  if row['verdict'] == 'PASS')
    with tarfile.open(archive, 'r:*') as stored:
        for member in stored:
            if not member.isfile():
                continue
            if member.name.endswith('/verdict-collection.error.log'):
                collection_error = True
            if member.name.endswith('/evaluation-verdicts.tsv'):
                with stored.extractfile(member) as raw:
                    for row in csv.DictReader(io.TextIOWrapper(raw), delimiter='\t'):
                        row['archive_evidence'] = str(Path(member.name).parent / row['evidence'])
                        verdicts.append(row)
            elif member.name.endswith(('.log', '.txt', '.tsv', '.json')) and not any(
                    member.name.startswith(directory) for directory in passed):
                value = None
                if member.name.endswith('.json') and member.size < 1048576:
                    with stored.extractfile(member) as raw:
                        try:
                            value = json.load(raw)
                        except ValueError:
                            pass
                if member.name.endswith(('/verdict.json', '/evaluation-verdict.json')):
                    if isinstance(value, dict) and isinstance(value.get('verdict'), str):
                        partial_verdicts.append((member.name, value))
                if member.name.endswith('/invocation.json') and isinstance(value, dict):
                    if isinstance(value.get('problems'), list) and isinstance(value.get('sample_count'), int):
                        expected.update((problem, sample) for problem in value['problems']
                                        for sample in range(value['sample_count']))
                if isinstance(value, dict) and isinstance(value.get('mismatches'), list):
                    if value['mismatches']:
                        print(f'\n{archive}:{member.name}')
                        print(json.dumps(value, indent=2))
                    continue
                if isinstance(value, dict) and value.get('first_mismatch_index') is not None:
                    print(f'\n{archive}:{member.name}')
                    print(json.dumps(value, indent=2))
                    continue
                with stored.extractfile(member) as raw:
                    context = deque(maxlen=3)
                    remaining = 0
                    for number, line in enumerate(io.TextIOWrapper(raw, errors='replace'), 1):
                        if ERROR.search(line) or COMPILE_ERROR.search(line):
                            if remaining == 0:
                                print(f'\n{archive}:{member.name}:{number}')
                                for previous in context:
                                    print(previous, end='')
                            print(line, end='')
                            remaining = 3
                        elif remaining:
                            print(line, end='')
                            remaining -= 1
                        context.append(line)
    for row in verdicts:
        print(f"\n{row['problem']} sample-{int(row['sample_index']):02d}: {row['verdict']}\nEvidence: {archive}:{row['archive_evidence']}")
    print(f'Full execution evidence: {archive}')
    if not verdicts:
        for name, value in partial_verdicts:
            print(f"Partial verdict: {value['verdict']}\nEvidence: {archive}:{name}")
        print('No completed verdict was recorded; inspect the runner logs in the archive.', file=sys.stderr)
        return 2
    actual = [(row['problem'], int(row['sample_index'])) for row in verdicts]
    if collection_error or (expected and (set(actual) != expected or len(actual) != len(expected))):
        print('Evaluation results are incomplete; inspect the runner logs in the archive.', file=sys.stderr)
        return 2
    if any(row['verdict'] != 'PASS' and not row['verdict'].startswith('FAIL') for row in verdicts):
        return 2
    return 0 if all(row['verdict'] == 'PASS' for row in verdicts) else 1


def show_result(path):
    if path.is_file():
        return show(path)
    archives = sorted((path / 'archives').glob('*.tar.gz'))
    if not archives:
        raise ValueError(f'no result archives in {path / "archives"}')
    return max(show(archive) for archive in archives)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    inspect = commands.add_parser('show', help='show verdicts and comparison output from a result directory or archive')
    inspect.add_argument('result', type=Path, help='--output directory or one of its archives')
    for name in ('run', 'prepare'):
        command = commands.add_parser(name, help='evaluate now' if name == 'run' else 'prepare a portable evaluation job')
        selection = command.add_mutually_exclusive_group(required=True)
        selection.add_argument('--problem', help='CPU/problem identifier from cpus/CPU/PROBLEMS.tsv')
        if name == 'prepare':
            selection.add_argument('--cpu', choices=('boom', 'cva6', 'ibex', 'rift2core', 'veer_el2', 'vexriscv'),
                                   help='prepare several problems using --candidate PROBLEM=FILE')
            command.add_argument('--problems-per-chunk', type=int, default=1,
                                 help='group CVA6 problems; other CPUs require one')
        command.add_argument('--candidate', required=True, action='append', type=Path,
                             help='saved UTF-8 final answer or HDL; with --cpu use PROBLEM=FILE; extraction is automatic')
        environment = command.add_mutually_exclusive_group(required=True)
        environment.add_argument('--image', type=Path)
        environment.add_argument('--environment', type=Path,
                                 help='directory created by prepare_environment.py')
        command.add_argument('--assets', type=Path, help='prepared CPU assets where required')
        command.add_argument('--output', required=True, type=Path)
        if name == 'run':
            command.add_argument('--work-root', type=Path,
                                 help='temporary CPU/build area; defaults to OUTPUT/scratch')
    args = parser.parse_args()
    if args.command == 'show':
        return show_result(args.result.resolve())
    if args.problem is not None:
        cpu, separator, problem = args.problem.partition('/')
        if not separator or not any(row['cpu'] == cpu and row['problem'] == problem for row in problem_rows(ROOT)):
            parser.error('Problem must match a CPU/problem entry in cpus/CPU/PROBLEMS.tsv')
    else:
        cpu, problem = args.cpu, None
    if args.environment:
        if args.assets:
            parser.error('--assets cannot be combined with --environment')
        from prepare_environment import load_environment
        args.image, args.assets = load_environment(args.environment, cpu)
    output = args.output.resolve()
    work_root_option = getattr(args, 'work_root', None)
    work_root = work_root_option.resolve() if work_root_option else output / 'scratch'
    if args.command == 'run' and (work_root == ROOT or ROOT in work_root.parents):
        parser.error('Work root must be outside the repository')
    command = [sys.executable, str(ROOT / 'tools/evaluation/prepare_evaluation_job.py'), '--cpu', cpu,
               '--image', str(args.image.resolve()),
               '--output', str(output)]
    for candidate in args.candidate:
        command += ['--candidate', f'{problem}={candidate.resolve()}' if problem else str(candidate)]
    if args.command == 'prepare':
        command += ['--problems-per-chunk', str(args.problems_per_chunk)]
    if args.assets:
        command += ['--assets', str(args.assets.resolve())]
        if args.command == 'run':
            command += ['--reuse-assets']
    prepared = subprocess.run(command, stderr=subprocess.PIPE, text=True)
    if prepared.returncode:
        message = ' '.join(prepared.stderr.split()) or f'job preparation exited with status {prepared.returncode}'
        print(message, file=sys.stderr)
        return 2
    if args.command == 'prepare':
        print(f'Evaluation job prepared: {output}')
        return 0
    execution_log = output / 'execution.log'
    with execution_log.open('w') as log:
        completed = subprocess.run([sys.executable, str(ROOT / 'tools/evaluation/run_evaluation_chunk.py'),
                                '--bundle', str(output / 'evaluation-job.json'), '--chunk', '1',
                                '--job-id', 'single-' + uuid.uuid4().hex, '--image', str(args.image.resolve()),
                                '--work-root', str(work_root)], stdout=log, stderr=subprocess.STDOUT)
    archive = output / 'archives/chunk-001.tar.gz'
    if archive.exists():
        feedback_status = show(archive)
        return completed.returncode or feedback_status
    archive.parent.mkdir(exist_ok=True)
    with tarfile.open(archive, 'w:gz') as stored:
        stored.add(execution_log, arcname='execution.log')
        if (output / 'results').exists():
            stored.add(output / 'results', arcname='results')
    print(f'Execution failed before a completed archive was produced: {execution_log}', file=sys.stderr)
    show(archive)
    return completed.returncode or 2


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, tarfile.TarError) as error:
        print(f'Evaluation failed: {error}', file=sys.stderr)
        sys.exit(2)
