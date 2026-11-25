# Example: generate answers with Ollama Cloud

This example generates ten answers for every problem of one CPU through an
Ollama server signed in to [Ollama Cloud](https://docs.ollama.com/cloud). It
saves each answer as `answer.txt` and the complete API response beside it.
Run it from the repository root and pass the saved answers to the evaluator as
described in the [README](../../README.md#evaluating-many-answers).

```bash
export CPU=ibex
export OLLAMA_ENDPOINT=http://localhost:11434
export OLLAMA_MODEL=gpt-oss:120b-cloud
export ANSWERS=/path/to/ibex-answers
export SAMPLES=10
export PARALLEL=4

python3 - <<'PY'
from concurrent.futures import ThreadPoolExecutor
import csv
import json
import os
from pathlib import Path
import urllib.request

root = Path.cwd()
cpu = os.environ['CPU']
model = os.environ['OLLAMA_MODEL']
endpoint = os.environ['OLLAMA_ENDPOINT'].rstrip('/')
samples = int(os.environ.get('SAMPLES', '10'))
parallel = int(os.environ.get('PARALLEL', '4'))
if samples < 1 or parallel < 1:
    raise ValueError('SAMPLES and PARALLEL must be positive')
headers = {'Content-Type': 'application/json'}
if endpoint == 'https://ollama.com':
    headers['Authorization'] = 'Bearer ' + os.environ['OLLAMA_API_KEY']
output = Path(os.environ['ANSWERS']).resolve()
if output == root or root in output.parents:
    raise ValueError('Save answers outside the repository')
with (root / 'cpus' / cpu / 'PROBLEMS.tsv').open() as stream:
    problems = list(csv.DictReader(stream, delimiter='\t'))
output.mkdir(parents=True, exist_ok=False)

def generate(item):
    problem, sample = item
    destination = output / problem['problem'] / f'sample-{sample:02d}'
    destination.mkdir(parents=True)
    prompt = (root / 'cpus' / cpu / problem['specification']).read_bytes()
    (destination / 'prompt.md').write_bytes(prompt)
    payload = {
        'model': model, 'prompt': prompt.decode('utf-8'),
        'think': 'low', 'stream': False,
        'options': {'temperature': 0.8, 'top_p': 0.95, 'seed': sample,
                    'num_ctx': 65536, 'num_predict': 65536},
    }
    body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
    (destination / 'request.json').write_bytes(body)
    request = urllib.request.Request(
        endpoint + '/api/generate', data=body, headers=headers,
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        raw = response.read()
    (destination / 'response.json').write_bytes(raw)
    result = json.loads(raw)
    if result.get('done') is not True or not isinstance(result.get('response'), str):
        raise ValueError(f'Incomplete generation: {destination}')
    (destination / 'answer.txt').write_bytes(result['response'].encode('utf-8'))
    print(f"{cpu}/{problem['problem']} sample-{sample:02d}: saved", flush=True)

trials = ((problem, sample) for problem in problems for sample in range(samples))
with ThreadPoolExecutor(max_workers=parallel) as executor:
    for _ in executor.map(generate, trials):
        pass
PY
```
