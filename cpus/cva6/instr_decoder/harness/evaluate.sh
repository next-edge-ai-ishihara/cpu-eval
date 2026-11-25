#!/usr/bin/env bash
set -euo pipefail

script_directory=$(cd "$(dirname "$0")" && pwd)
bash "$script_directory/evaluate_ports.sh" "$@"
CPU_EVAL_MODULE=instr_decoder \
  exec "$script_directory/../../copro_alu/harness/evaluate.sh" "$@"
