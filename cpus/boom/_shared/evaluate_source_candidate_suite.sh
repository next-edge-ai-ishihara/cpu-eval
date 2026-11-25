#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 SOURCE_UNIT CANDIDATE TESTS_FILE TEST_ROOT EVIDENCE_DIR" >&2
  exit 2
fi

source_unit=$1
candidate=$2
tests_file=$3
test_root=$4
evidence_dir=$5
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
: "${BOOM_TEST_POLICY:=}"
: "${BOOM_TEST_PARALLELISM:=1}"
if [[ ! $BOOM_TEST_PARALLELISM =~ ^[1-9][0-9]*$ ]]; then
  echo "BOOM_TEST_PARALLELISM must be a positive integer" >&2
  exit 2
fi

policy_for_test() {
  local test_name=$1
  if [[ -z $BOOM_TEST_POLICY ]]; then
    printf 'trace\t\t\n'
    return
  fi
  awk -F '\t' -v test="$test_name" '
    NR == 1 { next }
    $1 == test { print $2 "\t" $3 "\t" $4; found++ }
    END { if (found != 1) exit 1 }
  ' "$BOOM_TEST_POLICY"
}

run_first_test() {
  local mode=$1 register=$2 expected=$3
  case "$mode" in
    trace)
      BOOM_PRESERVE_SIMULATOR=1 "$script_dir/evaluate_source_candidate.sh" \
        "$source_unit" "$candidate" "$test_root/$first" "$first_dir"
      ;;
    directed_program)
      BOOM_DIRECTED_PROGRAM=1 BOOM_PRESERVE_SIMULATOR=1 \
        "$script_dir/evaluate_source_candidate.sh" \
        "$source_unit" "$candidate" "$test_root/$first" "$first_dir"
      ;;
    directed_register|directed_register_max)
      BOOM_DIRECTED_XREG=$register BOOM_DIRECTED_EXPECTED=$expected \
        BOOM_DIRECTED_COMPARISON=$mode \
        BOOM_PRESERVE_SIMULATOR=1 "$script_dir/evaluate_source_candidate.sh" \
        "$source_unit" "$candidate" "$test_root/$first" "$first_dir"
      ;;
    *)
      echo "unknown test policy for $first: $mode" >&2
      return 2
      ;;
  esac
}

mapfile -t tests < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$tests_file")
if [[ ${#tests[@]} -eq 0 ]]; then
  echo "test list is empty: $tests_file" >&2
  exit 2
fi

mkdir -p "$evidence_dir/tests"
summary="$evidence_dir/summary.tsv"
printf 'test\tverdict\texit_code\n' >"$summary"

first=${tests[0]}
first_dir="$evidence_dir/tests/000-$first"
first_policy=$(policy_for_test "$first") || {
    echo "missing or duplicate test policy for $first" >&2
    exit 2
  }
IFS=$'\t' read -r first_mode first_register first_expected <<<"$first_policy"
set +e
run_first_test "$first_mode" "$first_register" "$first_expected"
first_rc=$?
set -e
if [[ ! -f $first_dir/build.exit || $(<"$first_dir/build.exit") != 0 ]]; then
  if [[ $first_rc == 1 && -f $first_dir/verdict.tsv && $(cut -f1 "$first_dir/verdict.tsv") == FAIL* ]]; then
    cp "$first_dir/verdict.tsv" "$evidence_dir/verdict.tsv"
    printf '%s\t%s\t1\n' "$first" "$(cut -f1 "$first_dir/verdict.tsv")" >>"$summary"
    exit 1
  fi
  printf '%s\tINVALID\t%s\n' "$first" "$first_rc" >>"$summary"
  exit $((first_rc == 0 || first_rc == 1 ? 2 : first_rc))
fi
first_verdict=$(cut -f1 "$first_dir/verdict.tsv" 2>/dev/null || printf INVALID)
printf '%s\t%s\t%s\n' "$first" "$first_verdict" "$first_rc" >>"$summary"

simulator="$first_dir/simulator"
if [[ ! -x $simulator ]]; then
  echo "preserved simulator is missing: $simulator" >&2
  exit 2
fi

# Concurrent workers must write only within their own test directory.
# Simulator instances use an OS-assigned remote-bitbang port (port 0).
_boom_run_one_test() {
  # Pass scalar arguments because exported Bash environments do not carry arrays.
  local index=$1
  local test_name=$2
  local test_program="$test_root/$test_name"
  local test_dir
  test_dir=$(printf '%s/tests/%03d-%s' "$evidence_dir" "$index" "$test_name")
  mkdir -p "$test_dir"

  local policy mode register expected
  policy=$(policy_for_test "$test_name") || {
    echo "missing or duplicate test policy for $test_name" >&2
    return 2
  }
  IFS=$'\t' read -r mode register expected <<<"$policy"

  local rtl_rc=0 run_rc=0
  "$script_dir/run_simulator.sh" "$simulator" "$test_program" "$test_dir/rtl.log" || rtl_rc=$?
  printf '%s\n' "$rtl_rc" >"$test_dir/rtl.exit"
  python3 "$script_dir/failure_cause.py" run "$test_dir/rtl.log" "$rtl_rc" \
    >"$test_dir/run-verdict.tsv" || run_rc=$?
  if [[ $run_rc -ne 0 && ( $run_rc -ne 2 || $mode != trace ) ]]; then
    mv -- "$test_dir/run-verdict.tsv" "$test_dir/verdict.tsv"
    printf '%s\n' "$run_rc" >"$test_dir/effective_rc.txt"
    return "$run_rc"
  fi
  [[ $run_rc -ne 0 ]] || rm -f -- "$test_dir/run-verdict.tsv"

  local rc verdict observed
  if [[ $mode == directed_program ]]; then
    observed=$(sed -nE 's/.*\*\*\* (PASSED|FAILED) \*\*\*.*/\1/p' "$test_dir/rtl.log" | tail -1)
    if [[ $rtl_rc -eq 0 && $observed == PASSED ]]; then
      rc=0; verdict=PASS
    else
      rc=1; verdict=FAIL
    fi
    printf 'expected\tobserved\nPASSED\t%s\n' "$observed" >"$test_dir/directed-result.tsv"
  elif [[ $mode == directed_register || $mode == directed_register_max ]]; then
    if [[ ! $register =~ ^x([1-9]|[12][0-9]|3[01])$ || -z $expected ]]; then
      echo "invalid directed-register policy for $test_name" >&2
      return 2
    fi
    observed=$(python3 - "$test_dir/rtl.log" "$register" <<'PY'
import re, sys
p = re.compile(rf"\b{re.escape(sys.argv[2])}\s+0x([0-9a-fA-F]+)\b")
values = [m.group(1).lower() for line in open(sys.argv[1], errors="replace") if (m := p.search(line))]
if not values:
    raise SystemExit(2)
print(f"{int(values[-1], 16):016x}")
PY
    ) || {
      printf 'FAIL\tmissing_directed_register\t%s\n' "$register" >"$test_dir/verdict.tsv"
      printf '1\n' >"$test_dir/effective_rc.txt"
      return 1
    }
    expected=$(printf '%016x' "$expected")
    printf 'register\texpected\tobserved\n%s\t%s\t%s\n' \
      "$register" "$expected" "$observed" >"$test_dir/directed-result.tsv"
    if [[ -n $observed && $rtl_rc -eq 0 ]] &&
        [[ $observed == "$expected" || ( $mode == directed_register_max && $observed < $expected ) ]]; then
      rc=0; verdict=PASS
    else
      rc=1; verdict=FAIL
    fi
  elif [[ $mode == trace ]]; then
    local spike_rc
    set +e
    timeout 180 "$BOOM_RISCV_TOOLS/bin/spike" --isa=rv64imafdc --log-commits \
      "$test_program" >"$test_dir/spike.stdout" 2>"$test_dir/spike.log"
    spike_rc=$?
    set -e
    printf '%s\n' "$spike_rc" >"$test_dir/spike.exit"
    if [[ $spike_rc -ne 0 ]]; then
      rc=2; verdict=INVALID
    else
      set +e
      python3 "$BOOM_TRACE_COMPARATOR" "$test_dir/rtl.log" "$test_dir/spike.log" \
        --report "$test_dir/comparison.json"
      rc=$?
      set -e
      if [[ $run_rc -eq 2 ]]; then
        # An interrupted run is FAIL only when its trace already differs from Spike.
        if [[ $rc -eq 1 ]] && python3 "$script_dir/trace_mismatch.py" "$test_dir/comparison.json"; then
          verdict=FAIL
        else
          rc=2; verdict=INVALID
        fi
      elif [[ $rc -eq 0 ]]; then
        verdict=PASS
      elif [[ $rc -eq 1 ]]; then
        verdict=FAIL
      else
        rc=2; verdict=INVALID
      fi
    fi
  else
    echo "unknown test policy for $test_name: $mode" >&2
    return 2
  fi
  if [[ $verdict == INVALID && $run_rc -eq 2 ]]; then
    mv -- "$test_dir/run-verdict.tsv" "$test_dir/verdict.tsv"
  elif [[ $verdict == PASS && $rtl_rc -ne 0 ]]; then
    rc=1; verdict=FAIL_INCOMPLETE_EXECUTION
    printf 'FAIL_INCOMPLETE_EXECUTION\trtl_nonzero_exit\t%s\n' "$rtl_rc" >"$test_dir/verdict.tsv"
  else
    printf '%s\tfull_suite\n' "$verdict" >"$test_dir/verdict.tsv"
  fi
  printf '%s\n' "$rc" >"$test_dir/comparison.exit"
  printf '%s\n' "$rc" >"$test_dir/effective_rc.txt"
  return "$rc"
}

remaining_indices=()
work_items=()
for index in "${!tests[@]}"; do
  (( index == 0 )) && continue
  remaining_indices+=("$index")
  work_items+=("$index"$'\t'"${tests[index]}")
done
set +e
if [[ ${#work_items[@]} -eq 0 ]]; then
  :
elif [[ $BOOM_TEST_PARALLELISM -le 1 ]]; then
  for item in "${work_items[@]}"; do
    IFS=$'\t' read -r index test_name <<<"$item"
    ( _boom_run_one_test "$index" "$test_name" )
  done
else
  export -f _boom_run_one_test policy_for_test
  export script_dir test_root evidence_dir simulator BOOM_RISCV_TOOLS BOOM_TRACE_COMPARATOR \
    BOOM_TEST_POLICY
  printf '%s\n' "${work_items[@]}" | \
    xargs -P "$BOOM_TEST_PARALLELISM" -L1 \
      bash -c '_boom_run_one_test "$@"' _
fi
set -e
for index in "${remaining_indices[@]}"; do
  test_name=${tests[index]}
  test_dir=$(printf '%s/tests/%03d-%s' "$evidence_dir" "$index" "$test_name")
  if [[ ! -f $test_dir/verdict.tsv || ! -f $test_dir/effective_rc.txt ]]; then
    echo "worker for $test_name produced no verdict (manifest-level abort)" >&2
    exit 2
  fi
  verdict=$(cut -f1 "$test_dir/verdict.tsv")
  rc=$(<"$test_dir/effective_rc.txt")
  printf '%s\t%s\t%s\n' "$test_name" "$verdict" "$rc" >>"$summary"
done

if [[ $source_unit == RegisterReadDecode ]]; then
  ports_dir="$evidence_dir/tests/register-read-decode-ports"
  ports_rc=0
  "$script_dir/evaluate_directed_source_test.sh" "$source_unit" "$candidate" \
    "$script_dir/../register_read_decode/test/RegisterReadDecodePortsTest.scala" boom.tests.RegisterReadDecodePortsTest \
    "$ports_dir" || ports_rc=$?
  ports_verdict=$(cut -f1 "$ports_dir/verdict.tsv" 2>/dev/null || printf INVALID)
  if [[ $ports_verdict == PASS || $ports_verdict == FAIL ]] &&
    ! grep -qF 'REGISTER_READ_DECODE_OBSERVATION ' "$ports_dir/test.log"; then
    ports_verdict=FAIL
    ports_rc=1
  fi
  printf 'register-read-decode-ports\t%s\t%s\n' "$ports_verdict" "$ports_rc" >>"$summary"
fi
if [[ $source_unit == Queue ]]; then
  if [[ -s $first_dir/queue-ports.tsv ]]; then
    IFS=$'\t' read -r ports_test ports_verdict ports_rc < "$first_dir/queue-ports.tsv"
  else
    ports_test=queue-sync-read-ports
    ports_verdict=INVALID
    ports_rc=2
  fi
  printf '%s\t%s\t%s\n' "$ports_test" "$ports_verdict" "$ports_rc" >>"$summary"
fi
if [[ $source_unit == PipelinedMulUnit ]]; then
  ports_dir="$evidence_dir/tests/pipelined-mul-unit-ports"
  ports_rc=0
  "$script_dir/evaluate_directed_source_test.sh" "$source_unit" "$candidate" \
    "$script_dir/../pipelined_mul_unit/test/PipelinedMulUnitPortsTest.scala" boom.tests.PipelinedMulUnitPortsTest \
    "$ports_dir" || ports_rc=$?
  ports_verdict=$(cut -f1 "$ports_dir/verdict.tsv" 2>/dev/null || printf INVALID)
  if [[ $ports_verdict == PASS || $ports_verdict == FAIL ]] &&
    ! grep -qF 'PIPELINED_MUL_UNIT_OBSERVATIONS_STARTED' "$ports_dir/test.log"; then
    ports_verdict=FAIL
    ports_rc=1
  fi
  printf 'pipelined-mul-unit-ports\t%s\t%s\n' "$ports_verdict" "$ports_rc" >>"$summary"
fi
if [[ $source_unit == MulDiv ]]; then
  ports_dir="$evidence_dir/tests/mul-div-ports"
  ports_rc=0
  "$script_dir/evaluate_directed_source_test.sh" "$source_unit" "$candidate" \
    "$script_dir/../mul_div/test/MulDivPortsTest.scala" boom.tests.MulDivPortsTest \
    "$ports_dir" || ports_rc=$?
  ports_verdict=$(cut -f1 "$ports_dir/verdict.tsv" 2>/dev/null || printf INVALID)
  if [[ $ports_verdict == PASS || $ports_verdict == FAIL ]] &&
    ! grep -qF 'MULDIV_PORT_OBSERVATIONS_STARTED' "$ports_dir/test.log"; then
    ports_verdict=FAIL
    ports_rc=1
  fi
  printf 'mul-div-ports\t%s\t%s\n' "$ports_verdict" "$ports_rc" >>"$summary"
fi
if [[ $source_unit == Mul54 ]]; then
  timing_dir="$evidence_dir/tests/mul54-timing"
  timing_rc=0
  "$script_dir/evaluate_directed_source_test.sh" "$source_unit" "$candidate" \
    "$script_dir/../mul54/test/Mul54TimingTest.scala" boom.tests.Mul54TimingTest \
    "$timing_dir" || timing_rc=$?
  timing_verdict=$(cut -f1 "$timing_dir/verdict.tsv" 2>/dev/null || printf INVALID)
  if [[ $timing_verdict == PASS || $timing_verdict == FAIL ]] &&
    ! grep -qF 'MUL54_TIMING_OBSERVATIONS_STARTED' "$timing_dir/test.log"; then
    timing_verdict=FAIL
    timing_rc=1
  fi
  printf 'mul54-timing\t%s\t%s\n' "$timing_verdict" "$timing_rc" >>"$summary"
fi
sha256sum "$candidate" "$tests_file" "$summary" >"$evidence_dir/evidence.sha256"
# Any FAIL row decides the suite; other non-PASS rows are evaluator or environment failures.
awk -F '\t' 'NR > 1 { if ($2 ~ /^FAIL/) failed = 1; else if ($2 != "PASS") invalid = 1 }
  END { exit failed ? 1 : invalid ? 2 : 0 }' "$summary"
