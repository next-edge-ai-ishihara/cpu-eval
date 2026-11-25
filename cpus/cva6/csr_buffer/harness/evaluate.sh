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

HARNESS_DIR=$(cd "$(dirname "$0")" && pwd)
PROBLEM_DIR=$(cd "$HARNESS_DIR/.." && pwd)
SHARED_EVALUATOR=$(cd "$PROBLEM_DIR/../harness" && pwd)/evaluate.sh
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
TEST_REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}/verif/tests/riscv-arch-test
EXPECTED_TEST_SHA=c42354102e665ac5793070d624ef0d1bead9df218206290901732b8bb6831cb8

if [ ! -d "$TEST_REPO/.git" ] || [ "$(git -C "$TEST_REPO" rev-parse HEAD)" != "$TEST_REV" ]; then
  echo "the architectural-test checkout is not at its recorded revision" >&2
  exit 2
fi

invalid() {
  echo "INVALID: $1" >&2
  exit 2
}
scratch=$(mktemp -d) || invalid "cannot create a scratch directory"
trap 'rm -rf "$scratch"' EXIT INT TERM
mkdir -p "$scratch/cpu-eval-patches" || invalid "cannot create the scratch test directory"
for patch in \
  "$PROBLEM_DIR/tests/0001-add-csr-buffer-sequence.patch" \
  "$PROBLEM_DIR/tests/0002-delay-csr-retirement-with-cache-miss.patch" \
  "$PROBLEM_DIR/tests/0003-exercise-csr-triggered-flush.patch"
do
  git -C "$scratch" apply "$patch" || invalid "test patch $(basename "$patch") failed"
done
test "$(sha256sum "$scratch/cpu-eval-patches/csr_buffer_sequence.S" | cut -d' ' -f1)" = "$EXPECTED_TEST_SHA" ||
  invalid "reconstructed csr_buffer_sequence.S differs from its recorded SHA-256"
test_output=$CVA6_REPO/verif/tests/cpu-eval-patches
mkdir -p "$test_output" || invalid "cannot create the test directory"
cp "$scratch/cpu-eval-patches/csr_buffer_sequence.S" "$test_output/" || invalid "cannot stage csr_buffer_sequence.S"

CVA6_TESTLIST="$HARNESS_DIR/testlist_csr_buffer.yaml" \
  "$SHARED_EVALUATOR" csr_buffer "$1"

python3 "$HARNESS_DIR/evaluate_flush_ports.py" "$1"
