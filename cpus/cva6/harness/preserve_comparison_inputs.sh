#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: preserve_comparison_inputs.sh <output-dir> <test-name> <rtl-log> <reference-log>" >&2
  exit 2
fi

OUTPUT_DIR=$1
TEST_NAME=$2
RTL_LOG=$3
REFERENCE_LOG=$4

case "$TEST_NAME" in
  ''|*/*|.*) echo "invalid test name: $TEST_NAME" >&2; exit 2 ;;
esac
if [ ! -f "$RTL_LOG" ] || [ ! -f "$REFERENCE_LOG" ]; then
  echo "comparison input is missing for $TEST_NAME" >&2
  exit 2
fi

RTL_OUTPUT=$OUTPUT_DIR/rtl/$TEST_NAME.log
REFERENCE_OUTPUT=$OUTPUT_DIR/reference/$TEST_NAME.log
mkdir -p "$(dirname "$RTL_OUTPUT")" "$(dirname "$REFERENCE_OUTPUT")"
cp "$RTL_LOG" "$RTL_OUTPUT"
cp "$REFERENCE_LOG" "$REFERENCE_OUTPUT"
(
  cd "$OUTPUT_DIR"
  sha256sum "rtl/$TEST_NAME.log" "reference/$TEST_NAME.log" \
    > "$TEST_NAME.sha256"
  sha256sum --check "$TEST_NAME.sha256" >/dev/null
)
