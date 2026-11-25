#!/usr/bin/env python3
"""Create a VexRiscv evaluation checkout for the selected patch profile."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from patch_profiles import PROFILE_PATCHES, sha256, validate_recorded_patches


VEXRISCV_REVISION = "c4b2a55b22f46afb760446cd69f3ca7c36eef778"
SPINALHDL_REVISION = "95a5e6c65c54acfc4707c8fe6ef8b5d297cfcbde"
INTEGRATION_PATH = Path("src/main/scala/spinal/lib/Stream.scala")
UPSTREAM_STREAM_PATH = Path("lib/src/main/scala/spinal/lib/Stream.scala")


def run(command: list[str], *, cwd: Path | None = None) -> str:
    return subprocess.check_output(command, cwd=cwd, text=True, stderr=subprocess.STDOUT).strip()


def revision(repository: Path) -> str:
    return run(["git", "-c", f"safe.directory={repository}", "-C", str(repository), "rev-parse", "HEAD"])


def git_blob(repository: Path, revision_name: str, path: Path) -> bytes:
    return subprocess.check_output(
        [
            "git", "-c", f"safe.directory={repository}", "-C", str(repository),
            "show", f"{revision_name}:{path}",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-checkout", required=True, type=Path)
    parser.add_argument("--spinal-source-checkout", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--profile", required=True, choices=sorted(PROFILE_PATCHES))
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = args.source_checkout.resolve()
    spinal = args.spinal_source_checkout.resolve()
    repo = args.repo.resolve()
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    if revision(source) != VEXRISCV_REVISION:
        parser.error(f"VexRiscv source checkout must be at {VEXRISCV_REVISION}")
    if revision(spinal) != SPINALHDL_REVISION:
        parser.error(f"SpinalHDL source checkout must be at {SPINALHDL_REVISION}")

    subprocess.run(["git", "clone", "--no-checkout", str(source), str(output)], check=True)
    run(["git", "checkout", "--detach", VEXRISCV_REVISION], cwd=output)
    patch_root = repo / "cpus/vexriscv/_shared/test-patches"
    patch_hashes = validate_recorded_patches(repo)
    patches = []
    for name in PROFILE_PATCHES[args.profile]:
        patch = patch_root / name
        if sha256(patch) != patch_hashes[name]:
            raise ValueError(f"unexpected patch hash: {name}")
        subprocess.run(["git", "apply", str(patch)], cwd=output, check=True)
        patches.append({"path": str(patch.relative_to(repo)), "sha256": sha256(patch)})

    integrated_source = None
    if args.profile == "spinal":
        integrated = output / INTEGRATION_PATH
        integrated.parent.mkdir(parents=True, exist_ok=True)
        integrated.write_bytes(git_blob(spinal, SPINALHDL_REVISION, UPSTREAM_STREAM_PATH))
        integrated_source = {
            "upstream_path": str(UPSTREAM_STREAM_PATH),
            "integration_path": str(INTEGRATION_PATH),
            "sha256": sha256(integrated),
        }

    manifest = {
        "schema_version": 1,
        "profile": args.profile,
        "vexriscv_revision": revision(output),
        "spinalhdl_revision": revision(spinal),
        "patches": patches,
        "integrated_source": integrated_source,
    }
    (output / ".cpu-eval-profile.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
