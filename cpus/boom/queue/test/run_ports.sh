#!/usr/bin/env bash
set -euo pipefail

directory=$(cd -- "$(dirname -- "$0")" && pwd)
evidence=$1
candidate=$2
log="$evidence/queue-ports.log"

code=0
(cd "$BOOM_WORKTREE" && "$BOOM_JAVA_BIN/java" \
    -Dcpu.eval.queue.test.target="$evidence/queue-ports" \
    -Dsbt.coursier=false -Dsbt.ivy.home="$BOOM_SBT_IVY_HOME" -Dsbt.version="${BOOM_SBT_VERSION:-1.5.7}" \
    -jar "$BOOM_CHISEL_SBT" \
    ";set boom / Test / unmanagedSources := Seq(file(\"$directory/QueueSyncReadPortsTest.scala\"));set boom / libraryDependencies += \"edu.berkeley.cs\" %% \"chisel-iotesters\" % \"2.5.0\" % Test;boom/testOnly boom.tests.QueueSyncReadPortsTest") \
    > "$log" 2>&1 || code=$?

if [[ $code == 0 ]] && grep -q 'All tests passed' "$log" &&
    [[ $(grep -c 'CPU_EVAL_QUEUE_SYNC_OBSERVATION ' "$log") == 10 ]]; then
  printf 'queue-sync-read-ports\tPASS\t0\n'
elif [[ $code == 0 ]] && grep -q 'All tests passed' "$log"; then
  printf 'queue-sync-read-ports\tFAIL\t1\n'
else
  cause_rc=0
  cause=$(python3 "$directory/../../_shared/failure_cause.py" directed "$log" "$code" \
    "$evidence/candidate-region.json" "$candidate") || cause_rc=$?
  printf 'queue-sync-read-ports\t%s\t%s\n' "${cause%%$'\t'*}" "$((cause_rc == 1 ? 1 : 2))"
fi
