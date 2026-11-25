#!/usr/bin/env python3
"""Compare every output bit of the priority encoder for binary N=4 inputs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from candidate_error import EXTERNAL_STOP


def stop_group(process):
    def running():
        for entry in Path('/proc').iterdir():
            if not entry.name.isdecimal():
                continue
            try:
                fields = (entry / 'stat').read_text().rsplit(')', 1)[1].split()
                if int(fields[2]) == process.pid and int(fields[3]) == process.pid and fields[0] != 'Z':
                    return True
            except (FileNotFoundError, ProcessLookupError):
                continue
            except PermissionError:
                try:
                    if entry.stat().st_uid == os.geteuid():
                        return True
                except FileNotFoundError:
                    continue
        return False
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    while running():
        time.sleep(0.01)
    process.wait()


def run(command, directory, name, timeout):
    record = {'command': command, 'cwd': str(directory), 'timed_out': False}
    with (directory / (name + '.log')).open('wb') as log:
        try:
            process = subprocess.Popen(command, cwd=directory, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as error:
            record.update(process_returncode=None, startup_error=str(error))
        else:
            record['process_group'] = process.pid
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                record['timed_out'] = True
            finally:
                stop_group(process)
            record['process_returncode'] = process.returncode
    (directory / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    return record['process_returncode'], record['timed_out']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--build-timeout', type=float, default=120)
    parser.add_argument('--run-timeout', type=float, default=10)
    args = parser.parse_args()
    evidence_root = os.environ.get('CPU_EVAL_LOG_ROOT')
    root = Path(evidence_root or tempfile.gettempdir())
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix='priority-ports-', dir=root))
    print(f'priority port-test logs: {directory}', flush=True)
    os.environ.setdefault('CCACHE_DIR', str(directory / 'ccache'))
    shutil.copyfile(args.candidate.resolve(), directory / 'candidate.sv')
    shutil.copyfile(Path(__file__).with_name('priority_ports_tb.sv'), directory / 'tb.sv')
    (directory / 'inputs.json').write_text(json.dumps({p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [directory / 'candidate.sv', directory / 'tb.sv']}, indent=2) + '\n')
    tool = os.environ.get('VERILATOR', 'verilator')
    status, timed_out = run([tool, '--version'], directory, 'tool', 10)
    if status != 0 or timed_out:
        return 2
    status, timed_out = run([tool, '--binary', '--timing', '--assert', '-j', '2',
        '--top-module', 'tb', '--Mdir', str(directory / 'obj'), '-Wno-fatal',
        'candidate.sv', 'tb.sv'], directory, 'build', args.build_timeout)
    if status and not timed_out:
        classification = subprocess.run(["python3", str(Path(__file__).parents[2] / "harness/candidate_error.py"),
            str(directory / "build.log"), str(directory / "candidate.sv"), "--directory", str(directory), "--submitted", str(args.candidate)],
            capture_output=True, check=False)
        if (classification.returncode == 1 and
                classification.stdout.strip() == b'FAIL_CANDIDATE_COMPILE: compiler error identifies the submitted source'):
            if evidence_root:
                inputs = directory.rename(root.parent / (directory.name + '-compile-inputs'))
                receipt = root / 'hpdcache_prio_1hot_encoder' / directory.name
                receipt.mkdir(parents=True)
                shutil.copyfile(inputs / 'build.log', receipt / 'build.log')
                shutil.copyfile(receipt / 'build.log', receipt / 'candidate-compile-error.txt')
                (receipt / 'exit-code.txt').write_text('1\n')
                print(f'priority compiler inputs: {inputs}', flush=True)
            print(classification.stdout.decode().strip(), flush=True)
            return 1
    if status != 0 or timed_out:
        return 2
    status, timed_out = run([str(directory / 'obj/Vtb')], directory, 'runtime', args.run_timeout)
    if status is None or status in (125, 126, 127) or timed_out:
        return 2
    log = (directory / 'runtime.log').read_text()
    complete = (re.findall(r'(?m)^OBS request=([0-9a-f]+) ', log) == [format(i, 'x') for i in range(16)] + ['0']
        and len(re.findall(r'(?m)^SUMMARY checks=17 errors=0$', log)) == 1
        and len(re.findall(r'(?m)^PRIORITY_PORT_TEST_COMPLETE$', log)) == 1)
    if status in EXTERNAL_STOP:
        return 2
    return 0 if status == 0 and complete else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f'INVALID: {error}', flush=True)
        raise SystemExit(2)
