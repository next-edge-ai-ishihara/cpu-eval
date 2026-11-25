#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_prio_1hot_encoder.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)
if [ -z "${CVA6_REPO:-}" ]; then
  echo "INVALID: CVA6_REPO is required" >&2
  exit 2
fi

python3 "$script_directory/evaluate_ports.py" "$1"

if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$CVA6_REPO.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $CVA6_REPO" >&2
    exit 2
  fi
else
  if ! { exec 9>"$CVA6_REPO.cpu-eval.lock"; }; then
    echo "INVALID: cannot open evaluation lock for $CVA6_REPO" >&2
    exit 2
  fi
fi
flock -n 9 || { echo "another evaluation owns $CVA6_REPO" >&2; exit 2; }
export CVA6_EVALUATION_LOCK_FD=9

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_prio_1hot_encoder "$1"
