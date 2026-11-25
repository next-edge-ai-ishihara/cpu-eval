#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-pmp.sv>" >&2
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

python3 "$script_directory/check_write_ports.py" "$(realpath "$1")" || exit $?

integration_patch="$problem_directory/test-patches/adapt_custom_runtime_to_arch_linker.patch"
directed_test_patch="$problem_directory/test-patches/add_pmp_load_permissions_test.patch"
integration_target="$CVA6_REPO/verif/tests/custom/common/crt.S"
integration_reference_sha=eadeca60440673c2e6f1208268943ee7f0643ece7886fae62aedeead59a7638d
if [ "$(sha256sum "$integration_target" | cut -d' ' -f1)" != "$integration_reference_sha" ]; then
  echo "verif/tests/custom/common/crt.S is not the recorded reference runtime" >&2
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
git -C "$CVA6_REPO" apply --check "$directed_test_patch" || exit 2
git -C "$CVA6_REPO" apply "$directed_test_patch" || exit 2
applied_patch_repos+=("$CVA6_REPO")
applied_patch_files+=("$directed_test_patch")

export CVA6_TARGET=cv64a6_imafdc_sv39
export CVA6_TESTLIST="$script_directory/testlist_pmp.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" pmp "$1"
