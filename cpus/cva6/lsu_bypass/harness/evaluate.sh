#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-lsu_bypass.sv>" >&2
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
cpu_directory=$(cd "$script_directory/../.." && pwd)

integration_patch="$problem_directory/test-patches/force_fifo_residency.patch"
integration_target="$CVA6_REPO/core/load_store_unit.sv"
integration_reference_sha=ce091f34f60e489a79d335548355e7d69e7dcd3982f8ece835ce9df2baf72a78
if [ "$(sha256sum "$integration_target" | cut -d' ' -f1)" != "$integration_reference_sha" ]; then
  echo "core/load_store_unit.sv is not the recorded reference before LSU bypass activation" >&2
  exit 2
fi
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
git -C "$CVA6_REPO" apply --check "$integration_patch" || exit 2
git -C "$CVA6_REPO" apply "$integration_patch" || exit 2
applied_patch_repos+=("$CVA6_REPO")
applied_patch_files+=("$integration_patch")

# The ordinary build key does not include test-only integration patches.
rm -f "$CVA6_REPO/work-ver/.cpu-eval-build-key"

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_lsu_bypass.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" lsu_bypass "$1"
python3 "$script_directory/evaluate_ports.py" "$1"
