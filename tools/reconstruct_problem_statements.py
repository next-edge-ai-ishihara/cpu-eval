#!/usr/bin/env python3
"""Fetch public prompt sources and verify all fixed CPU-Eval prompts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def clone_url(repository: str) -> str:
    if repository.startswith("github.com/"):
        path = repository.removeprefix("github.com/").split("@", 1)[0]
        return f"https://github.com/{path}.git"
    if repository.startswith("https://github.com/"):
        path = repository.split("@", 1)[0]
        return path if path.endswith(".git") else f"{path}.git"
    raise ValueError(f"no public Git fetch rule for repository: {repository}")


def cache_name(url: str) -> str:
    name = url.removesuffix(".git").rsplit("/", 2)[-2:]
    return "--".join(name) + "--" + hashlib.sha256(url.encode()).hexdigest()[:12]


def recipes(repo: Path) -> list[Path]:
    return sorted(repo.glob("cpus/*/*/SPEC_RECIPE.json"))


def git_sources(recipe: Path) -> list[dict[str, object]]:
    value = json.loads(recipe.read_text(encoding="utf-8"))
    return [
        item
        for item in value["sources"]
        if item.get("source_type", "file") in ("file", "git_commit_message")
    ]


def source_is_in_git_tree(root: Path, commit: str, path: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{commit}:{path}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def checkout_with_submodules(
    mirror: Path, checkout: Path, revision: str
) -> Path:
    if not checkout.exists():
        subprocess.run(
            ["git", "clone", "--no-checkout", str(mirror), str(checkout)],
            check=True,
        )
    subprocess.run(["git", "-C", str(checkout), "checkout", "--detach", revision], check=True)
    subprocess.run(
        ["git", "-C", str(checkout), "submodule", "update", "--init", "--recursive"],
        check=True,
    )
    return checkout


def prepare_repositories(repo: Path, cache: Path) -> dict[str, Path]:
    requested: dict[str, list[tuple[str, str | None]]] = {}
    for recipe in recipes(repo):
        for source in git_sources(recipe):
            requested.setdefault(str(source["repo"]), []).append(
                (str(source["commit"]), str(source["path"]) if source.get("source_type", "file") == "file" else None)
            )

    cache.mkdir(parents=True, exist_ok=True)
    roots: dict[str, Path] = {}
    by_url: dict[str, Path] = {}
    for repository, source_requests in sorted(requested.items()):
        url = clone_url(repository)
        checkout = by_url.get(url)
        if checkout is None:
            checkout = cache / cache_name(url)
            if not checkout.exists():
                subprocess.run(["git", "clone", "--mirror", url, str(checkout)], check=True)
            else:
                subprocess.run(["git", "-C", str(checkout), "remote", "update", "--prune"], check=True)
            by_url[url] = checkout
        for commit in sorted({item[0] for item in source_requests}):
            found = subprocess.run(
                ["git", "-C", str(checkout), "cat-file", "-e", f"{commit}^{{commit}}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            if found.returncode != 0:
                subprocess.run(
                    ["git", "-C", str(checkout), "fetch", "origin", commit], check=True
                )
        missing_from_parent = any(
            path is not None and not source_is_in_git_tree(checkout, commit, path)
            for commit, path in source_requests
        )
        if missing_from_parent:
            base_revision = source_requests[0][0]
            checkout = checkout_with_submodules(
                checkout,
                cache / f"{cache_name(url)}--checkout",
                base_revision,
            )
        roots[repository] = checkout
    return roots


def reconstruct_one(
    repo: Path, recipe: Path, roots: dict[str, Path], output: Path
) -> None:
    problem = recipe.parent.relative_to(repo / "cpus")
    destination = output / problem
    command = [
        sys.executable,
        str(repo / "tools/spec/compose.py"),
        "--recipe",
        str(recipe),
        "--spec",
        str(destination / "SPEC.md"),
        "--record",
        str(destination / "SPEC_SOURCES.json"),
    ]
    fixed_record = json.loads(
        (recipe.parent / "SPEC_SOURCES.json").read_text(encoding="utf-8")
    )
    command.extend(["--record-recipe", str(fixed_record["recipe"])])
    for repository in sorted({str(item["repo"]) for item in git_sources(recipe)}):
        command.extend(["--source-root", f"{repository}={roots[repository]}"])
    subprocess.run(command, check=True)
    for name in ("SPEC.md", "SPEC_SOURCES.json"):
        expected = recipe.parent / name
        observed = destination / name
        expected_data = expected.read_bytes()
        observed_data = observed.read_bytes()
        if name == "SPEC_SOURCES.json":
            expected_data = json.dumps(json.loads(expected_data), sort_keys=True).encode()
            observed_data = json.dumps(json.loads(observed_data), sort_keys=True).encode()
        if observed_data != expected_data:
            raise ValueError(f"reconstructed file differs: {expected}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    roots = prepare_repositories(repo, args.cache.resolve())
    if args.output:
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=True)
        for recipe in recipes(repo):
            reconstruct_one(repo, recipe, roots, output)
    else:
        with tempfile.TemporaryDirectory(prefix="cpu-eval-prompts-") as temporary:
            output = Path(temporary)
            for recipe in recipes(repo):
                reconstruct_one(repo, recipe, roots, output)
    print(f"verified {len(recipes(repo))} prompts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
