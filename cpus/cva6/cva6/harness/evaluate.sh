#!/usr/bin/env bash
set -uo pipefail

CANDIDATE=${1:-}
if [ -z "$CANDIDATE" ] || [ ! -f "$CANDIDATE" ]; then
  echo "usage: evaluate.sh <candidate-cva6.sv>" >&2
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
COMMON_EVALUATOR="$HARNESS_DIR/../../harness/evaluate_parallel.sh"
LOG_ROOT=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}
REPO=$lock_repo
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
TEST_REPO=$REPO/verif/tests/riscv-arch-test

if [ ! -d "$TEST_REPO/.git" ] || [ "$(git -C "$TEST_REPO" rev-parse HEAD)" != "$TEST_REV" ]; then
  echo "the architectural-test checkout is not at its recorded revision" >&2
  exit 2
fi

scratch=$(mktemp -d) || exit 2
trap 'rm -rf "$scratch"' EXIT INT TERM
mkdir -p "$scratch/cpu-eval-patches" || exit 2
for patch in "$PROBLEM_DIR"/tests/*.patch; do
  git -C "$scratch" apply "$patch" || {
    echo "INVALID: problem-specific test patch failed" >&2
    exit 2
  }
done

stage_test() {
  name=$1
  expected=$2
  source="$scratch/cpu-eval-patches/$name"
  if ! test "$(sha256sum "$source" | cut -d' ' -f1)" = "$expected" ||
     ! mkdir -p "$REPO/verif/tests/cpu-eval-patches" ||
     ! cp "$source" "$REPO/verif/tests/cpu-eval-patches/"; then
    echo "INVALID: reconstructed test could not be verified or copied into the CVA6 test tree" >&2
    exit 2
  fi
}
stage_test cva6_cvxif_add.S 2fc438a7b3e39f9bb158770da5e8d72d2237932270064b98f6a90f9c76b7cd31
stage_test cva6_csr_sequence.S dec9ace0cb8657f2091b4689358df39d6e5572face10771aa9d95cf38bf794d3
stage_test cva6_csr_illegal.S 4cc1cbd41b1b4bc32807be9d849119adb0a7e81ce94dedd966cf51678b0d7800
stage_test cva6_ecall.S 068179cc3ac739d16df4461bead22d085d01a769ed93c9742734fe682dc9abae
stage_test cva6_wfi.S ab815f45d41b75ed54c2492d807d3627dccc5c9d2cc67c640ba3845c2ad07a89

CVA6_TESTLIST="$HARNESS_DIR/testlist_cva6.yaml" \
CPU_EVAL_LOG_ROOT="$LOG_ROOT/instruction-traces" \
  "$COMMON_EVALUATOR" cva6 "$CANDIDATE"
TRACE_RC=$?

CPU_EVAL_LOG_ROOT="$LOG_ROOT/store-updates" \
  "$HARNESS_DIR/evaluate_store_updates.sh" "$CANDIDATE"
STORE_RC=$?

# A definite mismatch outranks a check that could not finish.
if [ "$TRACE_RC" -eq 1 ] || [ "$STORE_RC" -eq 1 ]; then
  echo "FAIL: instruction traces or store updates mismatched"
  exit 1
fi
if [ "$TRACE_RC" -ne 0 ] || [ "$STORE_RC" -ne 0 ]; then
  echo "INVALID: one or both CPU regressions did not complete" >&2
  exit 2
fi
echo "PASS: instruction traces and store updates matched"
exit 0
