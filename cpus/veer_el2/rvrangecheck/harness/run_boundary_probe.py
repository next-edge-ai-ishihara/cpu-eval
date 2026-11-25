#!/usr/bin/env python3
"""Check rvrangecheck outputs at the boundaries of the selected configurations."""
import argparse
import hashlib
import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--results', required=True, type=Path)
    parser.add_argument('--verilator', default='verilator')
    parser.add_argument('--compile-timeout', type=float, default=120)
    parser.add_argument('--timeout', type=float, default=20)
    args = parser.parse_args()
    try:
        args.results.mkdir(parents=True, exist_ok=True)
        if any(args.results.iterdir()):
            print('CPU_EVAL_INVALID: results directory must be empty', file=sys.stderr)
            return 2
    except OSError as error:
        print('CPU_EVAL_INVALID: ' + str(error), file=sys.stderr)
        return 2
    record = {'source_path': str(args.source.resolve()), 'commands': [],
              'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'cwd': str(Path.cwd()),
              'environment': {key: os.environ.get(key) for key in ['PATH', 'CCACHE_DIR', 'CXX', 'VERILATOR_ROOT']}}

    def finish(code, reason, invalid=False):
        record.update(exit=code, reason=reason, invalid=invalid)
        try:
            (args.results / 'execution.json').write_text(json.dumps(record, indent=2) + '\n')
        except OSError as error:
            print('CPU_EVAL_INVALID: ' + str(error), file=sys.stderr)
            return 2
        print(('CPU_EVAL_INVALID' if invalid else 'PASS' if code == 0 else 'FAIL') + ': ' + reason)
        return code

    def run(command, log, limit):
        record['commands'].append(command)
        with (args.results / log).open('w') as output:
            process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=limit)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                record[log + '_exit'] = process.returncode
                raise
        record[log + '_exit'] = code
        return code

    try:
        source = args.source.read_bytes()
        record['source_sha256'] = hashlib.sha256(source).hexdigest()
        (args.results / 'installed-source.sv').write_bytes(source)
        text = source.decode('utf-8')
        starts = list(re.finditer(r'(?m)^\s*module\s+rvrangecheck\b', text))
        if len(starts) != 1:
            return finish(2, 'installed source must contain exactly one rvrangecheck module')
        end = re.search(r'(?m)^\s*endmodule\b[^\n]*', text[starts[0].start():])
        if end is None:
            return finish(2, 'rvrangecheck endmodule is missing')
        module = text[starts[0].start():starts[0].start()+end.end()] + '\n'
        capture = args.results / 'rvrangecheck.sv'
        capture.write_text(module)
        record['module_sha256'] = hashlib.sha256(module.encode()).hexdigest()
        tb = Path(__file__).resolve().with_name('range_boundary_tb.sv')
        record['testbench_sha256'] = hashlib.sha256(tb.read_bytes()).hexdigest()
        if run([args.verilator, '--version'], 'version.log', 10) != 0:
            return finish(2, 'Verilator version command failed', invalid=True)
        if not re.search(r'\bVerilator 5\.036\b', (args.results/'version.log').read_text()):
            return finish(2, 'Verilator 5.036 is required', invalid=True)
        command = [args.verilator, '--binary', '--timing', '-Wno-fatal', '-j', '2', '--top-module', 'range_boundary_tb', '--Mdir', str(args.results.resolve()/'obj'), '-o', 'range_probe', str(capture.resolve()), str(tb)]
        if run(command, 'compiler.log', args.compile_timeout) != 0:
            return finish(2, 'single-module compilation failed')
        if run([str(args.results.resolve()/'obj/range_probe')], 'runtime.log', args.timeout) != 0:
            return finish(2, 'probe process did not exit normally')
        result = re.findall(r'^RANGE_PROBE_COMPLETE checked=44 errors=(\d+)$', (args.results/'runtime.log').read_text(), re.M)
        if len(result) != 1:
            return finish(2, 'complete 44-input result is missing or duplicated')
        record['checked'] = 44
        record['mismatches'] = int(result[0])
        return finish(1 if int(result[0]) else 0, 'selected boundary values differ' if int(result[0]) else 'all 44 selected boundary values match')
    except subprocess.TimeoutExpired as error:
        record['timeout_command'] = error.cmd
        return finish(2, 'probe compilation or execution timed out', invalid=True)
    except (OSError, UnicodeError) as error:
        return finish(2, str(error), invalid=True)


if __name__ == '__main__':
    sys.exit(main())
