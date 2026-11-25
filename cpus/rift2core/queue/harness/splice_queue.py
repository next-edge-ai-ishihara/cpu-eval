#!/usr/bin/env python3
"""Insert a candidate ``chisel3.util.Queue`` class into the Decoupled.scala template.

The template is chipsalliance/chisel 066fb4705472e07bde340810ee45eaf8c1ad9438
src/main/scala/chisel3/util/Decoupled.scala with class Queue replaced by MARKER.

Usage:
    splice_queue.py --template <Decoupled.scala template> \
                    --candidate <candidate Queue class .scala> \
                    --output <spliced Decoupled.scala>
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))
from tools.evaluation.scala_compile_diagnostics import source_region
from tools.submission.scala_definition import definition_span

MARKER = "// Changed from upstream: class Queue is removed and the evaluator inserts the submitted class here.\n"


def extract_class(text: str, label: str) -> str:
    try:
        start, end = definition_span(text, "Queue")
    except ValueError as error:
        print(f"{label}: {error}", file=sys.stderr)
        # Exit 3 marks a submission that declares no usable Queue class; an ambiguous match stays 2.
        ambiguous = "not unique" in str(error) or ("was not found" in str(error) and "`Queue`" in text)
        raise SystemExit(2 if ambiguous else 3) from error
    while start < end and text[start] in "\r\n":
        start += 1
    if not text[start:end].endswith("\n") and text[end:end + 1] == "\n":
        end += 1
    if not text[start:end].endswith("\n"):
        return text[start:end] + "\n"
    return text[start:end]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--region-output", type=Path)
    args = parser.parse_args()

    template = args.template.read_text(encoding="utf-8")
    try:
        candidate = args.candidate.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        print(f"{args.candidate}: {error}", file=sys.stderr)
        return 3

    try:
        definition_span(template, "Queue")
    except ValueError as error:
        if "not found" not in str(error):
            raise SystemExit(f"{args.template}: {error}") from error
    else:
        raise SystemExit(f"{args.template}: template already defines class Queue")
    template_lines = template.splitlines(keepends=True)
    if template_lines.count(MARKER) != 1:
        raise SystemExit(f"{args.template}: expected exactly one insertion marker line")
    line = template_lines.index(MARKER) + 1
    start = sum(len(text) for text in template_lines[:line - 1])

    replacement = extract_class(candidate, str(args.candidate))
    spliced = template[:start] + replacement + template[start + len(MARKER):]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(spliced, encoding="utf-8")
    if args.region_output is not None:
        region = source_region(args.output, spliced, start, start + len(replacement))
        args.region_output.write_text(json.dumps(region) + "\n", encoding="utf-8")
    print(
        f"[splice] template {args.template} ({len(template_lines)} lines): inserted the "
        f"{replacement.count(chr(10))}-line `class Queue` definition from {args.candidate} "
        f"at line {line}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
