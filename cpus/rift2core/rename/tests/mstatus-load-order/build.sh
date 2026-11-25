#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${BUILD_HEADERS:?Set BUILD_HEADERS to a directory holding the headers listed in BUILD_INPUTS.json}"
: "${OUT:?Set OUT to an output directory outside this distribution}"
gcc="${GCC:-riscv64-unknown-elf-gcc}"
objcopy="${OBJCOPY:-riscv64-unknown-elf-objcopy}"
name=rename_mstatus_load_order
mkdir -p "$OUT"
"$gcc" -save-temps=obj -march=rv64g -mabi=lp64 -static -mcmodel=medany -fvisibility=hidden \
  -nostdlib -nostartfiles -fcommon -I"$BUILD_HEADERS/env/p" -I"$BUILD_HEADERS/isa/macros/scalar" \
  -T"$BUILD_HEADERS/env/p/link.ld" "$here/source/$name.S" -o "$OUT/$name"
"$objcopy" -O verilog "$OUT/$name" "$OUT/$name.verilog"
python3 - "$OUT/$name.verilog" <<'PY'
from pathlib import Path
import sys

image = Path(sys.argv[1])
image.write_bytes(image.read_bytes().replace(b"@800", b"@000").replace(b"\r\n", b"\n"))
PY
