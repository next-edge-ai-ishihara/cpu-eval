#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.submission.scala_definition import integrate_submission
from tools.submission.scala_definition import definition_span
from tools.evaluation.scala_compile_diagnostics import integrated_region


PREFIXES = {
    "boom": Path("generators/boom"),
    "rocket-chip": Path("generators/rocket-chip"),
    "berkeley-hardfloat": Path("generators/rocket-chip/hardfloat"),
    "chisel3": Path("."),
}


def parse_repository_roots(values: list[str]) -> dict[str, Path]:
    roots = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"expected SOURCE_REPOSITORY=PATH: {value}")
        repository, path = value.split("=", 1)
        roots[repository] = Path(path).resolve()
    return roots


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def definition_end(text: str, start: int) -> int:
    depth = 0
    paren_depth = 0
    bracket_depth = 0
    opened = False
    index = start
    state = "code"
    while index < len(text):
        char = text[index]
        nxt = text[index + 1] if index + 1 < len(text) else ""
        if state == "line_comment":
            if char == "\n":
                state = "code"
        elif state == "block_comment":
            if char == "*" and nxt == "/":
                state = "code"
                index += 1
        elif state == "string":
            if char == "\\":
                index += 1
            elif char == '"':
                state = "code"
        elif state == "char":
            if char == "\\":
                index += 1
            elif char == "'":
                state = "code"
        elif char == "/" and nxt == "/":
            state = "line_comment"
            index += 1
        elif char == "/" and nxt == "*":
            state = "block_comment"
            index += 1
        elif char == '"':
            state = "string"
        elif char == "'":
            state = "char"
        elif char == "{":
            depth += 1
            opened = True
        elif char == "}" and opened:
            depth -= 1
            if depth == 0:
                return index + 1
        elif not opened and char == "(":
            paren_depth += 1
        elif not opened and char == ")":
            paren_depth -= 1
        elif not opened and char == "[":
            bracket_depth += 1
        elif not opened and char == "]":
            bracket_depth -= 1
        elif (
            not opened
            and char == "\n"
            and nxt == "\n"
            and paren_depth == 0
            and bracket_depth == 0
        ):
            return index
        index += 1
    raise ValueError("matching outer brace was not found")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--chisel-source-root", type=Path)
    parser.add_argument("--repository-root", action="append", default=[])
    parser.add_argument("--unit", required=True)
    parser.add_argument("--extract", type=Path)
    parser.add_argument("--replace", type=Path)
    parser.add_argument("--region-output", type=Path)
    args = parser.parse_args()
    if (args.extract is None) == (args.replace is None):
        parser.error("specify exactly one of --extract or --replace")

    rows = list(csv.DictReader(args.inventory.open(), delimiter="\t"))
    matches = [row for row in rows if row["source_unit"] == args.unit]
    if len(matches) != 1:
        raise ValueError(f"expected one inventory row for {args.unit}, found {len(matches)}")
    row = matches[0]
    repository_roots = parse_repository_roots(args.repository_root)
    repository = row["source_repository"]
    if repository in repository_roots:
        relative = Path(row["definition_path"]).relative_to(PREFIXES[repository])
        path = repository_roots[repository] / relative
    elif repository == "chisel3":
        if args.chisel_source_root is None:
            raise ValueError("--chisel-source-root is required for a Chisel source unit")
        path = args.chisel_source_root / row["definition_path"]
    else:
        path = args.source_root / row["definition_path"]
    if digest(path) != row["source_file_sha256"]:
        raise ValueError(f"source hash mismatch: {path}")
    text = path.read_text()
    line = int(row["definition_line"])
    start = sum(len(item) for item in text.splitlines(keepends=True)[: line - 1])
    end = definition_end(text, start)
    block = text[start:end]

    if args.extract is not None:
        args.extract.parent.mkdir(parents=True, exist_ok=True)
        args.extract.write_text(block + ("" if block.endswith("\n") else "\n"))
    else:
        annotation = "@chiselName\n"
        annotated_unit = text[:start].endswith(annotation)
        if annotated_unit:
            # Include the annotation in the replacement span so submitted imports can precede it.
            start -= len(annotation)
            text = text[:start] + text[start + len(annotation):]
            start, _ = definition_span(text, args.unit, allow_braceless=True)
        try:
            fixed = integrate_submission(text, args.replace.read_text(), args.unit)
        except ValueError as error:
            # The fixed source integrates with the reference, so a rejected class is the submission's.
            print(f"CANDIDATE_DEFINITION_ERROR: {error}", file=sys.stderr)
            return 3
        if annotated_unit:
            declaration, _ = definition_span(fixed, args.unit, allow_braceless=True)
            declaration += len(fixed[declaration:]) - len(fixed[declaration:].lstrip())
            if not any(line.strip() == annotation.strip() for line in fixed[start:declaration].splitlines()):
                fixed = fixed[:declaration] + annotation + fixed[declaration:]
        path.write_text(fixed)
        if args.region_output:
            region = integrated_region(path, text, fixed, args.unit)
            region["candidate_sha256"] = digest(args.replace)
            region["class_name"] = args.unit
            roots = {args.source_root, *repository_roots.values()}
            if args.chisel_source_root:
                roots.add(args.chisel_source_root)
            same_name = {match.resolve() for root in roots for match in root.rglob(path.name)
                         if match.is_file()}
            region["source_basename_unique"] = same_name == {path.resolve()}
            args.region_output.write_text(json.dumps(region, indent=2) + "\n")
    print(f"{args.unit}\t{path}\t{line}\t{end}\t{hashlib.sha256(block.encode()).hexdigest()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
