#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_fxarb.sv>" >&2
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

bash "$script_directory/evaluate_ports.sh" "$1"

patch_file="$problem_directory/test-patches/route_data_bits_through_fxarb.patch"
applied_patch_repos=()
applied_patch_files=()
restore_integration() {
  status=$?
  trap - EXIT INT TERM
  failed=0
  for ((index=${#applied_patch_files[@]}-1; index>=0; index--)); do
    if ! git -C "${applied_patch_repos[index]}" apply --reverse "${applied_patch_files[index]}"; then
      echo "INVALID: cannot restore ${applied_patch_files[index]}" >&2
      failed=1
    fi
  done
  if [ "$failed" -ne 0 ]; then
    exit 2
  fi
  exit "$status"
}
trap restore_integration EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$CVA6_REPO" apply --check "$patch_file" || exit 2
git -C "$CVA6_REPO" apply "$patch_file" || exit 2
applied_patch_repos+=("$CVA6_REPO")
applied_patch_files+=("$patch_file")

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_fxarb "$1"
