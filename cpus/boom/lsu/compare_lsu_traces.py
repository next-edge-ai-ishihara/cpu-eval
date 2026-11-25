#!/usr/bin/env python3

from __future__ import annotations
import importlib.util
from pathlib import Path

helper = Path(__file__).resolve().parent.parent / "_shared" / "compare_instruction_traces.py"
spec = importlib.util.spec_from_file_location("boom_lsu_shared_comparison", helper)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Cannot load shared trace comparison: {helper}")
comparison = importlib.util.module_from_spec(spec)
spec.loader.exec_module(comparison)
shared_records = comparison.records

def records(path: Path) -> list[tuple[str, ...]]:
    return [record[:5] for record in shared_records(path)]

comparison.records = records
if __name__ == "__main__":
    raise SystemExit(comparison.main())
