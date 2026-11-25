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
reference_hash="$(git -c safe.directory="$ibex" -C "$ibex" show "$expected_revision:$rtl_path" | sha256sum | cut -d' ' -f1)"
backup="$(mktemp -p "$(dirname "$target")" .cpu-eval-reference-XXXXXX)"
git -c safe.directory="$ibex" -C "$ibex" show "$expected_revision:$rtl_path" >"$backup"
core_backup=
core_restore=0
core="$ibex/rtl/ibex_core.sv"
cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  restore_failed=0
  install -m 644 "$backup" "$target" || restore_failed=1
  if [ "$core_restore" -eq 1 ]; then
    cat "$core_backup" >"$core" || restore_failed=1
    if ! cmp -s "$core_backup" "$core"; then
      restore_failed=1
    fi
  fi
  if ! restored_hash="$(sha256sum "$target" | cut -d' ' -f1)"; then
    restore_failed=1
  elif [ "$restored_hash" != "$reference_hash" ]; then
    restore_failed=1
  fi
  if [ "$restore_failed" -ne 0 ]; then
    echo "failed to restore reference source; backups retained" >&2
    printf 'INVALID\treference restoration\n' >"$results/verdict.tsv"
    exit 2
  fi
  rm -f "$backup"
  if [ -n "$core_backup" ]; then rm -f "$core_backup"; fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if [ "$rtl_path" = rtl/ibex_if_stage.sv ]; then
  core_hash="$(sha256sum "$core" | cut -d' ' -f1)"
  if [ "$core_hash" != 88b8bf3907472f1d413380f62234a7fbf53cb1de392a6660e6ef2d684a2416fd ]; then
    printf 'INVALID\tunexpected core source\n' >"$results/verdict.tsv"
    exit 2
  fi
  core_backup="$(mktemp -p "$(dirname "$core")" .cpu-eval-core-XXXXXX)"
  cat "$core" >"$core_backup"
  if ! cmp -s "$core_backup" "$core"; then
    printf 'INVALID\tcore backup\n' >"$results/verdict.tsv"
    exit 2
  fi
  core_restore=1
  if ! git -c safe.directory="$ibex" -C "$ibex" apply "$(dirname "$0")/if-pmp-observation.patch"; then
    printf 'INVALID\tIF coverage observation patch\n' >"$results/verdict.tsv"
    exit 2
  fi
fi
cp "$candidate" "$target"

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
  python3 "$(dirname "$0")/candidate_error.py" "$results/build.log" "$ibex" "$rtl_path" "$candidate"
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
run_directed() {
  local label=$1 directed=$2 directed_status=0
  shift 2
  bash "$@" || directed_status=$?
  if [ "$directed_status" -ne 0 ]; then
    if [ ! -f "$directed/verdict.tsv" ]; then
      printf 'INVALID\t%s verdict missing\texit=%s\n' "$label" "$directed_status" >"$results/verdict.tsv"
      exit 2
    fi
    cp "$directed/verdict.tsv" "$results/verdict.tsv"
    exit "$directed_status"
  fi
}
problem_root="$(dirname "$0")/.."
case "$rtl_path" in
  rtl/ibex_fetch_fifo.sv)
    directed="$results/directed-fetch-fifo"
    if [ -e "$directed" ]; then
      printf 'INVALID\tfetch FIFO port results already exist\n' >"$results/verdict.tsv"
      exit 2
    fi
    run_directed 'fetch FIFO port' "$directed" "$problem_root/fetch_fifo/evaluate_ports.sh" "$ibex" "$candidate" "$directed"
    ;;
  rtl/ibex_register_file_ff.sv)
    directed="$results/directed-register-file-ff"
    run_directed 'register-file port' "$directed" "$problem_root/register_file_ff/evaluate_ports.sh" "$ibex" "$candidate" "$directed"
    ;;
  rtl/ibex_csr.sv)
    directed="$results/directed-csr"
    run_directed 'CSR port' "$directed" "$problem_root/csr/evaluate_ports.sh" "$ibex" "$candidate" "$directed"
    ;;
  rtl/ibex_prefetch_buffer.sv)
    directed="$results/directed-prefetch-buffer"
    run_directed 'prefetch buffer port' "$directed" "$problem_root/prefetch_buffer/evaluate_ports.sh" "$ibex" "$candidate" "$directed"
    ;;
  rtl/ibex_counter.sv)
    directed="$results/directed-counter"
    run_directed 'counter port' "$directed" "$problem_root/counter/evaluate_ports.sh" "$ibex" "$candidate" "$directed"
    ;;
  vendor/lowrisc_ip/ip/prim_generic/rtl/prim_buf.sv | vendor/lowrisc_ip/ip/prim_generic/rtl/prim_clock_gating.sv)
    primitive="$(basename "$rtl_path" .sv)"
    directed="$results/directed-primitive"
    run_directed 'primitive port' "$directed" "$(dirname "$0")/evaluate_primitive.sh" "$ibex" "$candidate" \
      "$problem_root/$primitive/harness/primitive_tb.cpp" "$primitive" "$directed"
    ;;
esac
printf 'PASS\tall programs\n' >"$results/verdict.tsv"
