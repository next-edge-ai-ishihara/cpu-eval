#!/usr/bin/env bash
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CPU_DIR=$(cd "$HERE/../.." && pwd)
REPO=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
TEST_REV=a5a49fc9f244192649e57fe61b4513d9bc39b1e3
UPSTREAM=riscv-test-suite/rv32i_m/I/src/add-01.S
EXPECTED_SHA=3bebcf35d726e721011bcf98781e16f635b8cb7acd95a399e61985f34b5f1ce8

WORK=$(mktemp -d)
tmp=$WORK/upstream.S
GENERATED=$WORK/ariane-regfile-01.S
TESTLIST=$WORK/testlist_ariane_regfile.yaml
trap 'rm -rf "$WORK"' EXIT INT TERM
cp "$HERE/testlist_ariane_regfile.yaml" "$TESTLIST" || exit 2
git -C "$REPO/verif/tests/riscv-arch-test" show "$TEST_REV:$UPSTREAM" >"$tmp" || exit 2
patch --quiet "$tmp" "$HERE/0001-observe-delayed-register-read.patch" \
  -o "$GENERATED" || exit 2
actual=$(sha256sum "$GENERATED" | cut -d' ' -f1)
if [ "$actual" != "$EXPECTED_SHA" ]; then
  echo "generated test hash mismatch: $actual" >&2
  exit 2
fi
python3 - "$TESTLIST" "$GENERATED" <<'PY' || exit 2
from pathlib import Path
import sys

testlist = Path(sys.argv[1])
generated = Path(sys.argv[2])
placeholder = "<path_var>/cpu-eval-patches/ariane-regfile-01.S"
text = testlist.read_text(encoding="utf-8")
if text.count(placeholder) != 1:
    raise SystemExit("the Ariane register-file test path is missing or duplicated")
testlist.write_text(text.replace(placeholder, str(generated)), encoding="utf-8")
PY

CVA6_TESTLIST="$TESTLIST" \
  "$CPU_DIR/harness/evaluate_parallel.sh" ariane_regfile "$1"
status=$?
exit "$status"
