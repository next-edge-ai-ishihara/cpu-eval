#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-compressed_decoder.sv>" >&2
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

HERE=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$HERE/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
UPSTREAM=riscv-test-suite/rv32i_m/C/src/cebreak-01.S
GENERATED=$REPO/verif/tests/cpu-eval-patches/cebreak-01.S
EXPECTED_SHA=3a9136eeb7894289dc8d2a66f3fd625f5f8dbf41604d477ed6618a9a3ad91df7

tmp=$(mktemp)
trap 'rm -f "$tmp" "$GENERATED"' EXIT INT TERM
mkdir -p "$(dirname "$GENERATED")"
git -C "$REPO/verif/tests/riscv-arch-test" show "$TEST_REV:$UPSTREAM" >"$tmp" || exit 2
patch --quiet "$tmp" "$HERE/cebreak-normalize-mtvec.patch" -o "$GENERATED" || exit 2
rm -f "$tmp"
actual=$(sha256sum "$GENERATED" | cut -d' ' -f1)
if [ "$actual" != "$EXPECTED_SHA" ]; then
  echo "generated test hash mismatch: $actual" >&2
  exit 2
fi

CVA6_TESTLIST="$HERE/testlist_compressed_decoder.yaml" \
  "$CPU_DIR/harness/evaluate_parallel.sh" compressed_decoder "$1"
status=$?
if [ "$status" -ne 0 ]; then
  exit "$status"
fi
python3 "$HERE/check_zcb_ports.py" "$1"
