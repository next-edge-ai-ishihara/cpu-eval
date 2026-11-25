#!/usr/bin/env python3
"""Construct one VeeR EL2 problem checkout from its fixed recipe."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def problem_directory(repo: Path, problem: str) -> Path:
    for line in (repo / "cpus/veer_el2/PROBLEMS.tsv").read_text(encoding="utf-8").splitlines()[1:]:
        fields = line.split("\t")
        if fields[0] == problem:
            return repo / "cpus/veer_el2" / fields[1]
    raise ValueError(f"unknown VeeR EL2 problem: {problem}")


def generated_source(test: dict[str, object]) -> tuple[str, str]:
    name = str(test.get("name", "riscv_arithmetic_basic_test"))
    digest = test.get("generated_source_before_patch_sha256") or test.get("generated_source_sha256")
    if not digest:
        raise ValueError(f"generated test {name} records no source hash")
    return name, str(digest)


def generated_tests(recipe: dict[str, object]) -> list[dict[str, object]]:
    tests = recipe.get("tests")
    if isinstance(tests, list) and tests:
        return [test for test in tests if isinstance(test, dict) and
                (test.get("generated_source_sha256") or test.get("generated_source_before_patch_sha256"))]
    test = recipe.get("test")
    if isinstance(test, dict) and (test.get("generated_source_sha256") or test.get("generated_source_before_patch_sha256")):
        return [test]
    alignment_test = recipe.get("alignment_decompress_test")
    if isinstance(alignment_test, dict):
        return [alignment_test] if (alignment_test.get("generated_source_sha256") or alignment_test.get("generated_source_before_patch_sha256")) else []
    return []


def patch_working_directory(checkout: Path, description: str) -> Path:
    if description == "third_party/riscv-dv":
        return checkout / description
    if description.startswith("tools/"):
        return checkout / description
    return checkout


def apply_patch(checkout: Path, patch: Path, apply_in: str) -> None:
    with patch.open("rb") as stream:
        subprocess.run(
            ["patch", "--batch", "--forward", "-p1"],
            cwd=patch_working_directory(checkout, apply_in),
            stdin=stream,
            check=True,
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--generated-tests", required=True, type=Path)
    parser.add_argument("--problem", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    repo = args.repo.resolve()
    directory = problem_directory(repo, args.problem)
    recipe = json.loads((directory / "TEST_RECIPE.json").read_text(encoding="utf-8"))
    shutil.copytree(args.source, args.output)

    fixed_tests: dict[str, Path] = {}
    for test in generated_tests(recipe):
        test_name, source_digest = generated_source(test)
        source = args.generated_tests / f"{source_digest}.S"
        if not source.is_file() or sha256(source) != source_digest:
            raise FileNotFoundError(f"fixed generated test is unavailable: {source_digest}")
        test_directory = args.output / "tools/riscv-dv/work" / f"test_{test_name}" / "asm_test"
        test_directory.mkdir(parents=True, exist_ok=True)
        fixed_source = test_directory / f"{test_name}_0.S"
        shutil.copy2(source, fixed_source)
        fixed_tests[test_name] = fixed_source

    patches = [item for item in recipe.get("patches", []) if int(item.get("order", 0)) > 2]
    test = recipe.get("test")
    if isinstance(test, dict):
        post = test.get("post_generation_patch")
        if isinstance(post, dict):
            patches.append(post)
        post_many = test.get("post_generation_patches", [])
        if isinstance(post_many, list):
            patches.extend(post_many)
    for item in patches:
        patch = (directory / str(item["path"])).resolve()
        if sha256(patch) != item["sha256"]:
            raise ValueError(f"test patch hash mismatch: {patch}")
        apply_patch(args.output, patch, str(item["apply_in"]))
    expected_after = None
    if isinstance(test, dict):
        expected_after = test.get("generated_source_after_patch_sha256") or test.get("patched_source_sha256")
    if expected_after:
        test_name, _ = generated_source(test)
        fixed_source = fixed_tests[test_name]
    if expected_after and sha256(fixed_source) != expected_after:
        raise ValueError(
            f"patched generated test hash mismatch: expected {expected_after}, got {sha256(fixed_source)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
