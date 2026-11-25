#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


class MissingModule(ValueError):
    """The text does not define the requested module."""


def module_span(text: str, module: str) -> tuple[int, int]:
    ignored = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\[\s\S]|[^"\\])*"')
    masked = ignored.sub(lambda match: re.sub(r"[^\n]", " ", match.group()), text)
    start_pattern = re.compile(rf"(?m)^\s*module\s+{re.escape(module)}\b")
    start_match = start_pattern.search(masked)
    if start_match is None:
        raise MissingModule(f"module {module!r} was not found")
    keyword = re.search(r"\bmodule\b", masked[start_match.start():start_match.end()])
    keyword_start = start_match.start() + keyword.start()
    start = start_match.start()
    while not text[start:keyword_start].isspace() and start < keyword_start:
        newline = text.find("\n", start, keyword_start)
        start = newline + 1 if newline >= 0 else keyword_start
    end_match = re.search(r"\bendmodule\b", masked[start_match.end():])
    if end_match is None:
        raise MissingModule(f"endmodule for {module!r} was not found")
    end = start_match.end() + end_match.end()
    label = re.match(r"[ \t]*:[ \t]*[a-zA-Z_][\w$]*", masked[end:])
    if label:
        end += label.end()
    line_end = masked.find("\n", end)
    line_end = len(masked) if line_end < 0 else line_end + 1
    if not masked[end:line_end].strip():
        end = line_end
    return start, end


def module_text(text: str, module: str) -> str:
    start, end = module_span(text, module)
    return text[start:end]


def main() -> int:
    """Exit 1 when the candidate lacks the module and 2 for a fixed-input or I/O failure."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--module", required=True)
    parser.add_argument("--base", type=Path, help="file whose module is replaced; omit to write only the module")
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        candidate = args.candidate.read_text(errors="replace")
        base = None if args.base is None else args.base.read_text()
    except OSError as error:
        print(f"cannot read the inputs: {error}", file=sys.stderr)
        return 2
    try:
        cand_start, cand_end = module_span(candidate, args.module)
    except ValueError as error:
        print(f"candidate: {error}", file=sys.stderr)
        return 1
    replacement = candidate[cand_start:cand_end]
    try:
        if base is None:
            args.output.write_text(replacement)
            return 0
        base_start, base_end = module_span(base, args.module)
        if base[base_end:] and not replacement.endswith("\n"):
            replacement += "\n"
        args.output.write_text(base[:base_start] + replacement + base[base_end:])
    except (OSError, ValueError) as error:
        print(f"cannot integrate the candidate: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
