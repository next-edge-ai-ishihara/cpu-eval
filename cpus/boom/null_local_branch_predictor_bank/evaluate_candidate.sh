#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$5"
set +e
bash "$script_dir/evaluate_ports.sh" "$1" "$2" "$5/ports"
port_rc=$?
set -e
if [[ $port_rc -ne 0 ]]; then
  if [[ -f $5/ports/verdict.tsv ]]; then
    cp -- "$5/ports/verdict.tsv" "$5/verdict.tsv"
  else
    printf 'INVALID\tport_test_did_not_run\n' >"$5/verdict.tsv"
  fi
  exit "$port_rc"
fi
exec bash "$script_dir/../_shared/evaluate_source_candidate_suite.sh" "$@"
