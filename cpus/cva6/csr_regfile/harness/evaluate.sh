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
for patch in "$PROBLEM_DIR"/tests/*.patch; do
  git -C "$scratch" apply "$patch" || invalid "test patch $(basename "$patch") failed"
done

test_output=$CVA6_REPO/verif/tests/cpu-eval-patches
mkdir -p "$test_output" || invalid "cannot create the test directory"
check_and_stage() {
  source="$scratch/cpu-eval-patches/$1"
  test "$(sha256sum "$source" | cut -d' ' -f1)" = "$2" ||
    invalid "reconstructed $1 differs from its recorded SHA-256"
  cp "$source" "$test_output/" || invalid "cannot stage $1"
}
check_and_stage csr_regfile_sequence.S dec9ace0cb8657f2091b4689358df39d6e5572face10771aa9d95cf38bf794d3
check_and_stage csr_regfile_illegal.S 4cc1cbd41b1b4bc32807be9d849119adb0a7e81ce94dedd966cf51678b0d7800
check_and_stage csr_regfile_ecall.S 068179cc3ac739d16df4461bead22d085d01a769ed93c9742734fe682dc9abae
check_and_stage csr_regfile_wfi.S ab815f45d41b75ed54c2492d807d3627dccc5c9d2cc67c640ba3845c2ad07a89

port_output="${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT}/csr_regfile/wfi-ports-$(date -u +%Y-%m-%dT%H%M%SZ)-$$"
(
  # The pinned upstream setup script reads optional variables before assigning defaults.
  set +u
  source "${CVA6_ENVFILE:?Set CVA6_ENVFILE}" || {
    echo "INVALID: CVA6 environment setup failed" >&2
    exit 2
  }
  set -u
  python3 "$HARNESS_DIR/check_wfi_ports.py" --cpu-repo "$lock_repo" \
    --candidate "$1" --output "$port_output"
)

CVA6_TESTLIST="$HARNESS_DIR/testlist_csr_regfile.yaml" \
  "$SHARED_EVALUATOR" csr_regfile "$1"
