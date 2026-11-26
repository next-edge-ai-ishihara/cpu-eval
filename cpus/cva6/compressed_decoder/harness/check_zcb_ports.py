#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare CV32A60X Zcb expansion and classification at the public decoder ports."""

from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CPU = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(CPU / 'instr_scan/harness'))
from evaluate_ports import CAPACITY, CPU_REV, execute, port_work_root, size
sys.path.insert(0, str(Path(__file__).resolve().parents[4] / "tools/cva6"))
from replace_module import MissingModule, module_text
sys.path.insert(0, str(CPU / 'harness'))
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP, missing_module


SUCCESS = 'PASS: decoded 1000 legal and returned 1176 reserved Zcb halfwords'
FIXED = ('config_pkg.sv', 'cv32a60x_config_pkg.sv', 'build_config_pkg.sv', 'riscv_pkg.sv')


def main(candidate):
    repo = os.environ['CVA6_REPO']
    base = Path(os.environ['CPU_EVAL_LOG_ROOT'])
    base.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix='compressed-decoder-zcb-', dir=base))
    root = port_work_root()
    if shutil.disk_usage(root).free < CAPACITY:
        raise ValueError('64 MiB free temporary storage required')
    files = {name: subprocess.check_output(['git', '-C', repo, 'show', f'{CPU_REV}:core/include/{name}'])
             for name in FIXED}
    files['candidate.sv'] = module_text(candidate.read_text(), 'compressed_decoder').encode()
    bench = Path(__file__).with_name('compressed_zcb_ports_tb.sv')
    files[bench.name] = bench.read_bytes()
    if sum(map(len, files.values())) >= CAPACITY:
        raise ValueError('compressed-decoder port inputs exceed the temporary storage capacity')
    result = {'configuration': 'cv32a60x', 'cpu_revision': CPU_REV,
              'input_sha256': {name: sha256(data).hexdigest() for name, data in files.items()}}
    code = 2
    runtime = b'INVALID: bounded Zcb port check did not complete\n'
    with tempfile.TemporaryDirectory(prefix='cpu-eval-compressed-decoder-zcb-', dir=root) as temporary:
        work = Path(temporary)
        for name, data in files.items():
            (work / name).write_bytes(data)
        argv = ['verilator', '--binary', '--timing', '-Wno-fatal', '--top-module', 'testbench',
                '-MAKEFLAGS', 'VM_PARALLEL_BUILDS=0', '--Mdir', str(work / 'obj'),
                *(str(work / name) for name in files)]
        result['build_argv'] = argv
        try:
            build = execute(argv, 120, work)
            (output / 'build.log').write_bytes(build.stdout)
            result['build_exit_code'] = build.returncode
            if build.returncode not in (0, *EXTERNAL_STOP) and size(work) <= CAPACITY and not (
                    ENVIRONMENT_ERROR.search(build.stdout.decode(errors='replace'))):
                code = 1
                runtime = b'FAIL: the Zcb port testbench did not build with the submission\n'
            if build.returncode == 0 and size(work) <= CAPACITY:
                run = execute([str(work / 'obj/Vtestbench')], 30, work)
                runtime = run.stdout
                result['runtime_exit_code'] = run.returncode
                lines = runtime.decode(errors='replace').splitlines()
                if run.returncode == 0 and lines.count(SUCCESS) == 1 and not any(line.startswith('FAIL:') for line in lines):
                    code = 0
                elif run.returncode not in EXTERNAL_STOP:
                    code = 1
        except (ValueError, OSError, subprocess.TimeoutExpired) as error:
            result['error'] = str(error)
    (output / 'runtime.log').write_bytes(runtime)
    result['exit_code'] = code
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(runtime.decode(errors='replace'), end='')
    print('PORT_RESULT=' + str(output))
    return code


if __name__ == '__main__':
    try:
        raise SystemExit(main(Path(sys.argv[1])))
    except MissingModule as error:
        raise SystemExit(missing_module('compressed_decoder', error))
    except (IndexError, KeyError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print('INVALID: ' + str(error))
        raise SystemExit(2)
