#!/usr/bin/env bash
set -uo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 SIMULATOR PROGRAM LOG [ARGUMENT_AFTER_PROGRAM...]" >&2
  exit 2
fi
simulator=$1
program=$2
log=$3
shift 3
# The longest reference program, rv64mi-p-cache_replacement_cycles, ends after 202,604 cycles.
max_cycles=${BOOM_MAX_CYCLES:-2500000}
# About 1,500 cycles/s were observed with eight parallel traced runs, so the cycle limit ends first.
wall_seconds=${BOOM_SIMULATION_WALL_SEC:-3600}
timeout "$wall_seconds" "$simulator" +verbose +max-cycles="$max_cycles" "$program" "$@" >"$log" 2>&1
