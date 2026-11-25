#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check writeback before and after a load pipeline flush."""

from hashlib import sha256
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / 'instr_scan/harness'))
from evaluate_ports import CAPACITY, execute, port_work_root
sys.path.insert(0, str(HERE.parents[1] / 'harness'))
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP


def digest(data):
    return sha256(data).hexdigest()

def port_types(cpu_parent):
    text = cpu_parent.decode()
    declarations = []
    for name in ('exception_t', 'lsu_ctrl_t', 'dcache_req_i_t', 'dcache_req_o_t'):
        match = re.search(r'\b'+name+r' = struct packed \{(.*?)\n    \},', text, re.S)
        if match is None:
            raise ValueError(f'cannot read {name} from the fixed CVA6 parent')
        declarations.append('typedef struct packed {'+match.group(1)+'\n} '+name+';\n')
    return ''.join(declarations).encode()


def main(candidate):
    recipe = json.loads((HERE.parent/'TEST_RECIPE.json').read_bytes())
    cpu = Path(os.environ['CVA6_REPO'])
    revision = recipe['cpu_revision']
    if subprocess.check_output(['git','-C',cpu,'rev-parse','HEAD']).decode().strip() != revision:
        raise ValueError('CVA6 checkout differs from its recorded revision')
    files = {}
    for source in recipe['port_test']['dependencies']:
        path = source['path']
        data = subprocess.check_output(['git','-C',cpu,'show',f'{revision}:{path}'])
        if digest(data) != source['sha256']:
            raise ValueError(f'unexpected fixed dependency bytes for {path}')
        files[Path(path).name] = data
    files['load_port_types.svh'] = port_types(files.pop('cva6.sv'))
    files['candidate.sv'] = candidate.read_bytes()
    files['load_ports_tb.sv'] = (HERE/'load_ports_tb.sv').read_bytes()
    ram = port_work_root()
    if sum(map(len,files.values())) >= CAPACITY or shutil.disk_usage(ram).free < CAPACITY:
        raise ValueError('64 MiB free temporary storage required for the port check')
    root = Path(os.environ['CPU_EVAL_LOG_ROOT']).resolve()
    logs = Path(tempfile.mkdtemp(prefix='load-unit-ports-', dir=root.parent))
    (logs/'inputs.json').write_text(json.dumps({name:digest(data) for name,data in files.items()},indent=2)+'\n')
    print(f'load unit port-test logs: {logs}',flush=True)
    tool = os.environ.get('VERILATOR','verilator')
    with tempfile.TemporaryDirectory(prefix='cpu-eval-load-unit-', dir=ram) as work_dir:
        work = Path(work_dir)
        for name, data in files.items():
            (work/name).write_bytes(data)
        command = [tool,'--binary','--timing','-Wno-fatal','-j','2',f'-I{work}',
                   '--top-module','testbench','--Mdir',str(work/'obj'),
                   *[str(work/name) for name in files if name.endswith('.sv')]]
        build = execute(command,120,work)
        (logs/'build.log').write_bytes(build.stdout)
        (logs/'build.json').write_text(json.dumps({'argv':command, 'exit_code':build.returncode},indent=2)+'\n')
        if build.returncode in EXTERNAL_STOP or ENVIRONMENT_ERROR.search(build.stdout.decode(errors='replace')):
            print('INVALID: the port-test build was stopped by a tool or resource failure')
            return 2
        if build.returncode:
            print('FAIL: the port test could not build with this submission')
            return 1
        run = execute([str(work/'obj/Vtestbench')],30,work)
    (logs/'runtime.log').write_bytes(run.stdout)
    text = run.stdout.decode(errors='replace')
    observations = [int(i) for i in re.findall(r'(?m)^OBSERVATION check=(\d+) ',text)]
    mismatches = re.findall(r'(?m)^MISMATCH check=\d+ name=[\w-]+$',text)
    complete = (observations == list(range(3)) and
                re.findall(r'(?m)^SUMMARY observations=3 mismatches=(\d+)$',text) == [str(len(mismatches))])
    if run.returncode in EXTERNAL_STOP:
        print('INVALID: the port check was stopped from outside')
        return 2
    if run.returncode or not complete:
        print('FAIL: the port check did not record a complete observation sequence')
        return 1
    if mismatches:
        print('FAIL: load completion differs')
        return 1
    print('PASS: three load completion observations match')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main(Path(sys.argv[1]).resolve()))
    except (KeyError,OSError,subprocess.SubprocessError,ValueError) as error:
        print(f'INVALID: {error}')
        raise SystemExit(2)
