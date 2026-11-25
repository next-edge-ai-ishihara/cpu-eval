#!/usr/bin/env python3
"""Extract HDL from an LLM response."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.submission.scala_definition import _non_code_end


FENCE = re.compile(r"```([^\n`]*)\n(.*?)```", re.DOTALL)

FENCE_LANGUAGES = {
    "verilog": {"verilog", "systemverilog", "sv"},
    "scala": {"scala", "chisel", "spinalhdl"},
}


FENCE_LINE = re.compile(r"(?m)^[ \t]*```[ \t]*\r?$")
FENCE_OPEN = re.compile(r"```([^\n`]*)\n")


def _fence_end(raw: str, start: int, fallback: int, language: str) -> int:
    index = start
    while index < len(raw):
        if raw.startswith("```", index):
            following = FENCE_OPEN.match(raw, index)
            if index > fallback and following and following.group(1).strip():
                return fallback
            return index
        char = raw[index]
        if (raw.startswith(("//", "/*"), index) or char in "\"'"
                or (language == "scala" and char == "`")):
            if language == "verilog" and raw.startswith("/*", index):
                closing = raw.find("*/", index + 2)
                end = len(raw) if closing < 0 else closing + 2
            else:
                end = _non_code_end(raw, index)
            if end is not None:
                closing = FENCE_LINE.search(raw, index, end)
                if closing is not None:
                    return raw.index("```", closing.start(), closing.end())
                index = end
                continue
        index += 1
    return fallback


def _fenced_blocks(raw: str, language: str) -> list[tuple[str, str]]:
    blocks = []
    position = 0
    while match := FENCE.search(raw, position):
        label = match.group(1).strip().lower()
        end = match.end(2)
        if not label or label in FENCE_LANGUAGES[language]:
            end = _fence_end(raw, match.start(2), end, language)
        blocks.append((label, raw[match.start(2):end]))
        position = end + 3
    return blocks


def extract_submission(raw: str, language: str) -> tuple[str | None, dict[str, object]]:
    all_blocks = _fenced_blocks(raw, language)
    accepted_labels = FENCE_LANGUAGES[language]
    language_blocks = [body for label, body in all_blocks if label in accepted_labels]
    unlabelled_blocks = [body for label, body in all_blocks if not label]
    blocks = language_blocks or unlabelled_blocks

    if blocks:
        submission = blocks[0]
        method = "first_markdown_code_block"
    else:
        submission = raw
        method = "complete_model_response"

    if not submission.endswith("\n"):
        submission += "\n"
    return submission, {
        "status": "success",
        "code_language": language,
        "code_blocks": len(blocks),
        "all_code_blocks": len(all_blocks),
        "method": method,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--language', choices=('scala', 'systemverilog', 'verilog'), required=True)
    parser.add_argument('--response', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--decision', type=Path, help='Optional JSON extraction decision')
    args = parser.parse_args()
    try:
        paths = [args.output] + ([args.decision] if args.decision else [])
        if len({p.resolve() for p in paths}) != len(paths):
            parser.error('output and decision must be different files')
        for path in paths:
            if path.exists():
                parser.error(f'output already exists: {path}')
            if not path.parent.is_dir():
                parser.error(f'output directory does not exist: {path.parent}')
        family = 'scala' if args.language == 'scala' else 'verilog'
        source, decision = extract_submission(args.response.read_text(encoding='utf-8'), family)
        with args.output.open('x', encoding='utf-8', newline='') as output:
            output.write(source)
        if args.decision:
            with args.decision.open('x', encoding='utf-8', newline='') as output:
                output.write(json.dumps(decision, indent=2) + '\n')
    except (OSError, UnicodeError) as error:
        parser.exit(2, f'error: {error}\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
