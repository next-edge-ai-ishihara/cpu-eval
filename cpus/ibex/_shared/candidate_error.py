#!/usr/bin/env python3
"""Decide whether a failed build is the submitted answer's fault.

The fixed tree builds with the reference module, so a build that fails after only
the target file was replaced is the answer's fault unless the target differs from
the submission or the log shows a resource or tool failure.
"""

import argparse
from pathlib import Path
import re


ENVIRONMENT_ERROR = re.compile(
    r'command not found|failed to download|out of memory|cannot allocate memory|'
    r'no space left on device|virtual memory exhausted|input/output error|internal error', re.I)


def candidate_error(log: str, checkout: Path, rtl_path: str, submitted: Path) -> bool:
    return (checkout / rtl_path).read_bytes() == submitted.read_bytes() and not ENVIRONMENT_ERROR.search(log)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('checkout', type=Path)
    parser.add_argument('rtl_path')
    parser.add_argument('submitted', type=Path)
    parser.add_argument('specification', type=Path, nargs='?')
    args = parser.parse_args()
    try:
        identified = candidate_error(args.log.read_text(errors='replace'), args.checkout,
                                     args.rtl_path, args.submitted)
    except OSError:
        return 2
    return 1 if identified else 2


if __name__ == '__main__':
    raise SystemExit(main())
