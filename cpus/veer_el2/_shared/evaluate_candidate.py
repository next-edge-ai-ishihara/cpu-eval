#!/usr/bin/env python3
"""Replace one module and run the supplied command."""

from __future__ import annotations

import argparse
import fcntl
import re
import subprocess
import sys
from contextlib import nullcontext
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu-root", required=True, type=Path)
    parser.add_argument("--module", required=True)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--lock-held", action="store_true", help="Caller holds the checkout lock and restores the source")
    parser.add_argument("--command", required=True, nargs=argparse.REMAINDER)
    return parser.parse_args()


def replace_module(source: str, module: str, candidate: str) -> str:
    start_match = re.search(rf"(?m)^\s*module\s+{re.escape(module)}\b", source)
    if not start_match:
        raise ValueError(f"module {module} was not found in the recorded source file")
    end_match = re.search(r"(?m)^\s*endmodule\b[^\n]*", source[start_match.start() :])
    if not end_match:
        raise ValueError(f"endmodule for {module} was not found")
    end = start_match.start() + end_match.end()
    return source[: start_match.start()] + candidate.rstrip() + "\n" + source[end:]


def main() -> int:
    args = parse_args()
    if not args.candidate.is_file():
        print(f"CPU_EVAL_INVALID: candidate file not found: {args.candidate}", file=sys.stderr)
        return 2
    if not args.source.is_file():
        print(f"CPU_EVAL_INVALID: recorded source file not found: {args.source}", file=sys.stderr)
        return 2
    if not args.command:
        print("CPU_EVAL_INVALID: missing test command after --command", file=sys.stderr)
        return 2

    lock_path = args.cpu_root / ".cpu_eval.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with (nullcontext() if args.lock_held else lock_path.open("w")) as lock:
        if lock is not None:
            fcntl.flock(lock, fcntl.LOCK_EX)
        original = args.source.read_text(encoding="utf-8")
        candidate = args.candidate.read_text(encoding="utf-8")
        try:
            args.source.write_text(replace_module(original, args.module, candidate), encoding="utf-8")
            completed = subprocess.run(args.command, cwd=args.cpu_root)
            return completed.returncode
        except ValueError as error:
            print(f"CPU_EVAL_INVALID: {error}", file=sys.stderr)
            return 2
        finally:
            if not args.lock_held:
                args.source.write_text(original, encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
