#!/usr/bin/env bash
set -uo pipefail

candidate=${1:-}
if [ -z "$candidate" ] || [ ! -f "$candidate" ]; then
  echo "usage: evaluate.sh <candidate-cvxif_compressed_if_driver.sv>" >&2
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

harness_dir=$(cd "$(dirname "$0")" && pwd)
package_dir=$(cd "$harness_dir/.." && pwd)
repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
test_output="$repo/verif/tests/cpu-eval-patches/compressed_instr_decoder_table.S"
scratch=$(mktemp -d)
cleanup() {
  if [ -d "$scratch" ]; then
    find "$scratch" -depth -delete
  fi
}
trap cleanup EXIT INT TERM

git -C "$scratch" apply "$package_dir/../compressed_instr_decoder/tests/0001-add-compressed-cvxif-table-test.patch" || exit 2
reconstructed="$scratch/cpu-eval-patches/compressed_instr_decoder_table.S"
test "$(sha256sum "$reconstructed" | cut -d' ' -f1)" = \
  d43d1f1774003378202ad0a55cfa9d71e1c36a5ab492afe3b58a9fa19c88e6a9 || exit 2
mkdir -p "$(dirname "$test_output")" || exit 2
install -m 644 "$reconstructed" "$test_output" || exit 2
install -m 644 "$harness_dir/rejected_compressed.S" "$(dirname "$test_output")/" || exit 2
testlist="$scratch/testlist.yaml"
cat "$harness_dir/../../compressed_instr_decoder/harness/testlist_compressed_instr_decoder.yaml" \
  "$harness_dir/rejected_compressed.yaml" > "$testlist" || exit 2

CVA6_TESTLIST="$testlist" \
  "$harness_dir/../../harness/evaluate_parallel.sh" \
    cvxif_compressed_if_driver "$candidate"
