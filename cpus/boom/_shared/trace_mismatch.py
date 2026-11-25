#!/usr/bin/env python3
"""Exit 0 when a trace comparison report records a compared-value mismatch."""

import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as stream:
        mismatch = json.load(stream).get("first_mismatch_index")
except (OSError, ValueError, AttributeError):
    mismatch = None
sys.exit(0 if mismatch is not None else 1)
