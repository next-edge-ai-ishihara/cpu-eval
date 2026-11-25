#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hpdcache_amo.sv>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$problem_directory/.." && pwd)

repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
rvfi_source="$repo/core/cva6_rvfi.sv"
build_key="$repo/work-ver/.cpu-eval-build-key"
original_sha=bf2455879fbf2f9e947fd1bbf37538c9de46592ff9c9d889e29f87803676de21
corrected_sha=18f6034a7d82d3be20fdf9435d4436849e77208ac4c8109d2f6456b3734cb6c9
exec 9>"$repo.cpu-eval.lock"
flock -n 9 || { echo "INVALID: another evaluation owns $repo" >&2; exit 2; }
printf '%s  %s\n' "$original_sha" "$rvfi_source" | sha256sum --check --status || {
  echo "INVALID: CVA6 RVFI source does not match its pinned input" >&2
  exit 2
}
backup=$(mktemp "$rvfi_source.cpu-eval-XXXXXX") || exit 2
cp -p "$rvfi_source" "$backup" || { rm -f "$backup"; exit 2; }
restore_rvfi() {
  local status=$?
  if ! mv -f "$backup" "$rvfi_source" || ! rm -f "$build_key"; then
    echo "INVALID: could not restore CVA6 RVFI source or invalidate the instrumented build" >&2
    exit 2
  fi
  exit "$status"
}
trap restore_rvfi EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# CVA6 routes LR through the store unit. Clear only its RVFI write mask because LR reads memory.
sed "/rvfi_instr_o\[i\]\.mem_wmask <= /s/<= /<= (commit_instr_op[i] inside {AMO_LRW, AMO_LRD}) ? '0 : /" \
  "$backup" > "$rvfi_source" || exit 2
printf '%s  %s\n' "$corrected_sha" "$rvfi_source" | sha256sum --check --status || {
  echo "INVALID: corrected CVA6 RVFI source does not match its recorded SHA-256" >&2
  exit 2
}
rm -f "$build_key" || exit 2

export CVA6_EVALUATION_LOCK_FD=9
export CVA6_TARGET=cv64a6_imafdc_sv39_hpdcache_wb
export CVA6_TESTLIST="$script_directory/testlist_amo.yaml"
export CVA6_TEST_JOBS=1
"$cpu_directory/harness/evaluate_parallel.sh" hpdcache_amo "$1"
