#!/usr/bin/env python3

import argparse, hashlib, json, os, pathlib, re, signal, subprocess, sys, tempfile, time, traceback
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'harness'))
from candidate_error import EXTERNAL_STOP
parser = argparse.ArgumentParser()
parser.add_argument('--candidate', type=pathlib.Path, required=True)
parser.add_argument('--checkout', type=pathlib.Path, required=True)
parser.add_argument('--log-root', type=pathlib.Path, required=True)
parser.add_argument('--compile-marker-root', type=pathlib.Path)
parser.add_argument('--verilator', default='verilator')
parser.add_argument('--timeout', type=int, default=900)
args = parser.parse_args()
directory = args.log_root.resolve()
directory.mkdir(parents=True, exist_ok=False)
record = {'start': time.time(), 'timeout_seconds': args.timeout}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def execute(command, log):
    with log.open('wb') as out:
        process = subprocess.Popen(command, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            record['timed_out_command'] = command
            raise

def compile_marker(log):
    if args.compile_marker_root is not None:
        args.compile_marker_root.mkdir(parents=True, exist_ok=True)
        marker = pathlib.Path(tempfile.mkdtemp(prefix='user-compile-', dir=args.compile_marker_root))
        (marker / 'build.log').write_bytes(log.read_bytes())
        (marker / 'candidate-compile-error.txt').write_bytes(log.read_bytes())
        (marker / 'exit-code.txt').write_text('1\n')

def main():
    if args.timeout <= 0:
        raise ValueError('timeout must be positive')
    root = pathlib.Path(__file__).resolve().parents[4]
    revision = '6348e9e684678f83b40d0520028513d06b36e7b2'
    paths = {
        'common/local/util/sram_cache.sv': '08f855e6fc7b6f79971bc51724d10ccbbd7641cc9a4c63ef61c0f287e97fc962',
        'common/local/util/tc_sram_wrapper_cache_techno.sv': 'c10b2faf922c2d7c49a52f93087bb545077d9c82399c985c2bfdaead0a03b220',
        'vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv': '32e9cb89cf89902e9fa566a66f931f6fe00a616cd426ba440b1e634d0caeb607',
    }
    pinned = []
    for source, expected in paths.items():
        target = directory / 'fixed' / source
        target.parent.mkdir(parents=True, exist_ok=True)
        raw = subprocess.check_output(['git', '-C', str(args.checkout), 'show', revision + ':' + source], timeout=args.timeout)
        target.write_bytes(raw)
        if sha(target) != expected:
            raise ValueError('pinned source SHA mismatch: ' + source)
        pinned.append(target)
    record.update(revision=revision, candidate_sha256=sha(args.candidate), fixed_sources=[{'path': str(p), 'sha256': sha(p)} for p in pinned])
    candidate = directory / 'compiled-source.sv'
    normalize = ['python3', str(root / 'tools/cva6/replace_module.py'), '--module', 'sram_cache', '--base', str(pinned[0]), '--candidate', str(args.candidate.resolve()), '--output', str(candidate)]
    record['normalization_command'] = normalize
    record['normalization_exit'] = execute(normalize, directory / 'normalization.log')
    if record['normalization_exit'] == 1:
        # The submission does not define sram_cache.
        compile_marker(directory / 'normalization.log')
        return 1
    if record['normalization_exit']:
        return 2
    inputs = [candidate, pathlib.Path(__file__).with_name('user_tb.sv'), *pinned[1:]]
    record['inputs'] = [{'path': str(p.resolve()), 'sha256': sha(p)} for p in inputs]
    build = [args.verilator, '--binary', '--timing', '--top-module', 'user_tb', '-Wno-fatal', '-j', '2', '--Mdir', str(directory / 'model'), *[str(p) for p in inputs]]
    record['build_command'] = build
    record['build_exit'] = execute(build, directory / 'build.log')
    if record['build_exit']:
        if record['build_exit'] not in EXTERNAL_STOP:
            classify = ['python3', str(root / 'cpus/cva6/harness/candidate_error.py'),
                        str(directory / 'build.log'), str(candidate),
                        '--directory', str(directory), '--submitted', str(args.candidate.resolve())]
            record['build_classification_command'] = classify
            record['build_classification_exit'] = execute(classify, directory / 'build-classification.log')
            if record['build_classification_exit'] == 1:
                compile_marker(directory / 'build.log')
                return 1
        return 2
    binary = directory / 'model/Vuser_tb'
    record['binary_sha256'] = sha(binary)
    run = [str(binary)]
    record['run_command'] = run
    record['run_exit'] = execute(run, directory / 'run.log')
    result = re.findall(r'^RESULT checks=(\d+) data_errors=(\d+) user_errors=(\d+) errors=(\d+)$', (directory / 'run.log').read_text(), re.M)
    if record['run_exit'] in EXTERNAL_STOP:
        return 2
    if len(result) != 1 or int(result[0][0]) != 128:
        return 1
    counts = list(map(int, result[0]))
    record['result'] = counts
    if counts[3]:
        return 1
    return 0 if record['run_exit'] == 0 else 1

try:
    exit_code = main()
except Exception:
    (directory / 'exception.log').write_text(traceback.format_exc())
    exit_code = 2
record.update(exit_code=exit_code, verdict={0: 'PASS', 1: 'FAIL', 2: 'INVALID'}[exit_code], end=time.time())
(directory / 'execution.json').write_text(json.dumps(record, indent=2) + '\n')
print(record['verdict'] + ': selected SRAM user test; logs=' + str(directory))
raise SystemExit(exit_code)
