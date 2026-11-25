#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 6 ]; then
  echo "usage: evaluate_suite.sh <Ibex checkout> <Spike install> <relative RTL path> <candidate> <results directory> <program.elf>..." >&2
  exit 2
fi

ibex="$(realpath "$1")"
spike_install="$(realpath "$2")"
rtl_path="$3"
candidate="$(realpath "$4")"
results="$(realpath -m "$5")"
shift 5
programs=("$@")
expected_revision="405c6d1d8220a18b2f9196141167a5875422dee4"

if [ "$rtl_path" != rtl/ibex_cs_registers.sv ]; then
  echo "unexpected target for the ibex_cs_registers evaluator" >&2
  exit 2
fi

test "$(git -c safe.directory="$ibex" -C "$ibex" rev-parse HEAD)" = "$expected_revision" || {
  echo "unexpected Ibex revision" >&2
  exit 2
}
target="$ibex/$rtl_path"
case "$target" in
  "$ibex"/rtl/*.sv|"$ibex"/vendor/lowrisc_ip/ip/prim_generic/rtl/*.sv) ;;
  *) echo "target is outside the selected CPU module population" >&2; exit 2 ;;
esac
if [ ! -f "$target" ] || [ ! -f "$candidate" ] || [ ! -x "$spike_install/bin/spike" ]; then
  echo "missing target, candidate, or Spike" >&2
  exit 2
fi
for program in "${programs[@]}"; do
  test -f "$program" || { echo "missing program: $program" >&2; exit 2; }
done
for tool in fusesoc verilator timeout; do
  command -v "$tool" >/dev/null || { echo "missing command: $tool" >&2; exit 2; }
done

mkdir -p "$results"
exec 9>"$ibex/.cpu_eval.lock"
flock 9
support_target="$ibex/rtl/ibex_core.sv"
backup=''
support_backup=''
if ! backup="$(mktemp -p "$(dirname "$target")" .cpu-eval-reference-XXXXXX)" ||
   ! support_backup="$(mktemp -p "$(dirname "$support_target")" .cpu-eval-support-XXXXXX)"; then
  rm -f "$backup" "$support_backup"
  printf 'INVALID\trestoration inputs\n' >"$results/verdict.tsv"
  exit 2
fi
if ! git -c safe.directory="$ibex" -C "$ibex" show "$expected_revision:$rtl_path" >"$backup" ||
   ! cp "$support_target" "$support_backup"; then
  rm -f "$backup" "$support_backup"
  printf 'INVALID\trestoration inputs\n' >"$results/verdict.tsv"
  exit 2
fi
if ! reference_hash="$(sha256sum "$backup" | cut -d' ' -f1)" ||
   ! support_hash="$(sha256sum "$support_backup" | cut -d' ' -f1)"; then
  printf 'INVALID\trestoration input hashes\n' >"$results/verdict.tsv"
  exit 2
fi
cleanup() {
  status=$?
  trap - EXIT
  restore_failed=0
  install -m 644 "$backup" "$target" || restore_failed=1
  install -m 644 "$support_backup" "$support_target" || restore_failed=1
  restored_hash="$(sha256sum "$target" | cut -d' ' -f1)" || restore_failed=1
  restored_support_hash="$(sha256sum "$support_target" | cut -d' ' -f1)" || restore_failed=1
  if [ "$restore_failed" -ne 0 ] ||
     [ "$restored_hash" != "$reference_hash" ] ||
     [ "$restored_support_hash" != "$support_hash" ]; then
    echo "failed to restore reference sources" >&2
    printf 'INVALID\tsource restoration\n' >"$results/verdict.tsv"
    exit 2
  fi
  if ! rm -f "$backup" "$support_backup"; then
    printf 'INVALID\trestoration input cleanup\n' >"$results/verdict.tsv"
    exit 2
  fi
  exit "$status"
}
trap cleanup EXIT
if ! cp "$candidate" "$target" ||
   ! git -c safe.directory="$ibex" -C "$ibex" apply \
     "$(dirname "$0")/test-patches/0001-remove-private-pmp-fcov-reference.patch"; then
  printf 'INVALID\tcandidate preparation\n' >"$results/verdict.tsv"
  exit 2
fi

read -r -a config_options <<<"$(cd "$ibex" && python3 util/ibex_config.py small fusesoc_opts)"
build="$ibex/build/lowrisc_ibex_ibex_simple_system_cosim_0"
rm -rf "$build"
export PKG_CONFIG_PATH="$spike_install/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
if ! (
  cd "$ibex"
  fusesoc --cores-root=. run --target=sim --setup --build \
    lowrisc:ibex:ibex_simple_system_cosim "${config_options[@]}" \
    --verilator_options="-Wno-fatal -DBASE_ISA=ibex_pkg::BaseIsaRV32I"
) >"$results/build.log" 2>&1; then
  set +e
  python3 "$(dirname "$0")/../_shared/candidate_error.py" "$results/build.log" "$ibex" "$rtl_path" \
    "$candidate" "$(dirname "$0")/SPEC.md"
  diagnostic_status=$?
  set -e
  if [ "$diagnostic_status" -eq 1 ]; then
    printf 'FAIL\tcandidate compile diagnostic\n' >"$results/verdict.tsv"
    exit 1
  fi
  printf 'INVALID\tbuild environment\n' >"$results/verdict.tsv"
  exit 2
fi

sim="$build/sim-verilator/Vibex_simple_system"
test -x "$sim" || { printf 'INVALID\tmissing simulator\n' >"$results/verdict.tsv"; exit 2; }
export LD_LIBRARY_PATH="$spike_install/lib:${LD_LIBRARY_PATH:-}"
printf 'program\tsha256\n' >"$results/programs.tsv"
failed=()
incomplete=()
invalid() {
  if [ "${#failed[@]}" -eq 0 ]; then
    { printf 'INVALID'; printf '\t%s' "$@"; printf '\n'; } >"$results/verdict.tsv"
    exit 2
  fi
  { printf 'INVALID'; printf '\t%s' "$@"; printf '\n'; } >>"$results/invalid-after-fail.tsv"
}
for program in "${programs[@]}"; do
  name="$(basename "$program")"
  log="$results/$name.log"
  run_dir="$results/raw/${name%.elf}"
  mkdir -p "$run_dir"
  printf '%s\t%s\n' "$program" "$(sha256sum "$program" | cut -d' ' -f1)" \
    >>"$results/programs.tsv"
  set +e
  (
    cd "$run_dir"
    timeout 1800 "$sim" \
      --term-after-cycles=2000000 \
      --meminit=ram,"$program"
  ) >"$log" 2>&1
  status=$?
  set -e
  case "$status" in
    124|137|143)
      invalid "$name" "execution_interrupted=$status"
      continue ;;
  esac
  for raw in simple_system_cosim.log ibex_simple_system.log; do
    if [ ! -f "$run_dir/$raw" ]; then
      incomplete+=("$name")
      continue 2
    fi
  done
  if grep -qE 'FAILURE: Co-simulation mismatch|%(Error|Fatal):.*Co-simulation mismatch seen' "$log"; then
    failed+=("$name")
    continue
  fi
  if [ "$status" -eq 0 ] && grep -q 'Simulation timeout of .* cycles reached' "$log"; then
    incomplete+=("$name")
    continue
  fi

  raw=trace_core_00000000.log
  if [ ! -f "$run_dir/$raw" ]; then
    incomplete+=("$name")
    continue
  fi
  if [ "$status" -ne 0 ] || ! grep -q 'Co-simulation matched' "$log"; then
    incomplete+=("$name")
    continue
  fi
  if ! grep -qF 'Terminating simulation by software request.' "$log"; then
    incomplete+=("$name")
    continue
  fi
done
if [ "${#failed[@]}" -gt 0 ]; then
  printf 'FAIL\t%s\n' "$(IFS=,; printf '%s' "${failed[*]}")" >"$results/verdict.tsv"
  exit 1
fi
if [ "${#incomplete[@]}" -gt 0 ]; then
  printf 'FAIL\tprogram did not complete\t%s\n' "$(IFS=,; printf '%s' "${incomplete[*]}")" >"$results/verdict.tsv"
  exit 1
fi
printf 'PASS\tall programs\n' >"$results/verdict.tsv"
