#!/usr/bin/env python3
"""Build reproducible BOOM directed-test executables from recorded sources."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checksum_line(path: Path, name: str) -> str:
    return f"{sha256(path)}  {name}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--riscv-tests", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--gcc", default="riscv64-unknown-elf-gcc")
    parser.add_argument("--ld", default="riscv64-unknown-elf-ld")
    parser.add_argument("--nm", default="riscv64-unknown-elf-nm")
    parser.add_argument("--strip", default="riscv64-unknown-elf-strip")
    return parser.parse_args()


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def require_host_symbols(nm: str, executable: Path) -> None:
    result = subprocess.run(
        [nm, "-B", str(executable)],
        check=True,
        capture_output=True,
        text=True,
    )
    symbols = {
        fields[-1]
        for line in result.stdout.splitlines()
        if len(fields := line.split()) >= 2
    }
    missing = {"tohost", "fromhost"} - symbols
    if missing:
        raise ValueError(
            f"CPU test executable lacks host communication symbols "
            f"{sorted(missing)}: {executable}"
        )


def stripped_sha256(strip: str, executable: Path) -> str:
    """GCC may embed a random temporary-object name in an executable symbol."""
    with tempfile.TemporaryDirectory(prefix="cpu-eval-boom-elf-") as temporary:
        normalized = Path(temporary) / executable.name
        shutil.copyfile(executable, normalized)
        run([strip, "--strip-all", str(normalized)])
        return sha256(normalized)


def directed_test_names(assets: list[dict]) -> set[str]:
    names = {asset["name"] for asset in assets}
    if len(names) != len(assets):
        raise ValueError("directed-test manifest contains duplicate asset names")
    return names


def required_upstream_tests(source_root: Path, directed_names: set[str]) -> set[str]:
    required: set[str] = set()
    for path in source_root.glob("cpus/boom/*/TESTS.txt"):
        for line in path.read_text(encoding="utf-8").splitlines():
            name = line.split("#", 1)[0].strip()
            if name.startswith("rv64") and name not in directed_names:
                required.add(name)
    return required


UPSTREAM_TEST_PATTERN = re.compile(r"^(rv64[a-z0-9]+)-p-(.+)$")


def upstream_source(riscv_tests: Path, name: str) -> Path:
    match = UPSTREAM_TEST_PATTERN.fullmatch(name)
    if match is None:
        raise ValueError(f"unsupported upstream test name: {name}")
    suite, test = match.groups()
    return riscv_tests / "isa" / suite / f"{test}.S"


def upstream_gcc_command(compiler: str, riscv_tests: Path, source: Path, output: Path) -> list[str]:
    return [
        compiler,
        "-march=rv64g",
        "-mabi=lp64",
        "-static",
        "-mcmodel=medany",
        "-fvisibility=hidden",
        "-nostdlib",
        "-nostartfiles",
        f"-I{riscv_tests / 'env/p'}",
        f"-I{riscv_tests / 'isa/macros/scalar'}",
        f"-T{riscv_tests / 'env/p/link.ld'}",
        str(source),
        "-o",
        str(output),
    ]


def gcc_command(
    compiler: str,
    profile: str,
    riscv_tests: Path,
    source: Path,
    output: Path,
) -> list[str]:
    common = [
        compiler,
        "-static",
        "-mcmodel=medany",
        "-nostdlib",
        "-nostartfiles",
        f"-I{riscv_tests / 'env/p'}",
        f"-I{riscv_tests / 'isa/macros/scalar'}",
        f"-T{riscv_tests / 'env/p/link.ld'}",
    ]
    if profile == "common":
        flags = ["-march=rv64g", "-mabi=lp64", "-fvisibility=hidden"]
    elif profile == "predictor":
        flags = ["-march=rv64imafdc", "-mabi=lp64", "-fvisibility=hidden"]
    elif profile == "full":
        flags = [
            "-march=rv64imafdc_zicsr_zifencei",
            "-mabi=lp64d",
            "-std=gnu99",
            "-O2",
            "-fno-common",
            "-fno-builtin-printf",
            "-Wl,--no-relax",
        ]
    else:
        raise ValueError(f"unsupported GCC profile: {profile}")
    return [*common, *flags, str(source), "-o", str(output)]


def main() -> int:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 2:
        raise ValueError("unsupported manifest schema")
    args.output.mkdir(parents=True, exist_ok=True)
    names = directed_test_names(manifest["assets"])
    for name in sorted(required_upstream_tests(args.source_root, names)):
        output = args.output / name
        if not output.is_file():
            source = upstream_source(args.riscv_tests, name)
            if not source.is_file():
                raise FileNotFoundError(f"required upstream test source is missing: {source}")
            run(upstream_gcc_command(args.gcc, args.riscv_tests, source, output))
        require_host_symbols(args.nm, output)
        output.chmod(0o755)
        print(checksum_line(output, name))
    for asset in manifest["assets"]:
        name = asset["name"]
        source = args.source_root / asset["source"]
        if sha256(source) != asset["source_sha256"]:
            raise ValueError(f"source hash mismatch: {source}")
        output = args.output / name
        profile = asset["profile"]
        if profile == "uncached_msip":
            linker_script = args.source_root / asset["linker_script"]
            if sha256(linker_script) != asset["linker_script_sha256"]:
                raise ValueError(f"linker script hash mismatch: {linker_script}")
            object_file = args.output / f"{name}.o"
            run([
                args.gcc,
                "-march=rv64imafd",
                "-mabi=lp64d",
                "-c",
                "-o",
                str(object_file),
                str(source),
            ])
            run([
                args.ld,
                "-T",
                str(linker_script),
                "--build-id=none",
                "-o",
                str(output),
                str(object_file),
            ])
            object_file.unlink()
        else:
            run(gcc_command(args.gcc, profile, args.riscv_tests, source, output))
            require_host_symbols(args.nm, output)
        normalized = stripped_sha256(args.strip, output)
        expected = asset.get("stripped_elf_sha256")
        if normalized != expected:
            raise ValueError(
                f"stripped ELF hash mismatch for {name}: expected {expected}, got {normalized}"
            )
        output.chmod(0o755)
        print(checksum_line(output, name))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
