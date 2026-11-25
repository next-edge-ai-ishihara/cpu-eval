#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
PATCH=$CPU_DIR/compressed_instr_decoder/tests/0001-add-compressed-cvxif-table-test.patch
FIXTURE=$(mktemp -d) || exit 2
trap 'rm -rf -- "$FIXTURE"' EXIT

if ! {
  test "$(sha256sum "$PATCH" | cut -d' ' -f1)" = fb50858d1a3adda165152f3571f5ffa5d8028118a42228742d30410eb349e3c0 &&
  (cd "$FIXTURE" && git apply "$PATCH") &&
  test "$(sha256sum "$FIXTURE/cpu-eval-patches/compressed_instr_decoder_table.S" | cut -d' ' -f1)" = d43d1f1774003378202ad0a55cfa9d71e1c36a5ab492afe3b58a9fa19c88e6a9 &&
  ln -s "$(realpath "$REPO")/verif/tests/riscv-arch-test" "$FIXTURE/riscv-arch-test";
}; then
  echo "INVALID: compressed instruction test reconstruction failed" >&2
  exit 2
fi

CPU_EVAL_MODULE=cvxif_example_coprocessor \
CVA6_TESTLIST="$SCRIPT_DIR/testlist_cvxif_example_coprocessor.yaml" \
CPU_EVAL_CVXIF_EXAMPLE_FIXTURE="$FIXTURE" \
  "$CPU_DIR/copro_alu/harness/evaluate.sh" "$@"
