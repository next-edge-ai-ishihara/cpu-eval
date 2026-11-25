#!/usr/bin/env python3
"""Split the selected CVA6 test-list entries into shards."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import yaml


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--jobs", type=int, required=True)
    parser.add_argument("--selection", type=Path, required=True)
    args = parser.parse_args()
    if args.jobs < 1:
        raise SystemExit("--jobs must be positive")

    selected = json.loads(args.selection.read_text())["entries"]
    header = "testlist:\n"
    entries = [yaml.safe_dump([entry], sort_keys=False) for entry in selected]
    entries = ["".join("  " + line for line in entry.splitlines(keepends=True)) for entry in entries]
    jobs = min(args.jobs, len(entries))
    args.output_directory.mkdir(parents=True, exist_ok=True)
    for shard in range(jobs):
        selected = entries[shard::jobs]
        (args.output_directory / f"shard-{shard:02d}.yaml").write_text(
            header + "".join(selected)
        )
    print(f"entries={len(entries)} shards={jobs}")


if __name__ == "__main__":
    main()
