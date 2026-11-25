"""Patch sets for each VexRiscv evaluation profile and their recorded hashes."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


PROFILE_PATCHES = {
    "spinal": ("0001-enable-selected-csr-tests.patch", "0006-add-public-csr-observation.patch", "0007-stabilize-fixed-fetch-pc-name.patch", "0008-zero-unmapped-pmp-read.patch",
              "0010-extend-cycle-budgets.patch", "0011-bind-debug-server-to-free-port.patch",),
    "vex-standard": ("0001-enable-selected-csr-tests.patch", "0006-add-public-csr-observation.patch", "0007-stabilize-fixed-fetch-pc-name.patch", "0008-zero-unmapped-pmp-read.patch",
                     "0010-extend-cycle-budgets.patch", "0011-bind-debug-server-to-free-port.patch",),
    "debug": (
        "0006-add-public-csr-observation.patch",
        "0007-stabilize-fixed-fetch-pc-name.patch",
        "0001-enable-selected-csr-tests.patch",
        "0002-enable-debug-plugin-test.patch",
        "0003-report-debug-trace-mismatch.patch",
        "0005-synchronize-debug-client-startup.patch",
        "0008-zero-unmapped-pmp-read.patch",
        "0009-establish-debug-first-use-through-bus.patch",
        "0010-extend-cycle-budgets.patch",
        "0011-bind-debug-server-to-free-port.patch",
    ),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def recorded_patch_hashes(repo: Path) -> dict[str, str]:
    recipe_path = repo / "cpus/vexriscv/TEST_RECIPE.json"
    recipe = json.loads(recipe_path.read_text(encoding="utf-8"))
    result: dict[str, str] = {}
    for record in recipe["patches"]:
        name = Path(record["path"]).name
        if name in result:
            raise ValueError(f"duplicate patch in {recipe_path}: {name}")
        result[name] = record["sha256"]
    expected = {name for names in PROFILE_PATCHES.values() for name in names}
    if set(result) != expected:
        raise ValueError(
            f"patch inventory in {recipe_path} does not match the evaluation profiles"
        )
    return result


def validate_recorded_patches(repo: Path) -> dict[str, str]:
    hashes = recorded_patch_hashes(repo)
    patch_root = repo / "cpus/vexriscv/_shared/test-patches"
    mismatches = [
        name for name, digest in hashes.items()
        if not (patch_root / name).is_file() or sha256(patch_root / name) != digest
    ]
    if mismatches:
        raise ValueError(
            "patch content differs from cpus/vexriscv/TEST_RECIPE.json: "
            + ", ".join(sorted(mismatches))
        )
    return hashes
