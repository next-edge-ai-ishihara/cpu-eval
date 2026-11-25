#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: build_directed_test.sh <Ibex checkout> <test.S> <output.elf>" >&2
  exit 2
fi

ibex=$(realpath "$1")
source_file=$(realpath "$2")
output=$(realpath -m "$3")
expected_revision=405c6d1d8220a18b2f9196141167a5875422dee4

test "$(git -c safe.directory="$ibex" -C "$ibex" rev-parse HEAD)" = "$expected_revision"
test -f "$source_file"
command -v riscv64-unknown-elf-gcc >/dev/null

common="$ibex/examples/sw/simple_system/common"
work=$(mktemp -d "${TMPDIR:-/tmp}/cpu-eval-ibex-directed-XXXXXX")
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

invocation_dir=$(pwd)
flags=(
  -march=rv32imc_zicsr -mabi=ilp32 -mcmodel=medany -Wall -g -Os
  -fvisibility=hidden -ffreestanding
  -ffile-prefix-map="$ibex"=/ibex
  -fdebug-prefix-map="$ibex"=/ibex
  -fmacro-prefix-map="$ibex"=/ibex
  -ffile-prefix-map="$(dirname "$source_file")"=/cpu-eval-test
  -fdebug-prefix-map="$(dirname "$source_file")"=/cpu-eval-test
  -fmacro-prefix-map="$(dirname "$source_file")"=/cpu-eval-test
  -ffile-prefix-map="$invocation_dir"=/cpu-eval-invocation
  -fdebug-prefix-map="$invocation_dir"=/cpu-eval-invocation
  -fmacro-prefix-map="$invocation_dir"=/cpu-eval-invocation
  -I"$common"
)

riscv64-unknown-elf-gcc "${flags[@]}" -c "$common/crt0.S" -o "$work/crt0.o"
objects=("$work/crt0.o")
while IFS= read -r source; do
  object="$work/$(basename "${source%.c}").o"
  riscv64-unknown-elf-gcc "${flags[@]}" -c "$source" -o "$object"
  objects+=("$object")
done < <(find "$common" -maxdepth 1 -type f -name '*.c' -print | LC_ALL=C sort)
riscv64-unknown-elf-gcc "${flags[@]}" -c "$source_file" -o "$work/test.o"
objects+=("$work/test.o")

mkdir -p "$(dirname "$output")"
riscv64-unknown-elf-gcc "${flags[@]}" -static -nostdlib -nostartfiles \
  -T "$common/link.ld" "${objects[@]}" -o "$output"
