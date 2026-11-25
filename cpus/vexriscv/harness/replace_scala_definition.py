#!/usr/bin/env python3
"""Replace one complete Scala class definition without touching siblings."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.submission.scala_definition import definition_span, integrate_submission


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--extract", action="store_true")
    parser.add_argument("--class-name", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    base = args.base.read_text(encoding="utf-8")
    if args.extract:
        if args.candidate is not None:
            parser.error("--candidate cannot be used with --extract")
        start, end = definition_span(base, args.class_name)
        args.output.write_text(base[start:end], encoding="utf-8")
        return 0
    if args.candidate is None:
        parser.error("--candidate is required unless --extract is used")
    definition_span(base, args.class_name, allow_braceless=True)
    try:
        # Undecodable or unparsable submitted text is the answer's; the fixed base was parsed above.
        candidate = args.candidate.read_text(encoding="utf-8")
        fixed = integrate_submission(base, candidate, args.class_name)
    except ValueError as error:
        print(f"candidate definition: {error}", file=sys.stderr)
        return 3
    args.output.write_text(fixed, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
