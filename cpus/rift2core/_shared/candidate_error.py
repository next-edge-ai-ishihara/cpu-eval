#!/usr/bin/env python3
"""Decide whether a failed Rift2Core build step is the submitted answer's fault.

The fixed tree builds and runs with the reference class, so a step that fails after only
the target class was replaced is the answer's fault unless the replaced source no longer
holds the submitted class or the log shows a resource or tool failure.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.submission.scala_definition import definition_span


ENVIRONMENT_ERROR = re.compile(
    r'command not found|failed to download|error downloading|resolution failed|unresolved dependenc|'
    r'out ?of ?memory|cannot allocate memory|std::bad_alloc|virtual memory exhausted|'
    r'no space left on device|input/output error|read-only file system|permission denied|'
    r'too many open files|killed signal terminated program|internal error|exec format error|'
    r'^(?:env|bash|sh|timeout|[\w/.-]*/bash)(?:: line \d+)?: .*no such file or directory', re.I | re.M)


def candidate_error(log: str, region: dict, candidate: str, class_name: str) -> bool:
    source = Path(str(region['source'])).read_bytes()
    if hashlib.sha256(source).hexdigest() != region['source_sha256']:
        return False
    try:
        start, end = definition_span(candidate, class_name, allow_braceless=True)
    except ValueError:
        # An unbalanced class has no span; replace_class.py inserts it up to the end of the answer.
        header = re.search(r'\bclass\s+' + re.escape(class_name) + r'\b', candidate)
        if header is None:
            return False
        start, end = header.start(), len(candidate)
    return candidate[start:end].strip() in source.decode('utf-8') and not ENVIRONMENT_ERROR.search(log)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('region', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('class_name')
    args = parser.parse_args()
    try:
        identified = candidate_error(args.log.read_text(errors='replace'),
                                     json.loads(args.region.read_text()),
                                     args.candidate.read_text(encoding='utf-8'), args.class_name)
    except (OSError, KeyError, TypeError, UnicodeError, ValueError):
        return 2
    return 1 if identified else 2


if __name__ == '__main__':
    raise SystemExit(main())
