#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 6 ]; then
  echo "usage: run_problem.sh <checkout> <Spike install> <problem> <candidate> <output directory> <program.elf>..." >&2
  exit 2
fi

checkout=$(realpath "$1")
spike=$(realpath "$2")
problem=$3
candidate=$(realpath "$4")
output=$(realpath -m "$5")
shift 5
programs=("$@")

harness=$(cd "$(dirname "$0")" && pwd)
cpu=$(cd "$harness/.." && pwd)
manifest=$cpu/PROBLEMS.tsv
evaluator=$cpu/_shared/evaluate_suite.sh

row=$(awk -F '\t' -v problem="$problem" 'NR > 1 && $1 == problem {print; found++} END {if (found != 1) exit 2}' "$manifest") || {
  echo "problem is not uniquely defined: $problem" >&2
  exit 2
}
IFS=$'\t' read -r _ directory specification test_recipe <<<"$row"
rtl_path=$(sed -n 's/^  file: //p' "$cpu/$directory/problem.yaml")
if [ "$problem" = ibex_cs_registers ]; then
  evaluator=$cpu/cs_registers/evaluate_suite.sh
fi
for path in "$cpu/$specification" "$cpu/$test_recipe" "$candidate"; do
  test -f "$path" || { echo "missing recorded input: $path" >&2; exit 2; }
done

if [ -e "$output" ]; then
  echo "output directory already exists: $output" >&2
  exit 2
fi
mkdir -p "$output/evaluator"

{
  printf 'field\tvalue\n'
  printf 'problem\t%s\n' "$problem"
  printf 'directory\t%s\n' "$directory"
  printf 'rtl_path\t%s\n' "$rtl_path"
  printf 'candidate\t%s\n' "$candidate"
  printf 'candidate_sha256\t%s\n' "$(sha256sum "$candidate" | cut -d' ' -f1)"
  printf 'specification\t%s\n' "$cpu/$specification"
  printf 'specification_sha256\t%s\n' "$(sha256sum "$cpu/$specification" | cut -d' ' -f1)"
  printf 'test_recipe\t%s\n' "$cpu/$test_recipe"
  printf 'test_recipe_sha256\t%s\n' "$(sha256sum "$cpu/$test_recipe" | cut -d' ' -f1)"
  printf 'started_at\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$output/invocation.tsv"
printf '%q ' "$evaluator" "$checkout" "$spike" "$rtl_path" "$candidate" "$output/evaluator" "${programs[@]}" >"$output/command.txt"
printf '\n' >>"$output/command.txt"

set +e
"$evaluator" "$checkout" "$spike" "$rtl_path" "$candidate" "$output/evaluator" "${programs[@]}" \
  >"$output/stdout.log" 2>"$output/stderr.log"
status=$?
set -e
printf '%s\n' "$status" >"$output/exit-code.txt"
printf 'finished_at\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$output/invocation.tsv"

(
  cd "$output"
  find . -type f ! -name files.sha256 -printf '%P\0' | sort -z | \
    xargs -0 -r sha256sum >files.sha256
)
exit "$status"
