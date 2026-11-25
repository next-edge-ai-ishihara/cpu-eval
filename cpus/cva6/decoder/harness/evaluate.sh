#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
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
test_repo="$repo/verif/tests/riscv-arch-test"
test_revision=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
test_path=riscv-test-suite/rv32i_m/C/src/cebreak-01.S
patch="$cpu_directory/harness/normalize-initial-mtvec.patch"

invalid() {
  echo "INVALID: $1" >&2
  exit 2
}
test -d "$test_repo/.git" && test -f "$patch" &&
  test "$(git -C "$test_repo" rev-parse HEAD)" = "$test_revision" ||
  invalid "the architectural-test checkout or its mtvec patch does not match the recorded revision"

exec 8>"$test_repo.cpu-eval-test-patch.lock" || invalid "cannot open the test-patch lock"
flock 8 || invalid "cannot take the test-patch lock"
restore_test() {
  temporary=$(mktemp -p "$(dirname "$test_repo/$test_path")" .cpu-eval-test-XXXXXX)
  if ! git -C "$test_repo" show "$test_revision:$test_path" >"$temporary" || \
     ! install -m 644 "$temporary" "$test_repo/$test_path"; then
    rm -f "$temporary"
    return 1
  fi
  rm -f "$temporary"
  test "$(sha256sum "$test_repo/$test_path" | cut -d' ' -f1)" = \
    a2b5f95de5f9faaea2161c81af270c57c53a16ddadcb11f7df87697ba41c48fc
}
finish_evaluation() {
  status=$?
  trap - EXIT INT TERM
  if ! restore_test; then
    echo "INVALID: fixed architectural-test source could not be restored" >&2
    status=2
  fi
  exit "$status"
}
trap finish_evaluation EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
restore_test || exit 2
git -C "$test_repo" apply "$patch" || invalid "the mtvec patch failed"
if [ "$(sha256sum "$test_repo/$test_path" | cut -d' ' -f1)" != c944a3d85fd5fccdd4930542089504fcd3f2a25da640d4fed1d1bb3c4f9ea9ae ]; then
  echo "INVALID: reconstructed cebreak program hash differs" >&2
  exit 2
fi

export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x_full.yaml"
export CVA6_TEST_JOBS=4
set +e
CPU_EVAL_LOG_ROOT="${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}/instruction-traces" \
  "$cpu_directory/harness/evaluate_parallel.sh" decoder "$1"
instruction_rc=$?
CPU_EVAL_LOG_ROOT="${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}/control-traces" \
  "$script_directory/evaluate_control.sh" "$1"
control_rc=$?
set -e

# A definite mismatch outranks a check that could not finish.
if [ "$instruction_rc" -eq 1 ] || [ "$control_rc" -eq 1 ]; then
  echo "FAIL: an instruction or control architectural trace mismatched"
  exit 1
fi
if [ "$instruction_rc" -ne 0 ] || [ "$control_rc" -ne 0 ]; then
  echo "INVALID: an instruction or control regression did not complete" >&2
  exit 2
fi
echo "PASS: instruction and control architectural traces matched"
exit 0
