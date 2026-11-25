#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_rrarb.sv>" >&2
  exit 2
fi

lock_repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$lock_repo.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $lock_repo" >&2
    exit 2
  fi
else
  exec 9>"$lock_repo.cpu-eval.lock" || { echo "INVALID: cannot open the evaluation lock" >&2; exit 2; }
fi
flock -n 9 || { echo "INVALID: another evaluation owns $lock_repo" >&2; exit 2; }
export CVA6_EVALUATION_LOCK_FD=9
export CVA6_TARGET=cv32a60x

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)
python3 "$script_directory/evaluate_ports.py" "$1"

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_rrarb "$1"
