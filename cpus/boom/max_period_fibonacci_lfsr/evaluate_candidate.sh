#!/usr/bin/env bash
set -euo pipefail
directory=$(cd -- "$(dirname -- "$0")" && pwd)
fixture="$directory/test/MaxPeriodFibonacciLFSRPortsTest.scala"
program=rv64mi-p-cache_replacement_cycles

if [[ ${1:-} == --ports ]]; then
    [[ $# -eq 3 ]] || exit 2
    candidate=$2
    evidence=$3
    set +e
    (cd "$BOOM_WORKTREE" && "$BOOM_JAVA_BIN/java" \
        -Dcpu.eval.lfsr.target="$evidence/lfsr-ports" \
        -Dsbt.coursier=false -Dsbt.ivy.home="$BOOM_SBT_IVY_HOME" -Dsbt.version="${BOOM_SBT_VERSION:-1.5.7}" \
        -jar "$BOOM_CHISEL_SBT" \
        ";set boom / Test / unmanagedSources := Seq(file(\"$fixture\"));set boom / libraryDependencies += \"edu.berkeley.cs\" %% \"chisel-iotesters\" % \"2.5.0\" % Test;boom/testOnly boom.tests.MaxPeriodFibonacciLFSRPortsTest") \
        > "$evidence/ports.log" 2>&1
    code=$?
    set -e
    if [[ $code -eq 0 ]] && grep -q 'All tests passed' "$evidence/ports.log" &&
        [[ $(grep -c 'CPU_EVAL_LFSR_PORT_PASS' "$evidence/ports.log") -eq 5 ]]; then
        printf 'PASS\t0\n' > "$evidence/ports.tsv"
    elif [[ $code -eq 0 ]] && grep -q 'All tests passed' "$evidence/ports.log"; then
        printf 'FAIL\t1\n' > "$evidence/ports.tsv"
        exit 1
    else
        cause_rc=0
        cause=$(python3 "$directory/../_shared/failure_cause.py" directed "$evidence/ports.log" "$code" \
            "$evidence/candidate-region.json" "$candidate") || cause_rc=$?
        [[ $cause_rc -eq 1 ]] || cause_rc=2
        printf '%s\t%s\n' "${cause%%$'\t'*}" "$cause_rc" > "$evidence/ports.tsv"
        exit "$cause_rc"
    fi
    sha256sum "$candidate" "$fixture" "$evidence/ports.log" > "$evidence/ports.sha256"
    exit 0
fi

if [[ $# -ne 5 ]]; then
    echo "usage: $0 SOURCE_UNIT CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
    exit 2
fi
source_unit=$1
candidate=$2
tests=$3
test_root=$4
evidence=$5
[[ $source_unit == MaxPeriodFibonacciLFSR && $(<"$tests") == "$program" ]] || exit 2

set +e
CPU_EVAL_MAX_PERIOD_LFSR_PORTS=1 "$directory/../_shared/evaluate_source_candidate_suite.sh" \
    "$source_unit" "$candidate" "$tests" "$test_root" "$evidence/cpu"
cpu_status=$?
set -e
test_result="$evidence/cpu/tests/000-$program"
summary="$evidence/summary.tsv"
printf 'test\tverdict\texit_code\n' > "$summary"
if [[ -f "$test_result/ports.tsv" ]]; then
    read -r port_verdict port_status < "$test_result/ports.tsv"
    printf 'lfsr_public_ports\t%s\t%s\n' "$port_verdict" "$port_status" >> "$summary"
    [[ $port_verdict == PASS ]] || exit "$port_status"
fi
if [[ -f "$evidence/cpu/summary.tsv" ]]; then
    tail -n +2 "$evidence/cpu/summary.tsv" >> "$summary"
fi
[[ $cpu_status -eq 0 && -f "$test_result/ports.tsv" && $(<"$test_result/ports.tsv") == $'PASS\t0' ]] &&
    awk -F '\t' 'NR > 1 {seen++; if ($2 != "PASS") bad++} END {exit (!seen || bad)}' "$summary"
