#!/usr/bin/env python3
"""Evaluate one VeeR EL2 module candidate in a pinned checkout.

Replace the selected definition, run its recorded evaluator, save commands
and outputs, and restore the checkout. The fixed tree builds and runs with the
reference module, so a test that ends without PASS or FAIL after only the target
was replaced is the answer's fault unless the evaluator, a fixed input, a tool,
a resource or the wall clock failed. Exit 0 means PASS, 1 functional FAIL,
3 candidate compilation FAIL, 4 incomplete-execution FAIL and 2 INVALID.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager, ExitStack
import fcntl
import hashlib
import importlib.util
import json
import os
import re
import shutil
import shlex
import subprocess
import sys
import traceback
import signal
import time
from pathlib import Path

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--problem", required=True)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=1800)
    return parser.parse_args()


def find_problem_dir(repo: Path, problem: str) -> Path:
    problems = repo / "cpus/veer_el2/PROBLEMS.tsv"
    for line in problems.read_text(encoding="utf-8").splitlines()[1:]:
        fields = line.split("\t")
        if fields[0] == problem:
            return repo / "cpus/veer_el2" / fields[1]
    raise ValueError(f"unknown VeeR EL2 problem: {problem}")


def load_expected(problem_dir: Path, recipe: dict[str, object]) -> tuple[str, str | None]:
    expectation = recipe.get("comparison_expectation")
    if expectation is not None:
        if not isinstance(expectation, dict):
            raise ValueError("comparison_expectation must be an object")
        kind = expectation.get("kind")
        if kind == "self_check" and set(expectation) == {"kind"}:
            return "self_check", None
        if kind == "matched" and set(expectation) == {"kind", "expected"}:
            expected = expectation["expected"]
            if type(expected) is int and expected > 0:
                return "matched", str(expected)
        raise ValueError("invalid comparison_expectation")
    test = recipe.get("test", {})
    if isinstance(test, dict) and test.get("kind") == "directed_mcycle_probe":
        return "mcycle", str(test["reference_mcycle_delta"])
    if isinstance(test, dict) and test.get("reference_matched_instructions") is not None:
        return "matched", str(test["reference_matched_instructions"])
    raise ValueError("recipe must declare its comparison expectation")


def fixed_test_artifacts(recipe: dict[str, object]) -> list[dict[str, object]]:
    test = recipe.get("test") or {}
    if not isinstance(test, dict):
        return []
    recorded = test.get("post_generation_artifacts") or []
    if not isinstance(recorded, list):
        raise ValueError("post-generation artifacts must be a list")
    artifacts = list(recorded)
    if test.get("post_generation_patches") and not artifacts:
        raise ValueError("post-generation patches require recorded artifact hashes")
    expected = (test.get("generated_source_after_patch_sha256") or test.get("patched_source_sha256")
                or test.get("generated_source_sha256") or test.get("generated_source_before_patch_sha256"))
    if expected:
        name = str(test.get("name", "riscv_arithmetic_basic_test"))
        if not name or Path(name).name != name or name in {".", ".."}:
            raise ValueError(f"invalid generated test name: {name}")
        artifacts.append({"path": f"tools/riscv-dv/work/test_{name}/asm_test/{name}_0.S", "sha256": expected})
    unique = {}
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            raise ValueError("invalid post-generation artifact record")
        relative = Path(str(artifact["path"]))
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"invalid post-generation artifact path: {relative}")
        name = str(relative)
        if name in unique and unique[name]["sha256"] != artifact["sha256"]:
            raise ValueError(f"conflicting post-generation artifact hashes: {name}")
        unique[name] = artifact
    return list(unique.values())


def verify_post_generation_artifacts(checkout: Path, recipe: dict[str, object]) -> None:
    artifacts = fixed_test_artifacts(recipe)
    mismatches = []
    for artifact in artifacts:
        if not isinstance(artifact, dict):
            raise ValueError("invalid post-generation artifact record")
        relative = Path(str(artifact["path"]))
        expected = str(artifact["sha256"])
        path = checkout / relative
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        if actual != expected:
            mismatches.append({"path": str(relative), "expected": expected, "actual": actual})
    if mismatches:
        raise RuntimeError(
            "checkout does not contain the required post-generation test artifacts: "
            + json.dumps(mismatches, sort_keys=True)
        )


@contextmanager
def preserve_post_generation_artifacts(checkout: Path, recipe: dict[str, object]):
    artifacts = fixed_test_artifacts(recipe)
    snapshots: dict[Path, bytes] = {}
    for artifact in artifacts or []:
        if not isinstance(artifact, dict):
            raise ValueError("invalid post-generation artifact record")
        relative = Path(str(artifact["path"]))
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"invalid post-generation artifact path: {relative}")
        path = checkout / relative
        if not path.is_file():
            raise FileNotFoundError(f"post-generation artifact is unavailable: {path}")
        snapshots[path] = path.read_bytes()
    try:
        yield
    finally:
        for path, content in snapshots.items():
            path.write_bytes(content)


def stage_checkout_files(checkout: Path, problem_dir: Path, recipe: dict[str, object]) -> None:
    entries = recipe.get("checkout_files") or []
    if not isinstance(entries, list):
        raise ValueError("checkout_files must be a list")
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("checkout_files entries must be objects")
        source = (problem_dir / str(entry["source"])).resolve()
        destination_relative = Path(str(entry["destination"]))
        if destination_relative.is_absolute() or ".." in destination_relative.parts:
            raise ValueError(f"invalid checkout-file destination: {destination_relative}")
        if not source.is_file() or problem_dir.resolve() not in source.parents:
            raise FileNotFoundError(f"checkout-file source is unavailable: {source}")
        expected = entry.get("sha256")
        if expected and hashlib.sha256(source.read_bytes()).hexdigest() != expected:
            raise ValueError(f"checkout-file hash mismatch: {source}")
        destination = checkout / destination_relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)


def acquire_resource_locks(stack: ExitStack, recipe: dict[str, object]) -> None:
    resources = recipe.get("exclusive_resources") or []
    if not isinstance(resources, list) or not all(isinstance(item, str) for item in resources):
        raise ValueError("exclusive_resources must be a list of strings")
    lock_root = Path(os.environ.get("CPU_EVAL_RESOURCE_LOCK_DIR", "/tmp/cpu-eval-resource-locks"))
    lock_root.mkdir(parents=True, exist_ok=True)
    for resource in sorted(set(resources)):
        digest = hashlib.sha256(resource.encode("utf-8")).hexdigest()
        lock = stack.enter_context((lock_root / f"{digest}.lock").open("a+"))
        fcntl.flock(lock, fcntl.LOCK_EX)


def group_has_running_members(group: int) -> bool:
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
            if int(fields[2]) == group and int(fields[3]) == group and fields[0] != "Z":
                return True
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError:
            # Other users cannot join the newly created evaluator session.
            # An unreadable own process must keep restoration blocked.
            try:
                if entry.stat().st_uid == os.geteuid():
                    return True
            except FileNotFoundError:
                continue
    return False


def stop_evaluator_group(process: subprocess.Popen) -> None:
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass
        deadline = time.monotonic() + 0.2
        while group_has_running_members(process.pid):
            if sig == signal.SIGTERM and time.monotonic() >= deadline:
                break
            time.sleep(0.01)
        if not group_has_running_members(process.pid):
            break
    process.wait()


def evaluation_environment(overrides: dict[str, str]) -> dict[str, str]:
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("CPU_EVAL_EXPECTED_", "RISCV_DV_"))
           and key not in {"CPU_EVAL_REAL_VERILATOR", "CPU_EVAL_OBSERVER_DEC", "CPU_EVAL_MCYCLE_PROBE_TEST"}}
    env.update(overrides)
    return env


# Test scripts print this line before exit 2 for evaluator, fixed-input, tool or wall-clock
# failures; "timeout --verbose" reports its own wall-clock kills.
ENVIRONMENT_MARKER = re.compile(r"(?m)^CPU_EVAL_INVALID: ")
ENVIRONMENT_ERROR = re.compile(
    r"command not found|failed to download|out of memory|cannot allocate memory|"
    r"no space left on device|virtual memory exhausted|input/output error|"
    r"\bKilled\b|^timeout: sending signal ", re.I)
# Lines that compilers echo from the submitted source are not tool messages.
SOURCE_ECHO = re.compile(r"^\s*\d*\s*\|")
# Verilator reports build diagnostics with line and column and runtime errors with line only.
COMPILE_ERROR = re.compile(
    r"(?m)^%Error: Exiting due to|^%Error: Verilator internal fault|"
    r"^%Error(?:-[A-Z0-9_]+)?: (?:Internal Error: )?\S+:\d+:\d+: |"
    r"^\S+\.(?:cpp|h):\d+:\d+: (?:fatal )?error: |^make\[\d+\]: \*\*\* \[\S*verilated\.mk:\d+: ")


def evaluation_logs(stdout: str, stderr: str, results: Path) -> str:
    logs = [stdout, stderr]
    for path in sorted(results.rglob("*.log")):
        if path.is_file():
            logs.append(path.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(logs)


def environment_failure(logs: str) -> bool:
    if ENVIRONMENT_MARKER.search(logs):
        return True
    return any(ENVIRONMENT_ERROR.search(line) and not SOURCE_ECHO.match(line)
               for line in logs.splitlines())


def answer_failure(logs: str) -> str:
    """Name the answer failure of a test that ended without PASS or FAIL."""
    return "compile" if COMPILE_ERROR.search(logs) else "incomplete"


def installed_source(repo: Path, original: str, module: str, candidate: str) -> str:
    spec = importlib.util.spec_from_file_location(
        "veer_evaluate_candidate", repo / "cpus/veer_el2/_shared/evaluate_candidate.py")
    installer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(installer)
    return installer.replace_module(original, module, candidate)


def main() -> int:
    args = parse_args()
    checkout = args.checkout.resolve()
    repo = args.repo.resolve()
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)

    problem_dir = find_problem_dir(repo, args.problem)
    definition = yaml.safe_load((problem_dir / "problem.yaml").read_text(encoding="utf-8"))
    target = definition["target"]
    module = target["module"]
    rtl_relative = target["file"]

    recipe = json.loads((problem_dir / "TEST_RECIPE.json").read_text(encoding="utf-8"))
    run_command = recipe.get("evaluation_command") or recipe.get("run")
    if not run_command and recipe.get("tests"):
        run_command = "bash evaluate_all.sh"
    elif not run_command:
        run_command = "bash ../_shared/run_fixed_test.sh"
    kind, expected = load_expected(problem_dir, recipe)

    env_overrides = dict(recipe.get("run_env") or {})
    if kind == "matched":
        env_overrides["CPU_EVAL_EXPECTED_MATCHED"] = expected
    elif kind == "mcycle":
        env_overrides["CPU_EVAL_EXPECTED_MCYCLE_HEX"] = expected
    env_overrides["CPU_EVAL_RESULTS_DIR"] = str(results / "run")

    test = recipe.get("test") or {}
    test_path = test.get("path") if isinstance(test, dict) else None

    run_parts = shlex.split(run_command)
    while run_parts and "=" in run_parts[0]:
        name, value = run_parts.pop(0).split("=", 1)
        env_overrides[name] = value
    if len(run_parts) != 2 or run_parts[0] != "bash":
        raise ValueError(f"unsupported evaluator command: {run_command}")
    script_relative = run_parts[1]
    script_absolute = (problem_dir / script_relative).resolve()
    command = [
        sys.executable,
        str(repo / "cpus/veer_el2/_shared/evaluate_candidate.py"),
        "--cpu-root", str(checkout),
        "--module", module,
        "--candidate", str(args.candidate.resolve()),
        "--source", str(checkout / rtl_relative),
        "--lock-held",
        "--command", "bash", str(script_absolute),
    ]
    env = evaluation_environment(env_overrides)
    try:
        submitted = args.candidate.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        submitted = None
    with ExitStack() as stack:
        acquire_resource_locks(stack, recipe)
        lock = stack.enter_context((checkout / ".cpu_eval.lock").open("a+"))
        fcntl.flock(lock, fcntl.LOCK_EX)
        verify_post_generation_artifacts(checkout, recipe)
        original_source = (checkout / rtl_relative).read_bytes()
        expected_source = (installed_source(repo, original_source.decode("utf-8"), module, submitted)
                           if submitted is not None else None)
        stack.callback((checkout / rtl_relative).write_bytes, original_source)
        stack.enter_context(preserve_post_generation_artifacts(checkout, recipe))
        if test_path and str(test_path).endswith((".s", ".S")):
            source_test = problem_dir / str(test_path)
            destination_test = checkout / "testbench/asm" / source_test.name
            destination_test.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source_test, destination_test)
        stage_checkout_files(checkout, problem_dir, recipe)
        timed_out = False
        if submitted is None:
            returncode, stdout, stderr = None, "", "submission is not UTF-8 text\n"
        else:
            process = subprocess.Popen(command, cwd=checkout, env=env, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       start_new_session=True)
            try:
                stdout, stderr = process.communicate(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                stop_evaluator_group(process)
                stdout, stderr = process.communicate()
            finally:
                stop_evaluator_group(process)
            returncode = process.returncode
        installed = (checkout / rtl_relative).read_text(encoding="utf-8", errors="replace")
    reason = None
    if submitted is None:
        verdict, reason = 3, "submission is not UTF-8 text"
    elif timed_out:
        verdict, reason = 2, f"wall-clock limit of {args.timeout} seconds"
    elif installed != expected_source:
        verdict, reason = 2, "installed target differs from the submission"
    elif returncode < 0:
        verdict, reason = 2, f"evaluator stopped by signal {-returncode}"
    elif returncode == 0:
        verdict = 0
    else:
        logs = evaluation_logs(stdout, stderr, results / "run")
        if environment_failure(logs):
            verdict, reason = 2, "evaluator, fixed input, tool or resource failure"
        elif returncode == 1:
            verdict = 1
        else:
            failure = answer_failure(logs)
            verdict = 3 if failure == "compile" else 4
            reason = ("submitted source did not build" if failure == "compile"
                      else "test ended without a PASS or FAIL result")
    (results / "stdout.log").write_text(stdout, encoding="utf-8")
    (results / "stderr.log").write_text(stderr, encoding="utf-8")
    (results / "command.json").write_text(json.dumps(command, indent=2) + "\n", encoding="utf-8")
    (results / "execution.json").write_text(json.dumps({
        "timed_out": timed_out, "process_returncode": returncode, "returncode": verdict,
        "answer_failure": {3: "compile", 4: "incomplete"}.get(verdict), "reason": reason,
    }, indent=2) + "\n")
    (results / "expected.json").write_text(
        json.dumps({"kind": kind, "expected": expected}, indent=2) + "\n", encoding="utf-8"
    )
    return verdict


def cli() -> int:
    try:
        return main()
    except Exception:
        traceback.print_exc()
        return 2


if __name__ == "__main__":
    raise SystemExit(cli())
