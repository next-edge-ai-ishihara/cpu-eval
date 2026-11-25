#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-popcount.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

test_list=$(python3 - "$problem_directory" <<'PY'
from hashlib import sha256
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
recipe = json.loads((root / "TEST_RECIPE.json").read_bytes())
path = root / recipe["test_list"]
if sha256(path.read_bytes()).hexdigest() != recipe["test_list_sha256"]:
    sys.exit("popcount test-list hash does not match TEST_RECIPE.json")
print(path)
PY
) || { echo "INVALID: could not bind the popcount test list" >&2; exit 2; }

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$test_list"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" popcount "$1"
python3 "$script_directory/evaluate_ports.py" "$1"
