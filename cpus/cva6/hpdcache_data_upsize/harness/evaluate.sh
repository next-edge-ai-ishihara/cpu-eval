#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_data_upsize.sv>" >&2
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
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

# The hpdcache_decoder and hpdcache_fxarb evaluators patch this file and must have restored it.
resize_source="$CVA6_REPO/core/cache_subsystem/hpdcache/rtl/src/common/hpdcache_data_resize.sv"
resize_sha=$(sha256sum "$resize_source" | cut -d' ' -f1) || exit 2
if [ "$resize_sha" != 0571f7068cef28d54d684d5faed566d09830b96686874f377545dfb48f1f7966 ]; then
  echo "INVALID: data resize source differs from the pinned source" >&2
  exit 2
fi

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_data_upsize "$1"
exec python3 "$script_directory/evaluate_ports.py" "$1"
