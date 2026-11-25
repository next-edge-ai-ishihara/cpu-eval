#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-systemverilog>" >&2
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
repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
test_root=$repo/verif/tests
test_patch=$problem_directory/tests/0001-add-controller-tests.patch
expected_patch=39ff11ef6c7461cc48a9e06e4c3437a14d3495497131132cb37d5de12f2fc845

invalid() {
  echo "INVALID: $1" >&2
  exit 2
}
records=(
  controller_csr.S:07e9c620dfa11826c43db6a3afc41544ed64f9ddfd82d5607527dac419b94b7d
  controller_ecall.S:068179cc3ac739d16df4461bead22d085d01a769ed93c9742734fe682dc9abae
  controller_wfi_resume.S:ab815f45d41b75ed54c2492d807d3627dccc5c9d2cc67c640ba3845c2ad07a89
)
test "$(sha256sum "$test_patch" | cut -d' ' -f1)" = "$expected_patch" ||
  invalid "controller test patch differs from its recorded SHA-256"
for record in "${records[@]}"; do
  rm -f "$test_root/cpu-eval-patches/${record%%:*}" || invalid "cannot remove a previous controller test"
done
mkdir -p "$test_root/cpu-eval-patches" || invalid "cannot create the test directory"
git -C "$repo" apply --directory=verif/tests "$test_patch" || invalid "controller test patch failed"
for record in "${records[@]}"; do
  test "$(sha256sum "$test_root/cpu-eval-patches/${record%%:*}" | cut -d' ' -f1)" = "${record#*:}" ||
    invalid "reconstructed ${record%%:*} differs from its recorded SHA-256"
done

export CVA6_TESTLIST="$script_directory/testlist_controller.yaml"
export CVA6_TEST_JOBS=4
exec "$cpu_directory/harness/evaluate_parallel.sh" controller "$1"
