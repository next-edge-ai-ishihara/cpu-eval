#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
asset_work="$1"
test "$(python3.12 -c 'import platform; print(platform.python_version())')" = 3.12.3
test ! -e "$asset_work"
mkdir -p "$asset_work"
assets="$asset_work/assets"
mkdir -p "$assets"
source_record="$(python3.12 -c 'import json, sys
source = json.load(open(sys.argv[1]))["adapters"]["veer_el2"]["sources"]["veer_el2"]
print(source["url"], source["revision"])' "$repo_root/tools/evaluation/adapters.json")"
read -r veer_url veer_revision <<<"$source_record"
git clone "$veer_url" "$assets/veer-el2-source"
git -C "$assets/veer-el2-source" checkout --detach "$veer_revision"
git -C "$assets/veer-el2-source" submodule update --init --recursive
test "$(git -C "$assets/veer-el2-source" rev-parse HEAD)" = "$veer_revision"
test "$(git -C "$assets/veer-el2-source/third_party/riscv-dv" rev-parse HEAD)" = da33551ab102c7530d7dadb803abf4c245ba08e0
git -C "$assets/veer-el2-source" apply "$repo_root/cpus/veer_el2/_shared/patches/veer-el2-riscv-dv-verilator.patch"
git -C "$assets/veer-el2-source/third_party/riscv-dv" apply "$repo_root/cpus/veer_el2/_shared/patches/riscv-dv-python-3.12.patch"

python3.12 -m venv "$asset_work/venv"
"$asset_work/venv/bin/python" -m pip install --no-deps -r "$repo_root/tools/preparation/veer-el2-generation-requirements.txt"
export PATH="$asset_work/venv/bin:$PATH"
cpu_source="$assets/veer-el2-source"
dv_source="$cpu_source/third_party/riscv-dv"
export PYTHONPATH="$dv_source/pygen"
(cd "$cpu_source/tools/riscv-dv" &&
python "$dv_source/run.py" \
  --simulator pyflow --test riscv_arithmetic_basic_test \
  --iss spike --iss_timeout 120 --start_seed 999 --iterations 1 --batch_size 1 \
  --isa rv32imc_zicsr_zifencei_zba_zbb_zbc_zbs --mabi ilp32 \
  --custom_target "$cpu_source/tools/riscv-dv" \
  --testlist "$cpu_source/tools/riscv-dv/testlist.yaml" \
  -v -o "$asset_work/generated" --steps gen)
python "$cpu_source/tools/riscv-dv/code_fixup.py" \
  -i "$asset_work/generated/asm_test/riscv_arithmetic_basic_test_0.S" \
  -o "$asset_work/once.S"
python "$cpu_source/tools/riscv-dv/code_fixup.py" \
  -i "$asset_work/once.S" -o "$asset_work/twice.S"
python - "$asset_work" "$assets" <<'PY'
import hashlib
from pathlib import Path
import shutil
import sys
work, assets = map(Path, sys.argv[1:])
expected = {
    'generated/asm_test/riscv_arithmetic_basic_test_0.S': 'a517527d47e564ec91a7212523785059b0d0541812fa19976983775a5d12201b',
    'once.S': '544e0547ce60f8d1a0a03221ed3dd16c59fda831ec40e45c56b097781dea8142',
    'twice.S': 'cd2056212ebc72c29568c38598cbf85a57173076fdf747a63c591288ae7b56ca',
}
for name, digest in expected.items():
    actual = hashlib.sha256((work / name).read_bytes()).hexdigest()
    if actual != digest:
        raise SystemExit(f'Generated source mismatch: {name}: {actual}')
target = assets / 'veer-generated-tests'
target.mkdir()
for name, digest in expected.items():
    shutil.copyfile(work / name, target / (digest + '.S'))
PY

bit_test_patch="$repo_root/cpus/veer_el2/_shared/patches/default-bitmanip-test.patch"
bit_target_patch="$repo_root/cpus/veer_el2/_shared/patches/riscv-dv-bitmanip-target.patch"
git -C "$cpu_source" apply "$bit_test_patch"
git -C "$dv_source" apply "$bit_target_patch"
(cd "$cpu_source/tools/riscv-dv" &&
python "$dv_source/run.py" \
  --simulator pyflow --test riscv_bitmanip_default_test_veer \
  --iss spike --iss_timeout 120 --start_seed 999 --iterations 1 --batch_size 1 \
  --isa rv32imc_zicsr_zifencei_zba_zbb_zbc_zbs --mabi ilp32 \
  --custom_target "$cpu_source/tools/riscv-dv" \
  --testlist "$cpu_source/tools/riscv-dv/testlist.yaml" \
  -v -o "$asset_work/generated-bitmanip" --steps gen)
python - "$asset_work" "$assets" <<'PYBIT'
import hashlib
from pathlib import Path
import shutil
import sys
work, assets = map(Path, sys.argv[1:])
source = work / 'generated-bitmanip/asm_test/riscv_bitmanip_default_test_veer_0.S'
expected = 'f2fe4f4ab9a73a383720f99b6ba4a8a1f8359b4eeaa979ff2a4c74495a68a339'
actual = hashlib.sha256(source.read_bytes()).hexdigest()
if actual != expected:
    raise SystemExit(f'Generated source mismatch: {source}: {actual}')
shutil.copyfile(source, assets / 'veer-generated-tests' / (expected + '.S'))
PYBIT
git -C "$dv_source" apply -R "$bit_target_patch"
git -C "$cpu_source" apply -R "$bit_test_patch"

mkdir "$assets/veer-generated-tests/origin-notices"
cp "$dv_source/LICENSE.txt" "$assets/veer-generated-tests/origin-notices/riscv-dv-LICENSE.txt"
sed -n '1,13p' "$dv_source/pygen/pygen_src/riscv_asm_program_gen.py" \
  > "$assets/veer-generated-tests/origin-notices/riscv_asm_program_gen-header.txt"
