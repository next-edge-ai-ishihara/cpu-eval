#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate.scala>" >&2
  exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
problem="$(cd "$here/.." && pwd)"
repo="${REPO:?Set REPO to the pinned Rift2Core checkout}"
patch_file="$here/io-lsu-aclint-readback.patch"
expected_patch="acdd3655d966666dbf7f71a9209a32f30912ca1e72abcb4499476d456441946a"
if [ "$(sha256sum "$patch_file" | cut -d' ' -f1)" != "$expected_patch" ]; then
  echo "fixed test patch hash mismatch" >&2
  exit 2
fi

work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/rift/tb/sw" "$work/images" || exit 2
cp -a "$repo/tb/sw/clint_Plic" "$work/rift/tb/sw/" || exit 2
patch -l --dry-run -p1 -d "$work/rift" <"$patch_file" >/dev/null || exit 2
patch -l -p1 -d "$work/rift" <"$patch_file" >/dev/null || exit 2
make -C "$work/rift/tb/sw/clint_Plic" clean >/dev/null 2>&1 || true
make -C "$work/rift/tb/sw/clint_Plic" || exit 2
cp "$work/rift/tb/sw/clint_Plic/clint_plic.elf" "$work/images/io-lsu-aclint-readback" || exit 2
cp "$work/rift/tb/sw/clint_Plic/clint_plic.verilog" "$work/images/io-lsu-aclint-readback.verilog" || exit 2

DROMAJO_RIFT_ACLINT_MAP=1 TEST_IMAGE_DIR="$work/images" TEST_NAME_PATTERN=io-lsu-aclint-readback \
  "$problem/../_shared/evaluate.sh" "$problem" "$1"
