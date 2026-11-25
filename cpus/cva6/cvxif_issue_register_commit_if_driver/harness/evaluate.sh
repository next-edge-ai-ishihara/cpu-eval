#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: evaluate.sh <candidate-systemverilog>" >&2
  exit 2
fi
set +e
CVA6_TESTLIST="$SCRIPT_DIR/testlist_commit_notifications.yaml" \
CPU_EVAL_MODULE=cvxif_issue_register_commit_if_driver \
  "$SCRIPT_DIR/../../copro_alu/harness/evaluate.sh" "$1"
result=$?
set -e
reference=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}/core/cvxif_issue_register_commit_if_driver.sv
if [ ! -f "$reference" ] || \
    [ "$(sha256sum "$reference" | cut -d' ' -f1)" != 79577da9e81421b986255b84f5249979c5b1f3218d83ed761b564dd5821ad553 ]; then
  echo "INVALID: fixed reference source was not restored" >&2
  exit 2
fi
testharness=${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}/corev_apu/tb/ariane_testharness.sv
if ! cmp -s "$testharness" <(git -C "${CVA6_REPO:?Set CVA6_REPO to the writable CPU checkout}" show 6348e9e684678f83b40d0520028513d06b36e7b2:corev_apu/tb/ariane_testharness.sv); then
  echo "INVALID: fixed simulation harness was not restored" >&2
  exit 2
fi
if [ "$result" -ne 0 ]; then
  exit "$result"
fi
candidate_sha=$(sha256sum "$1" | cut -c1-12)
logs=${CPU_EVAL_LOG_ROOT:?Set CPU_EVAL_LOG_ROOT to the results directory outside the distribution}/cvxif_issue_register_commit_if_driver
latest=$(find "$logs" -mindepth 1 -maxdepth 1 -type d -name "*-$candidate_sha" | sort | tail -1)
if [ -z "$latest" ]; then
  echo "INVALID: CPU observation output is missing" >&2
  exit 2
fi
for rtl_log in "$latest"/cpu-port-observations/*.log; do
  set +e
  python3 "$SCRIPT_DIR/observe_cpu_notifications.py" "$rtl_log" "$rtl_log.notifications.json"
  observer_result=$?
  set -e
  printf '%s\n' "$observer_result" > "$latest/notification-exit-code.txt"
  if [ "$observer_result" -ne 0 ]; then
    exit "$observer_result"
  fi
done
exit "$result"
