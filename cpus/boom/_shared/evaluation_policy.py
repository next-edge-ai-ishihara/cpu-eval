#!/usr/bin/env python3
"""Materialize the recorded BOOM test list and verdict policy for one problem."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


REGISTER_TESTS = {
    "bim_branch_predictor_bank": [("rv64mi-p-bim_cycle_probe", "x22", 0x5000)],
    "branch_decode": [
        ("rv64mi-p-branch_decode_cycles", "x20", 0x3CF),
        ("rv64mi-p-branch_decode_calls", "x20", 0x327),
        ("rv64mi-p-branch_decode_jalr_calls", "x20", 4413),
        ("rv64mi-p-branch_decode_x5_returns", "x20", 4640),
    ],
    "int_xbar": [("rv64mi-p-timer_pending", "x20", 1)],
    "loop_branch_predictor_bank": [("rv64mi-p-loop_exit_cycles", "x20", 26128)],
    "loop_branch_predictor_column": [("rv64mi-p-loop_exit_cycles", "x20", 26128)],
    "max_period_fibonacci_lfsr": [("rv64mi-p-cache_replacement_cycles", "x20", 0x86A)],
    "null_local_branch_predictor_bank": [("rv64mi-p-null_local_history_cycles", "x20", 0x8E6)],
    "null_prefetcher": [("rv64mi-p-data_prefetch_cycles", "x20", 0x3456)],
    "queue": [("rv64mi-p-loop_branch_cycles", "x20", 0x3CF)],
    "tl_xbar": [("rv64mi-p-data_prefetch_cycles", "x20", 0x3456)],
}

# Register tests that pass when the committed value is below the recorded bound.
MAXIMUM_REGISTER_TESTS = {
    ("bim_branch_predictor_bank", "rv64mi-p-bim_cycle_probe"),
    ("loop_branch_predictor_bank", "rv64mi-p-loop_exit_cycles"),
    ("loop_branch_predictor_column", "rv64mi-p-loop_exit_cycles"),
}

DIRECTED_PROGRAM_PROBLEMS = {
    "hella_cache_arbiter",
    "nbdtlb",
    "pmp_checker",
    "ptw",
    "tlb",
}

DIRECTED_PROGRAM_TESTS = {
    ("mem_addr_calc_unit", "rv64si-p-dirty"),
}


# Subset of each TESTS.txt that this driver runs; entries outside it are not run here.
CPU_SUITE_TESTS = {
    "l1_metadata_array": {"rv64ui-p-add", "rv64ui-p-sub", "rv64ui-p-lw", "rv64ui-p-sw"},
    "issue_unit_collapsing": {"rv64ui-p-add", "rv64ui-p-sub", "rv64ui-p-lw", "rv64ui-p-sw"},
    "fetch_target_queue": {"rv64ui-p-jal", "rv64ui-p-jalr", "rv64ui-p-beq", "rv64ui-p-bne"},
    "tl_xbar": {"rv64mi-p-data_prefetch_cycles"},
}


def read_tests(path: Path) -> list[str]:
    return [
        line.split("#", 1)[0].strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.split("#", 1)[0].strip()
    ]


def evaluation_row(cpu_dir: Path, problem: str) -> dict[str, str]:
    with (cpu_dir / "_shared/TEST_METHODS.tsv").open(encoding="utf-8", newline="") as stream:
        rows = [row for row in csv.DictReader(stream, delimiter="\t") if row["problem"] == problem]
    if len(rows) != 1:
        raise ValueError(f"expected one BOOM evaluation row for {problem}, found {len(rows)}")
    return rows[0]


def external_test(cpu_dir: Path, problem: str) -> tuple[Path, str]:
    recipe = json.loads((cpu_dir / problem / "TEST_RECIPE.json").read_text(encoding="utf-8"))
    source = (
        recipe["test_source"].get("path")
        or recipe["test_source"].get("directed_test")
        or recipe["test_source"].get("test")
    )
    if not source:
        raise ValueError(f"missing directed test source for {problem}")
    path = cpu_dir / problem / source
    return path, f"boom.tests.{path.stem}"


def write_policy(cpu_dir: Path, problem: str, output: Path) -> tuple[Path, Path]:
    row = evaluation_row(cpu_dir, problem)
    method = row["method"]
    if method == "directed_module_external":
        raise ValueError(f"{problem} uses a directed module test, not a CPU test policy")
    tests_path = cpu_dir / problem / "TESTS.txt"
    if tests_path.is_file():
        tests = read_tests(tests_path)
    else:
        recipe = json.loads((cpu_dir / problem / "TEST_RECIPE.json").read_text(encoding="utf-8"))
        tests = recipe.get("tests")
        if not isinstance(tests, list) or not tests or any(
            not isinstance(test, str) or not test.strip() for test in tests
        ):
            raise ValueError(f"{problem} has no valid recorded CPU test list")
    if problem in CPU_SUITE_TESTS:
        selected = CPU_SUITE_TESTS[problem]
        missing = selected.difference(tests)
        if missing:
            raise ValueError(f"recorded CPU-suite tests are absent for {problem}: {sorted(missing)}")
        tests = [test for test in tests if test in selected]
    directed = REGISTER_TESTS.get(problem, [])
    directed_by_test = {test: (register, expected) for test, register, expected in directed}
    policy = []
    for test in tests:
        if (
            method == "complete_cpu_self_check"
            or problem in DIRECTED_PROGRAM_PROBLEMS
            or (problem, test) in DIRECTED_PROGRAM_TESTS
        ):
            policy.append((test, "directed_program", "", ""))
        elif test in directed_by_test:
            mode = "directed_register_max" if (problem, test) in MAXIMUM_REGISTER_TESTS else "directed_register"
            policy.append((test, mode, *directed_by_test[test]))
        else:
            policy.append((test, "trace", "", ""))
    output.mkdir(parents=True, exist_ok=True)
    tests_path = output / "tests.txt"
    policy_path = output / "policy.tsv"
    tests_path.write_text("\n".join(tests) + "\n", encoding="utf-8")
    with policy_path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(("test", "mode", "register", "expected"))
        writer.writerows(policy)
    return tests_path, policy_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu-dir", required=True, type=Path)
    parser.add_argument("--problem", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    write_policy(args.cpu_dir.resolve(), args.problem, args.output.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
