#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check direct passage of both LSU result records at the selected depth."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1]/'instr_scan/harness'))
from evaluate_ports import CAPACITY, execute, port_work_root
sys.path.insert(0, str(HERE.parents[1] / 'harness'))
from candidate_error import ENVIRONMENT_ERROR, EXTERNAL_STOP


def evaluate(candidate):
    files = {'candidate.sv': candidate.read_bytes(),
             'shift_reg_ports_tb.sv': (HERE/'shift_reg_ports_tb.sv').read_bytes()}
    ram = port_work_root()
    if sum(map(len, files.values())) >= CAPACITY or shutil.disk_usage(ram).free < CAPACITY:
        raise ValueError('64 MiB free temporary storage required for the port check')
    root = Path(os.environ['CPU_EVAL_LOG_ROOT']).resolve()
    logs = Path(tempfile.mkdtemp(prefix='shift-reg-ports-', dir=root.parent))
    (logs/'inputs.json').write_text(json.dumps({name:hashlib.sha256(data).hexdigest()
                                               for name,data in files.items()},indent=2)+'\n')
    print(f'shift register port-test logs: {logs}',flush=True)
    with tempfile.TemporaryDirectory(prefix='cpu-eval-shift-reg-',dir=ram) as folder:
        scratch = Path(folder)
        for name, data in files.items():
            (scratch/name).write_bytes(data)
        tool = os.environ.get('VERILATOR','verilator')
        argv = [tool,'--binary','--timing','-Wno-fatal','-j','2','--top-module','testbench',
                '--Mdir',str(scratch/'obj'),*[str(scratch/name) for name in files]]
        build = execute(argv,120,scratch)
        (logs/'build.log').write_bytes(build.stdout)
        (logs/'build.json').write_text(json.dumps({'argv':argv,'exit_code':build.returncode},indent=2)+'\n')
        if build.returncode in EXTERNAL_STOP or ENVIRONMENT_ERROR.search(build.stdout.decode(errors='replace')):
            print('INVALID: the port-test build was stopped by a tool or resource failure')
            return 2
        if build.returncode:
            print('FAIL: the port test could not build with this submission')
            return 1
        run = execute([str(scratch/'obj/Vtestbench')],30,scratch)
    (logs/'runtime.log').write_bytes(run.stdout)
    text = run.stdout.decode(errors='replace')
    observations = [int(i) for i in re.findall(r'(?m)^OBSERVATION check=(\d+) ',text)]
    mismatch = re.findall(r'(?m)^MISMATCH check=\d+ [\w-]+$',text)
    summary = re.findall(r'(?m)^SUMMARY comparisons=6 mismatches=(\d+)$',text)
    if run.returncode in EXTERNAL_STOP:
        print('INVALID: the port check was stopped from outside')
        return 2
    if run.returncode or observations != list(range(6)) or summary != [str(len(mismatch))]:
        print('FAIL: the port check did not record a complete comparison sequence')
        return 1
    if mismatch:
        print('FAIL: depth-zero input and output differ')
        return 1
    print('PASS: six depth-zero port comparisons match')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(evaluate(Path(sys.argv[1]).resolve()))
    except (KeyError,OSError,subprocess.SubprocessError,ValueError) as error:
        print(f'INVALID: {error}')
        raise SystemExit(2)
