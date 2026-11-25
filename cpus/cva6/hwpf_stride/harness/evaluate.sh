#!/usr/bin/env bash
set -uo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-hwpf_stride.sv>" >&2
  exit 2
fi

lock_repo=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}
if [ -n "${CVA6_EVALUATION_LOCK_FD:-}" ]; then
  if [ "$CVA6_EVALUATION_LOCK_FD" != 9 ] || \
     [ ! "/proc/self/fd/9" -ef "$lock_repo.cpu-eval.lock" ]; then
    echo "INVALID: inherited evaluation lock does not match $lock_repo" >&2
    exit 2
  fi
else
  exec 9>"$lock_repo.cpu-eval.lock" || { echo "INVALID: cannot open the evaluation lock" >&2; exit 2; }
fi
flock -n 9 || { echo "INVALID: another evaluation owns $lock_repo" >&2; exit 2; }
export CVA6_EVALUATION_LOCK_FD=9

script_directory=$(cd "$(dirname "$0")" && pwd)
problem_directory=$(cd "$script_directory/.." && pwd)
cpu_directory=$(cd "$script_directory/../.." && pwd)

candidate=$(realpath "$1")
set +e
python3 "$script_directory/evaluate_ports.py" "$candidate" --module hwpf_stride
ports_rc=$?
set -e
if [ "$ports_rc" -ne 0 ]; then
  exit "$ports_rc"
fi
integration_patch="$problem_directory/test-patches/enable_hwpf_stride.patch"
submodule_patch="$problem_directory/test-patches/fix_stride_snoop_line.patch"
request_tag_patch="$problem_directory/test-patches/forward_stride_request_tag.patch"
integration_target="$CVA6_REPO/core/cva6.sv"
integration_reference_sha=a06f296f9cfd551ec50fbdfbf3c3ddc5d1e14461dd705692bcc5e2c85b147c2c

if [ "$(sha256sum "$integration_target" | cut -d' ' -f1)" != "$integration_reference_sha" ]; then
  echo "core/cva6.sv is not the recorded reference before prefetcher activation" >&2
  exit 2
fi
applied_patch_repos=()
applied_patch_files=()
restore_integration() {
  status=$?
  trap - EXIT INT TERM
  failed=0
  for ((index=${#applied_patch_files[@]}-1; index>=0; index--)); do
    if ! git -C "${applied_patch_repos[index]}" apply --reverse "${applied_patch_files[index]}"; then
      echo "INVALID: cannot restore ${applied_patch_files[index]}" >&2
      failed=1
    fi
  done
  if [ "$failed" -ne 0 ]; then
    exit 2
  fi
  exit "$status"
}
trap restore_integration EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git -C "$CVA6_REPO" apply --check "$integration_patch" || exit 2
git -C "$CVA6_REPO" apply "$integration_patch" || exit 2
applied_patch_repos+=("$CVA6_REPO")
applied_patch_files+=("$integration_patch")
git -C "$CVA6_REPO/core/cache_subsystem/hpdcache" apply --check "$submodule_patch" || exit 2
git -C "$CVA6_REPO/core/cache_subsystem/hpdcache" apply "$submodule_patch" || exit 2
applied_patch_repos+=("$CVA6_REPO/core/cache_subsystem/hpdcache")
applied_patch_files+=("$submodule_patch")
git -C "$CVA6_REPO/core/cache_subsystem/hpdcache" apply --check "$request_tag_patch" || exit 2
git -C "$CVA6_REPO/core/cache_subsystem/hpdcache" apply "$request_tag_patch" || exit 2
applied_patch_repos+=("$CVA6_REPO/core/cache_subsystem/hpdcache")
applied_patch_files+=("$request_tag_patch")

# The ordinary build key does not include test-only integration patches.
# Invalidate it so an inactive prefetcher binary cannot be reused.
rm -f "$CVA6_REPO/work-ver/.cpu-eval-build-key"

export CVA6_TARGET=cv32a60x
export CVA6_TESTLIST="$script_directory/testlist_hwpf_stride.yaml"
export CVA6_TEST_JOBS=1
export CPU_EVAL_LOG_ROOT="${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}"
base_log_root=$CPU_EVAL_LOG_ROOT
mkdir -p "$base_log_root" || { echo "INVALID: cannot create the log root" >&2; exit 2; }
invocation_log_root=$(mktemp -d "$base_log_root/hwpf_stride-invocation-XXXXXX") || {
  echo "INVALID: cannot create an invocation log root" >&2
  exit 2
}
export CPU_EVAL_LOG_ROOT="$invocation_log_root"
set +e
"$cpu_directory/harness/evaluate_parallel.sh" hwpf_stride "$candidate" \
  >"$invocation_log_root/directed-runner.log" 2>&1
shared_rc=$?
cat "$invocation_log_root/directed-runner.log"
set -e

case "$shared_rc" in
  0|1) ;;
  *) echo "INVALID: shared evaluator exited with $shared_rc" >&2; exit 2 ;;
esac

candidate_sha=$(sha256sum "$candidate" | cut -d' ' -f1)
shopt -s nullglob
run_directories=("$invocation_log_root/hwpf_stride/"*"-${candidate_sha:0:12}")
if [ "${#run_directories[@]}" -ne 1 ] || [ ! -d "${run_directories[0]}" ]; then
  echo "INVALID: one shared evaluator run was not recorded" >&2
  exit 2
fi
run_directory=${run_directories[0]}
if [ "$shared_rc" -eq 1 ] && [ -f "$run_directory/candidate-compile-error.txt" ]; then
  echo "FAIL_CANDIDATE_COMPILE: shared compiler error identifies the submitted source"
  exit 1
fi
if [ "$shared_rc" -eq 1 ] && [ -d "$run_directory/cycle-limit-evidence" ] && \
   find "$run_directory/cycle-limit-evidence" -name binding.json -print -quit | grep -q .; then
  echo "FAIL: CPU reached the fixed RVFI cycle limit"
  exit 1
fi
if [ "$shared_rc" -eq 1 ] && [ -s "$run_directory/incomplete-execution.txt" ]; then
  echo "FAIL: $(cat "$run_directory/incomplete-execution.txt")"
  exit 1
fi
if [ ! -f "$run_directory/iss_regr.log" ]; then
  echo "INVALID: directed-test evidence is missing" >&2
  exit 2
fi

set +e
python3 "$problem_directory/../hwpf_stride_arb/harness/compare_directed_traces.py" "$run_directory" \
  --output "$run_directory/directed-semantic-comparison.json" \
  --shared-return-code "$shared_rc" --runner-log "$invocation_log_root/directed-runner.log"
semantic_rc=$?
set -e
case "$semantic_rc" in
  0|1) ;;
  *) echo "INVALID: full directed semantic comparison did not complete" >&2; exit 2 ;;
esac

export CPU_EVAL_LOG_ROOT="$base_log_root"
export CVA6_TESTLIST="$cpu_directory/harness/testlist_cv32a60x.yaml"
export CVA6_TEST_JOBS=4
set +e
"$cpu_directory/harness/evaluate_parallel.sh" hwpf_stride "$candidate"
standard_rc=$?
set -e
# A definite mismatch outranks a check that could not finish.
if [ "$semantic_rc" -ne 0 ] || [ "$standard_rc" -eq 1 ]; then
  exit 1
fi
if [ "$standard_rc" -ne 0 ]; then
  exit 2
fi
exit 0
