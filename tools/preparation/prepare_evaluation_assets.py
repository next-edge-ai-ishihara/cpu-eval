#!/usr/bin/env python3
"""Prepare reusable Ibex or VexRiscv sources and test programs."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

sys.dont_write_bytecode = True


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fetch_revision(url: str, revision: str, output: Path) -> None:
    subprocess.run(["git", "init", "--quiet", str(output)], check=True)
    subprocess.run(["git", "-C", str(output), "remote", "add", "origin", url], check=True)
    subprocess.run(
        ["git", "-C", str(output), "fetch", "--quiet", "--depth", "1", "origin", revision],
        check=True,
    )
    subprocess.run(["git", "-C", str(output), "checkout", "--quiet", "--detach", "FETCH_HEAD"], check=True)
    actual = subprocess.check_output(["git", "-C", str(output), "rev-parse", "HEAD"], text=True).strip()
    if actual != revision:
        raise ValueError(f"source revision mismatch: expected {revision}, got {actual}")

def run_logged(command: list[str], cwd: Path, log: Path) -> None:
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as stream:
        subprocess.run(command, cwd=cwd, env={**os.environ, "PWD": str(cwd.resolve())},
                       check=True, stdout=stream, stderr=subprocess.STDOUT)

def fetch_archive(url: str, expected_sha256: str, output: Path) -> None:
    temporary = output.with_suffix(output.suffix + ".tmp")
    urllib.request.urlretrieve(url, temporary)
    if sha256(temporary) != expected_sha256:
        temporary.unlink()
        raise ValueError(f"downloaded archive hash mismatch: {url}")
    os.replace(temporary, output)

def prepare_ibex_assets(repo: Path, destination: Path, adapter: dict[str, object]) -> None:
    assets = destination / "assets"
    assets.mkdir()
    sources = adapter["sources"]
    ibex = assets / "ibex-source"
    fetch_revision(sources["ibex"]["url"], sources["ibex"]["revision"], ibex)
    subprocess.run([
        "git", "-C", str(ibex), "submodule", "update", "--init", "--recursive", "--depth", "1"
    ], check=True)

    spike_install = assets / "spike-install"
    archive_cache = destination / "downloads"
    archive_cache.mkdir(parents=True, exist_ok=True)
    spike_archive = archive_cache / f"{sources['spike']['archive_sha256']}.tar.gz"
    spike_runtime_prefix = Path("/mnt/assets/spike-install")
    logs = assets / "build-logs"
    if (
        not spike_archive.is_file()
        or sha256(spike_archive) != sources["spike"]["archive_sha256"]
    ):
        fetch_archive(sources["spike"]["url"], sources["spike"]["archive_sha256"], spike_archive)
    with tarfile.open(spike_archive) as archive:
        archive.extractall(destination, filter="data")
    shutil.move(destination / "riscv-isa-sim", spike_install)
    if not (spike_install / "bin/spike").is_file():
        raise FileNotFoundError(spike_install / "bin/spike")
    for package_config in (spike_install / "lib/pkgconfig").glob("*.pc"):
        text = package_config.read_text(encoding="utf-8")
        package_config.write_text(
            text.replace("/tools/riscv-isa-sim", str(spike_runtime_prefix)),
            encoding="utf-8",
        )

    programs = assets / "programs"
    upstream_cache = assets / "upstream-programs"
    recipes: list[tuple[Path, dict[str, object]]] = []
    for recipe_path in sorted((repo / "cpus/ibex").glob("*/TEST_RECIPE.json")):
        recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
        if "problem" in recipe:
            recipes.append((recipe_path.parent, recipe))

    upstream_names = sorted({
        name
        for problem_directory, recipe in recipes
        for name in recipe["assigned_programs"]
        if not (problem_directory / "harness" / f"{name}.S").is_file()
    })
    upstream_cache.mkdir()
    ibex_debug_root = "/ibex"
    cflags = " ".join([
        "-march=rv32imc_zicsr", "-mabi=ilp32", "-static", "-mcmodel=medany",
        "-Wall", "-g", "-Os", "-fvisibility=hidden", "-nostdlib", "-nostartfiles",
        "-ffreestanding",
        f"-ffile-prefix-map={ibex}={ibex_debug_root}",
        f"-fdebug-prefix-map={ibex}={ibex_debug_root}",
        f"-fmacro-prefix-map={ibex}={ibex_debug_root}",
    ])
    for name in upstream_names:
        run_logged([
            "make", "-B", "-C", str(ibex / "examples/sw/simple_system" / name),
            "ARCH=rv32imc_zicsr", "CC=riscv64-unknown-elf-gcc",
            "OBJCOPY=riscv64-unknown-elf-objcopy", f"CFLAGS={cflags}", f"{name}.elf",
        ], repo, logs / f"program-{name}.log")
        shutil.copy2(ibex / "examples/sw/simple_system" / name / f"{name}.elf", upstream_cache / f"{name}.elf")

    with tempfile.TemporaryDirectory(prefix="cpu-eval-ibex-directed-") as temporary:
        for problem_directory, recipe in recipes:
            problem = str(recipe["problem"])
            output = programs / problem
            output.mkdir(parents=True)
            expected_hashes = {str(row["name"]): str(row["elf_sha256"]) for row in recipe["programs"]}
            expected_hashes.update({
                Path(str(row["source"])).stem: str(row["elf_sha256"])
                for row in recipe["problem_specific_additions"]
                if "source" in row and "elf_sha256" in row
            })
            for name in recipe["assigned_programs"]:
                directed = problem_directory / "harness" / f"{name}.S"
                elf = output / f"{name}.elf"
                expected = expected_hashes.get(name)
                if expected is None:
                    raise ValueError(f"no recorded ELF hash for {problem}/{name}")
                if directed.is_file():
                    run_logged([
                        str(repo / "cpus/ibex/harness/build_directed_test.sh"),
                        str(ibex), str(directed), str(elf),
                    ], repo, logs / f"program-{problem}-{name}-repo-root.log")
                    if sha256(elf) != expected:
                        invocation = Path(temporary) / "invocation"
                        invocation.mkdir(exist_ok=True)
                        run_logged([
                            str(repo / "cpus/ibex/harness/build_directed_test.sh"),
                            str(ibex), str(directed), str(elf),
                        ], invocation, logs / f"program-{problem}-{name}-isolated.log")
                else:
                    shutil.copy2(upstream_cache / f"{name}.elf", elf)
                actual = sha256(elf)
                if actual != expected:
                    raise ValueError(f"ELF hash mismatch for {problem}/{name}: expected {expected}, got {actual}")

def prepare_vexriscv_assets(repo: Path, destination: Path, adapter: dict[str, object]) -> None:
    assets = destination / "assets"
    assets.mkdir()
    sources = adapter["sources"]
    vex = assets / "vexriscv-source"
    spinal = assets / "spinalhdl-source"
    fetch_revision(sources["vexriscv"]["url"], sources["vexriscv"]["revision"], vex)
    fetch_revision(sources["spinalhdl"]["url"], sources["spinalhdl"]["revision"], spinal)
    profiles = assets / "profiles"
    profiles.mkdir()
    preparer = repo / "cpus/vexriscv/harness/prepare_evaluation_checkout.py"
    for profile in ("spinal", "vex-standard", "debug"):
        subprocess.run([
            "python3", str(preparer),
            "--source-checkout", str(vex),
            "--spinal-source-checkout", str(spinal),
            "--repo", str(repo),
            "--profile", profile,
            "--output", str(profiles / profile),
        ], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cpu', choices=('ibex', 'vexriscv'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    if output.exists() or output == repo or repo in output.parents:
        parser.error('Output must be a new directory outside the repository')
    adapter = json.loads((repo / 'tools/evaluation/adapters.json').read_text())['adapters'][args.cpu]
    output.mkdir(parents=True)
    function = prepare_ibex_assets if args.cpu == 'ibex' else prepare_vexriscv_assets
    function(repo, output, adapter)
    print(output / 'assets')
    return 0


if __name__ == '__main__':
    sys.exit(main())
