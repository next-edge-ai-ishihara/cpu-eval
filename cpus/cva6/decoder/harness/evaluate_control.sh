#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: evaluate_control.sh <candidate-systemverilog>" >&2
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

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
invalid() {
  echo "INVALID: $1" >&2
  exit 2
}
scratch=$(mktemp -d) || invalid "cannot create a scratch directory"
cleanup() {
  if [ -d "$scratch" ]; then
    find "$scratch" -depth -delete
  fi
}
trap cleanup EXIT INT TERM
mkdir -p "$scratch/cpu-eval-patches" || invalid "cannot create the scratch test directory"
for patch in "$CPU_DIR/cva6"/tests/*.patch; do
  git -C "$scratch" apply "$patch" || invalid "test patch $(basename "$patch") failed"
done

mkdir -p "$REPO/verif/tests/cpu-eval-patches" || invalid "cannot create the test directory"
stage_test() {
  source_path="$scratch/cpu-eval-patches/$1"
  test "$(sha256sum "$source_path" | cut -d' ' -f1)" = "$2" ||
    invalid "reconstructed $1 differs from its recorded SHA-256"
  install -m 644 "$source_path" "$REPO/verif/tests/cpu-eval-patches/$1" || invalid "cannot stage $1"
}
stage_test cva6_csr_sequence.S dec9ace0cb8657f2091b4689358df39d6e5572face10771aa9d95cf38bf794d3
stage_test cva6_csr_illegal.S 4cc1cbd41b1b4bc32807be9d849119adb0a7e81ce94dedd966cf51678b0d7800
stage_test cva6_ecall.S 068179cc3ac739d16df4461bead22d085d01a769ed93c9742734fe682dc9abae
stage_test cva6_wfi.S ab815f45d41b75ed54c2492d807d3627dccc5c9d2cc67c640ba3845c2ad07a89
cleanup || exit 2

export TB_PATH="$REPO/verif/tb/core"
export CVA6_TESTLIST="$SCRIPT_DIR/testlist_control.yaml"
export CVA6_TEST_JOBS=4
exec "$CPU_DIR/harness/evaluate_parallel.sh" decoder "$1"
