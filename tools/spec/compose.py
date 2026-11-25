#!/usr/bin/env python3
"""Compose a CPU-Eval prompt from pinned source excerpts and authored text."""

from __future__ import annotations

import argparse
import functools
import hashlib
import json
import subprocess
import urllib.request
from pathlib import Path


BENCHMARK_ROOT = Path(__file__).resolve().parents[2]

def parse_source_root(value: str) -> tuple[str, Path]:
    repository, separator, path = value.partition("=")
    if not separator or not repository or not path:
        raise argparse.ArgumentTypeError(
            "source roots must use REPOSITORY=PATH"
        )
    return repository, Path(path).resolve()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recipe", required=True, type=Path)
    parser.add_argument(
        "--record-recipe",
        help=(
            "recipe identifier written to SPEC_SOURCES.json; defaults to the "
            "recipe file name"
        ),
    )
    parser.add_argument(
        "--source-root",
        action="append",
        default=[],
        type=parse_source_root,
        metavar="REPOSITORY=PATH",
        help="map a repository identifier in the recipe to a local checkout",
    )
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--record", required=True, type=Path)
    return parser.parse_args()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve_commit(repository: Path, commit: str) -> str:
    resolved = subprocess.check_output(
        [
            "git",
            "-c",
            f"safe.directory={repository}",
            "-C",
            str(repository),
            "rev-parse",
            f"{commit}^{{commit}}",
        ],
        text=True,
    ).strip()
    if resolved != commit:
        raise ValueError(
            f"{repository}: expected full commit object name {commit}, "
            f"found {resolved}"
        )
    return resolved


def source_bytes(
    root: Path,
    commit: str,
    path: str,
    lines: list[int],
    line_byte_start: int | None = None,
    line_byte_end: int | None = None,
) -> bytes:
    resolve_commit(root, commit)
    source = f"{root}@{commit}:{path}"
    data = file_at_revision(root, commit, path)
    return excerpt_bytes(
        data, source, lines, line_byte_start, line_byte_end
    )


def file_at_revision(root: Path, commit: str, path: str) -> bytes:
    result = subprocess.run(
        [
            "git",
            "-c",
            f"safe.directory={root}",
            "-C",
            str(root),
            "show",
            f"{commit}:{path}",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode == 0:
        return result.stdout

    # Files inside a submodule are not in the Git tree; read them from the
    # checkout when it is at the requested revision. The caller checks the hash.
    checkout_revision = subprocess.check_output(
        [
            "git",
            "-c",
            f"safe.directory={root}",
            "-C",
            str(root),
            "rev-parse",
            "HEAD^{commit}",
        ],
        text=True,
    ).strip()
    checked_out = root / path
    if checkout_revision == commit and checked_out.is_file():
        return checked_out.read_bytes()
    raise subprocess.CalledProcessError(
        result.returncode,
        result.args,
        output=result.stdout,
        stderr=result.stderr,
    )


def excerpt_bytes(
    data: bytes,
    source: Path | str,
    lines: list[int],
    line_byte_start: int | None = None,
    line_byte_end: int | None = None,
) -> bytes:
    source_lines = data.splitlines(keepends=True)
    start, end = lines
    if start < 1 or end < start or end > len(source_lines):
        raise ValueError(f"invalid source range {source}:{start}-{end}")
    selected = source_lines[start - 1 : end]
    if line_byte_start is None and line_byte_end is None:
        return b"".join(selected)
    if start != end:
        raise ValueError("line byte bounds require a one-line source range")
    byte_start = line_byte_start if line_byte_start is not None else 0
    byte_end = line_byte_end if line_byte_end is not None else len(selected[0])
    if byte_start < 0 or byte_start >= len(selected[0]):
        raise ValueError(
            f"invalid source byte start {source}:{start}:{byte_start}"
        )
    if byte_end <= byte_start or byte_end > len(selected[0]):
        raise ValueError(
            f"invalid source byte end {source}:{start}:{byte_end}"
        )
    return selected[0][byte_start:byte_end]


@functools.cache
def fetch_archived_webpage(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def archived_webpage(source: dict[str, object]) -> bytes:
    url = str(source["url"])
    revision = str(source["commit"])
    marker = f"/web/{revision}id_/"
    if marker not in url:
        raise ValueError(
            f"archived webpage URL must contain fixed revision {revision}: {url}"
        )
    return fetch_archived_webpage(url)


def archived_pdf_text(source: dict[str, object]) -> bytes:
    pdf = archived_webpage(source)
    extracted = subprocess.run(
        ["pdftotext", "-raw", "-", "-"],
        input=pdf,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout
    expected = str(source["text_sha256"])
    actual = sha256_bytes(extracted)
    if actual != expected:
        raise ValueError(
            f"{source['url']}: expected extracted-text SHA-256 "
            f"{expected}, found {actual}"
        )
    return extracted


def git_commit_message(root: Path, commit: str) -> bytes:
    resolve_commit(root, commit)
    return subprocess.check_output(
        [
            "git",
            "-c",
            f"safe.directory={root}",
            "-C",
            str(root),
            "show",
            "--no-patch",
            "--format=%B",
            commit,
        ]
    )


def main() -> int:
    args = parse_args()
    roots = dict(args.source_root)
    if len(roots) != len(args.source_root):
        raise ValueError("each repository may have only one source root")

    recipe = json.loads(args.recipe.read_text(encoding="utf-8"))
    sources = recipe["sources"]
    repository_records: dict[str, dict[str, str]] = {}
    for source in sources:
        repository = source["repo"]
        source_type = source.get("source_type", "file")
        if source_type in ("file", "git_commit_message"):
            if repository not in roots:
                raise ValueError(f"missing --source-root for {repository}")
            root = roots[repository]
            actual_revision = resolve_commit(root, source["commit"])
        if source_type == "file":
            source_path = f"{root}@{source['commit']}:{source['path']}"
            source_data = file_at_revision(
                root, source["commit"], source["path"]
            )
            actual_hash = sha256_bytes(source_data)
        elif source_type == "git_commit_message":
            if source.get("path") != "COMMIT_MESSAGE":
                raise ValueError(
                    "git commit messages must use path COMMIT_MESSAGE"
                )
            actual_hash = sha256_bytes(
                git_commit_message(root, source["commit"])
            )
            source_path = Path(f"{root}@{source['commit']}:COMMIT_MESSAGE")
        elif source_type == "benchmark_file":
            source_data = (BENCHMARK_ROOT / source["path"]).read_bytes()
            actual_hash = sha256_bytes(source_data)
            source_path = source["path"]
            actual_revision = None
        elif source_type in ("archived_webpage", "archived_pdf"):
            archived = archived_webpage(source)
            actual_hash = sha256_bytes(archived)
            source_path = source["url"]
            actual_revision = source["commit"]
        else:
            raise ValueError(f"unsupported source type: {source_type}")
        if actual_hash != source["sha256"]:
            raise ValueError(
                f"{source_path}: expected SHA-256 {source['sha256']}, "
                f"found {actual_hash}"
            )
        # The first source of each repository sets its recorded base revision.
        if source_type == "benchmark_file":
            continue
        repository_records.setdefault(repository, {
            "revision": actual_revision,
        })

    prompt = bytearray()
    segments = []
    for index, part in enumerate(recipe["parts"]):
        start = len(prompt)
        if part["kind"] == "authored":
            data = part["text"].encode("utf-8")
            segment = {
                "index": index,
                "kind": "authored",
                "description": part["description"],
                "prompt_bytes": [start, start + len(data)],
                "sha256": sha256_bytes(data),
            }
        elif part["kind"] == "verbatim_source":
            source_index = part["source"]
            source = sources[source_index]
            if source.get("source_type", "file") == "git_commit_message":
                message = git_commit_message(
                    roots[source["repo"]], source["commit"]
                )
                message_lines = message.splitlines(keepends=True)
                start_line, end_line = source["lines"]
                if (
                    start_line < 1
                    or end_line < start_line
                    or end_line > len(message_lines)
                ):
                    raise ValueError(
                        f"invalid commit-message range "
                        f"{source['commit']}:{start_line}-{end_line}"
                    )
                data = b"".join(message_lines[start_line - 1 : end_line])
            elif source.get("source_type") == "benchmark_file":
                data = excerpt_bytes(
                    (BENCHMARK_ROOT / source["path"]).read_bytes(),
                    source["path"],
                    source["lines"],
                    source.get("line_byte_start"),
                    source.get("line_byte_end"),
                )
            elif source.get("source_type") == "archived_webpage":
                data = excerpt_bytes(
                    archived_webpage(source),
                    source["url"],
                    source["lines"],
                    source.get("line_byte_start"),
                    source.get("line_byte_end"),
                )
            elif source.get("source_type") == "archived_pdf":
                data = excerpt_bytes(
                    archived_pdf_text(source),
                    source["url"],
                    source["lines"],
                    source.get("line_byte_start"),
                    source.get("line_byte_end"),
                )
            else:
                data = source_bytes(
                    roots[source["repo"]],
                    source["commit"],
                    source["path"],
                    source["lines"],
                    source.get("line_byte_start"),
                    source.get("line_byte_end"),
                )
                line_endings = source.get("line_endings", "source")
                if line_endings == "lf":
                    data = data.replace(b"\r\n", b"\n")
                elif line_endings != "source":
                    raise ValueError(f"unsupported line_endings: {line_endings}")
            segment = {
                "index": index,
                "kind": "verbatim_source",
                "source": source_index,
                "prompt_bytes": [start, start + len(data)],
                "sha256": sha256_bytes(data),
            }
        else:
            raise ValueError(f"unsupported part kind: {part['kind']}")
        if not data:
            raise ValueError(f"part {index} is empty")
        prompt.extend(data)
        segments.append(segment)

    args.spec.parent.mkdir(parents=True, exist_ok=True)
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.spec.write_bytes(prompt)
    record = {
        "schema_version": 1,
        "recipe": args.record_recipe or args.recipe.name,
        "recipe_sha256": sha256_file(args.recipe),
        "prompt_sha256": sha256_bytes(prompt),
        "repositories": repository_records,
        "segments": segments,
        "sources": sources,
    }
    args.record.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
