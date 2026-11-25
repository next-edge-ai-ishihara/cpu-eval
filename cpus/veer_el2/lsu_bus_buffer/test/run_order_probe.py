import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import tempfile


def execute(command, timeout):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               text=True, start_new_session=True,
                               env=dict(os.environ, CCACHE_DISABLE='1'))
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    finally:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--checkout', required=True, type=Path)
    parser.add_argument('--testbench', required=True, type=Path)
    parser.add_argument('--results', required=True, type=Path)
    args = parser.parse_args()
    checkout = args.checkout.resolve()
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output(['verilator', '--version'], text=True).strip()
    if not re.search(r'\b5\.036\b', version):
        raise RuntimeError('Verilator 5.036 is required')
    settings = checkout / 'tools/riscv-dv/work'
    files = [settings / name for name in ('el2_param.vh', 'el2_pdef.vh', 'common_defines.vh')]
    files += [checkout / 'design/include/el2_def.sv', checkout / 'design/lib/beh_lib.sv',
              checkout / 'design/lsu/el2_lsu_bus_buffer.sv', args.testbench.resolve()]
    manifest = {'verilator_version': version, 'inputs': [
        {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        for path in files]}
    work = Path(tempfile.mkdtemp(prefix='cpu-eval-bus-order-',
                                 dir=os.environ.get('CPU_EVAL_UNIT_WORK_ROOT')))
    try:
        library = work / 'library.sv'
        library.write_bytes(b'`include "common_defines.vh"\n' + files[4].read_bytes())
        command = ['verilator', '--binary', '--timing', '--top-module', 'probe',
                   '-Wno-fatal', '-I' + str(settings), '--Mdir', str(work / 'obj'),
                   str(files[3]), str(library), str(files[5]), str(files[6])]
        built = execute(command, 90)
        (results / 'bus_order_build.log').write_text(built.stdout + built.stderr)
        manifest['build_exit'] = built.returncode
        manifest['generated_bytes'] = sum(p.stat().st_size for p in work.rglob('*') if p.is_file())
        outcome = 2
        if manifest['generated_bytes'] > 64 * 1024 * 1024:
            print('Unit build exceeded the 64 MiB allocation')
            built = subprocess.CompletedProcess(command, 1)
        if built.returncode == 0:
            executed = execute([str(work / 'obj/Vprobe')], 10)
            output = executed.stdout + executed.stderr
            (results / 'bus_order_run.log').write_text(output)
            manifest['run_exit'] = executed.returncode
            match = re.search(r'ORDER_PROBE store_address_accepted=(\d+) '
                              r'store_data_accepted=(\d+) ar_before_store_response=(\d+)', output)
            if executed.returncode == 0 and match:
                manifest['observed'] = [int(value) for value in match.groups()]
                outcome = 0 if manifest['observed'] == [1, 1, 1] else 1
        manifest['returncode'] = outcome
        manifest['scope'] = 'Fixed-cycle observation; a missing store or load handshake is FAIL.'
        (results / 'bus_order_execution.json').write_text(json.dumps(manifest, indent=2) + '\n')
        return outcome
    finally:
        shutil.rmtree(work)


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print('CPU_EVAL_INVALID: bus order probe: ' + str(error))
        raise SystemExit(2)
