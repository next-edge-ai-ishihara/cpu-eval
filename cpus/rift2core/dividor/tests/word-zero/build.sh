#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${BUILD_HEADERS:?Set BUILD_HEADERS to a directory holding the headers listed in BUILD_INPUTS.json}"
GCC="${GCC:-riscv64-unknown-elf-gcc}"
OBJCOPY="${OBJCOPY:-riscv64-unknown-elf-objcopy}"
: "${OUT:?Set OUT to an output directory outside this distribution}"
mkdir -p "$OUT"
for name in divuw_zero remuw_zero divuw_control remuw_control; do
  "$GCC" -save-temps=obj -march=rv64g -mabi=lp64 -static -mcmodel=medany \
    -fvisibility=hidden -nostdlib -nostartfiles -fcommon \
    -I"$BUILD_HEADERS/env/p" -I"$BUILD_HEADERS/isa/macros/scalar" \
    -T"$BUILD_HEADERS/env/p/link.ld" "$HERE/source/$name.S" -o "$OUT/$name"
  "$OBJCOPY" -O verilog "$OUT/$name" "$OUT/$name.verilog"
  python3 - "$OUT/$name.verilog" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_bytes(p.read_bytes().replace(b"@800", b"@000"))
PY
done
