#!/usr/bin/env bash
# port_observation <build-log> <observation-log> <compiled-source> <submission> <seconds> <binary> <build command...>
# Returns 0 when the fixed bench ran to its end, 1 when the build or run failed with the
# submission (the bench builds and runs with the reference), and 2 for a tool, resource or kill stop.
port_observation() {
  local build_log=$1 observation_log=$2 source=$3 submission=$4 seconds=$5 binary=$6 status=0
  shift 6
  "$@" >"$build_log" 2>&1 || status=$?
  if [ "$status" -ne 0 ]; then
    case "$status" in 124|126|127|137|143) return 2 ;; esac
    python3 "$(dirname "${BASH_SOURCE[0]}")/candidate_error.py" "$build_log" "$source" \
      --submitted "$submission" >/dev/null
    [ "$?" -eq 1 ] && return 1
    return 2
  fi
  timeout "$seconds" "$binary" >"$observation_log" 2>&1 || status=$?
  case "$status" in
    0) return 0 ;;
    124|126|127|137|143) return 2 ;;
  esac
  return 1
}
