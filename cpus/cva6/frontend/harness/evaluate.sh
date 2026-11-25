#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-frontend.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

scratch=$(mktemp -d)
trap 'find "$scratch" -depth -delete' EXIT
fixture="$scratch/cpu-eval-patches/cva6_ecall.S"
if ! git -C "$scratch" apply "$cpu_directory/cva6/tests/0007-add-ecall-test.patch" ||
   ! printf '%s  %s\n' 068179cc3ac739d16df4461bead22d085d01a769ed93c9742734fe682dc9abae "$fixture" | sha256sum --check --status ||
   ! mv "$fixture" "$scratch/cva6_ecall.S" ||
   ! cp "$script_directory/testlist_frontend.yaml" "$scratch/testlist_frontend.yaml"; then
  echo "INVALID: cannot reconstruct the pinned CVA6 ECALL test" >&2
  exit 2
fi
export CVA6_TESTLIST="$scratch/testlist_frontend.yaml"
export CVA6_TEST_JOBS=4
"$cpu_directory/harness/evaluate_parallel.sh" frontend "$1"
