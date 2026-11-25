#!/usr/bin/env python3
"""Check stride arbiter transfers, round-robin progress and response ownership."""
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

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness"))
from candidate_error import EXTERNAL_STOP

HPDCACHE_REV = 'f404e7ebbda8baa4af3729535f520a6b12a06d03'
FIXED_SOURCES = ['rtl/src/hpdcache_pkg.sv', 'rtl/include/hpdcache_typedef.svh',
                 'rtl/src/common/hpdcache_mux.sv', 'rtl/src/common/hpdcache_rrarb.sv',
                 'rtl/src/common/hpdcache_prio_1hot_encoder.sv']


def run(command, directory, name, timeout):
    record = {'command': command, 'cwd': str(directory), 'timed_out': False}
    with (directory / (name + '.log')).open('wb') as log:
        process = subprocess.Popen(command, cwd=directory, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            record['timed_out'] = True
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        record['process_returncode'] = process.returncode
    (directory / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    return process.returncode, record['timed_out']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--build-timeout', type=float, default=120)
    parser.add_argument('--run-timeout', type=float, default=10)
    args = parser.parse_args()
    if not args.candidate.is_file() or min(args.build_timeout, args.run_timeout) <= 0:
        raise ValueError('candidate file and positive timeouts required')
    evidence_root = os.environ.get('CPU_EVAL_LOG_ROOT')
    root = Path(evidence_root or tempfile.gettempdir()).resolve()
    root.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix='stride-arb-ports-', dir=root.parent if evidence_root else root))
    print(f'stride arbiter port-test logs: {directory}', flush=True)
    here = Path(__file__).parent
    shutil.copyfile(args.candidate.resolve(), directory / 'candidate.sv')
    shutil.copyfile(here / 'stride_arb_ports_tb.sv', directory / 'tb.sv')
    # Fixed dependencies come from the pinned HPDcache commit in the CVA6 checkout.
    hpdcache = Path(os.environ['CVA6_REPO']) / 'core/cache_subsystem/hpdcache'
    for path in FIXED_SOURCES:
        (directory / Path(path).name).write_bytes(subprocess.check_output(
            ['git', '-C', str(hpdcache), 'show', HPDCACHE_REV + ':' + path]))
    inputs = [p for p in directory.iterdir() if p.suffix in {'.sv', '.svh'}]
    (directory / 'inputs.json').write_text(json.dumps(
        {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}, indent=2) + '\n')
    tool = os.environ.get('VERILATOR', 'verilator')
    status, timeout = run([tool, '--version'], directory, 'tool', 10)
    if status or timeout:
        return 2
    sources = ['hpdcache_pkg.sv', 'hpdcache_prio_1hot_encoder.sv',
               'hpdcache_rrarb.sv', 'hpdcache_mux.sv', 'candidate.sv', 'tb.sv']
    status, timeout = run([tool, '--binary', '--timing', '-Wno-fatal',
        '-DHPDCACHE_ASSERT_OFF', '-j', '2', '--top-module', 'tb',
        '--Mdir', str(directory / 'obj'), '-I' + str(directory), *sources],
        directory, 'build', args.build_timeout)
    if status and not timeout:
        classification = subprocess.run(["python3", str(here.parents[1] / "harness/candidate_error.py"),
            str(directory / "build.log"), str(directory / "candidate.sv"), "--directory", str(directory),
            "--submitted", str(args.candidate)], capture_output=True, text=True, check=False)
        print(classification.stdout, end="")
        if classification.returncode == 1 and classification.stdout.startswith("FAIL_CANDIDATE_COMPILE:"):
            if evidence_root:
                receipt = root / here.parent.name / directory.name
                receipt.mkdir(parents=True)
                shutil.copyfile(directory / "build.log", receipt / "build.log")
                shutil.copyfile(directory / "build.log", receipt / "candidate-compile-error.txt")
                (receipt / "exit-code.txt").write_text("1\n")
            return 1
    if status or timeout:
        print('INVALID: port-test build did not complete')
        return 2
    status, timeout = run([str(directory / 'obj/Vtb')], directory, 'runtime', args.run_timeout)
    log = (directory / 'runtime.log').read_text()
    if timeout:
        print('INVALID: port-test timed out')
        return 2
    if status in EXTERNAL_STOP:
        print('INVALID: port-test was stopped from outside')
        return 2
    if re.search(r'(?m)^INVALID ', log):
        print('FAIL: port-test producer did not complete with the submission')
        return 1
    if re.search(r'(?m)^MISMATCH cycle=', log):
        print('FAIL: external port contract mismatch')
        return 1
    complete = all(re.search(rf'(?m)^PHASE_COMPLETE phase={p} transfers={n}$', log)
                   for p, n in [(0, 512), (1, 128), (2, 32)])
    complete &= len(re.findall(r'(?m)^RESPONSE cycle=', log)) == 16
    complete &= bool(re.search(r'(?m)^SUMMARY requests=672 responses=16 input_hold_checks=[1-9]\d* output_hold_checks=[1-9]\d* errors=0$', log))
    complete &= bool(re.search(r'(?m)^STRIDE_ARB_PORT_TEST_COMPLETE$', log))
    if status or not complete:
        print('FAIL: completion evidence missing')
        return 1
    print('PASS: 672 requests and 16 response owners checked')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f'INVALID: {error}', flush=True)
        raise SystemExit(2)
