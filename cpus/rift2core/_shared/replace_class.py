#!/usr/bin/env python3


from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.submission.scala_definition import (
    CandidateDefinitionError, _code_mask, definition_span, integrate_submission,
)
from tools.evaluation.scala_compile_diagnostics import integrated_region


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--class-name", required=True)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--region-output", type=Path)
    parser.add_argument("--hide", action="append", default=[])
    parser.add_argument("--hide-root", type=Path)
    args = parser.parse_args()

    try:
        candidate = args.candidate.read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        print(f"{args.candidate}: {error}", file=sys.stderr)
        return 3
    if args.hide:
        # Fixed definitions that implement the answer get a name the submission cannot know.
        suffix = "_" + hashlib.sha256(candidate.encode()).hexdigest()[:16]
        pattern = re.compile(r"\b(" + "|".join(map(re.escape, args.hide)) + r")\b")
        found = set()
        for path in sorted(args.hide_root.rglob("*.scala")):
            text = path.read_bytes().decode("utf-8")
            hidden = pattern.sub(lambda match: (found.add(match[1]), match[1] + suffix)[1], text)
            if hidden != text:
                path.write_bytes(hidden.encode("utf-8"))
        if found != set(args.hide):
            print(f"hidden definitions not found: {sorted(set(args.hide) - found)}", file=sys.stderr)
            return 2
    source = args.source.read_text(encoding="utf-8")
    definition_span(source, args.class_name, allow_braceless=True)
    try:
        fixed = integrate_submission(source, candidate, args.class_name)
    except CandidateDefinitionError as error:
        print(f"{args.candidate}: {error}", file=sys.stderr)
        return 3
    except ValueError as error:
        # The fixed class was found, so a submission without a declaration of it is the answer's fault.
        if str(error).startswith("requested class was not found") and f"`{args.class_name}`" not in candidate:
            print(f"{args.candidate}: {error}", file=sys.stderr)
            return 3
        raise
    args.output.write_text(fixed, encoding="utf-8")
    if args.region_output is not None:
        integrated = args.output.read_text(encoding="utf-8")
        region = integrated_region(args.output, source, integrated, args.class_name)
        empty_body = False
        try:
            first, last = definition_span(candidate, args.class_name, allow_braceless=True)
            masked = _code_mask(candidate[first:last])
            brace = masked.find("{")
            empty_body = brace < 0 or not masked[brace + 1:masked.rfind("}")].strip()
        except ValueError:
            pass
        region.update(class_name=args.class_name, empty_body=empty_body)
        args.region_output.write_text(json.dumps(region, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
