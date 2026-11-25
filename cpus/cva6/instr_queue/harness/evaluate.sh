#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-instr_queue.sv>" >&2
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

script_directory=$(cd "$(dirname "$0")" && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_id_transport.yaml"
export CVA6_TEST_JOBS=1
set +e
"$cpu_directory/harness/evaluate_parallel.sh" instr_queue "$1"
directed_rc=$?
set -e

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
set +e
"$cpu_directory/harness/evaluate_parallel.sh" instr_queue "$1"
standard_rc=$?
set -e

# A definite mismatch outranks a check that could not finish.
if [ "$directed_rc" -eq 1 ] || [ "$standard_rc" -eq 1 ]; then
  exit 1
fi
if [ "$directed_rc" -ne 0 ] || [ "$standard_rc" -ne 0 ]; then
  exit 2
fi

python3 "$script_directory/evaluate_queue_ports.py" "$1"
