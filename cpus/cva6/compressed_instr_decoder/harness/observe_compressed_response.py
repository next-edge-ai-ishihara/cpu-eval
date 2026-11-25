#!/usr/bin/env python3
import json
from pathlib import Path
import re
import sys

raw=Path(sys.argv[1]).read_text(errors='replace')
pattern=r'^CPU_EVAL_COMPRESSED req=([0-9a-fA-F]{4}) accept=([01]) instr=([0-9a-fA-F]{8})$'
observations=[{'request':int(a,16),'accept':int(b),'instruction':int(c,16)} for a,b,c in re.findall(pattern,raw,re.M)]
required={0xe000:0x0000007b,0xf52c:0x00b5157b}
selected=[x for x in observations if x['request'] in required]
missing=sorted(set(required)-{x['request'] for x in selected})
malformed=[line for line in raw.splitlines() if line.startswith('CPU_EVAL_COMPRESSED') and not re.fullmatch(pattern,line)]
mismatches=[x for x in selected if x['accept']!=1 or x['instruction']!=required[x['request']]]
exit_code=2 if malformed else (1 if missing or mismatches else 0)
result={'verdict':{0:'PASS',1:'FAIL_COMPRESSION_RESPONSE_MISMATCH',2:'INVALID_OBSERVATION'}[exit_code],
        'observations':observations,'required_requests':list(required),'missing':missing,
        'malformed':malformed,'mismatches':mismatches,'exit_code':exit_code}
Path(sys.argv[2]).write_text(json.dumps(result,indent=2)+'\n')
print(result['verdict'])
raise SystemExit(exit_code)
