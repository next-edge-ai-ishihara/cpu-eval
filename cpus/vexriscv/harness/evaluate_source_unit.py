#!/usr/bin/env python3
"""Evaluate one VexRiscv source-level module in the selected CPU configuration."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from patch_profiles import PROFILE_PATCHES, sha256, validate_recorded_patches

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.evaluation.scala_compile_diagnostics import integrated_region


VEXRISCV_REVISION = "c4b2a55b22f46afb760446cd69f3ca7c36eef778"
SPINALHDL_REVISION = "95a5e6c65c54acfc4707c8fe6ef8b5d297cfcbde"


def revision(checkout: Path) -> str:
    return subprocess.check_output(
        ["git", "-c", f"safe.directory={checkout}", "-C", str(checkout), "rev-parse", "HEAD"],
        text=True,
    ).strip()


def profile_for(unit: dict[str, str]) -> str:
    if unit["repository"] == "spinalhdl":
        return "spinal"
    return "debug" if unit["id"] == "debug_plugin" else "vex-standard"


def patch_state(checkout: Path, patch: Path) -> str:
    command = ["git", "-c", f"safe.directory={checkout}", "-C", str(checkout), "apply"]
    quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if subprocess.run(command + ["--reverse", "--check", str(patch)], **quiet).returncode == 0:
        return "applied"
    if subprocess.run(command + ["--check", str(patch)], **quiet).returncode == 0:
        return "absent"
    return "indeterminate"


def validate_patch_profile(checkout: Path, repo: Path, profile: str) -> None:
    required = set(PROFILE_PATCHES[profile])
    patch_root = repo / "cpus/vexriscv/_shared/test-patches"
    patch_hashes = validate_recorded_patches(repo)
    failures = []
    for name in patch_hashes:
        patch = patch_root / name
        state = patch_state(checkout, patch)
        if name in required and state != "applied":
            failures.append(f"required patch is not applied: {name}")
        elif name not in required and state != "absent":
            failures.append(f"disallowed patch is not cleanly absent: {name}")
    if failures:
        raise ValueError(f"checkout does not match patch profile {profile}: " + "; ".join(failures))


# The fixed checkout passes with the reference class, so after only that class is replaced a
# failure is the answer's unless the log shows a tool, resource or host failure.
ENVIRONMENT_ERROR = re.compile(
    r"command not found|no java installation|unresolved dependenc|error downloading|failed to download|"
    r"resolutionerror|server access error|out of memory|outofmemoryerror|cannot allocate memory|"
    r"virtual memory exhausted|std::bad_alloc|no space left on device|disk quota exceeded|"
    r"input/output error|permission denied|broken pipe|^DebugPlugin(?:Test connect| bind): ", re.I | re.M)
KILLED = re.compile(r"\bKilled\b")
WALL_CLOCK_CODES = {124, 137, 143, -9, -15}
STOP_MESSAGES = {"timeout", "Liveness step failure", "Liveness interrupt failure"}


def environment_failure(output: str) -> bool:
    return ENVIRONMENT_ERROR.search(output) is not None or KILLED.search(output) is not None


def classify(output: str, code: int) -> str:
    if code == 0 and re.search(r"^REGRESSION SUCCESS \d+/\d+$", output, re.M):
        return "PASS"
    if code in WALL_CLOCK_CODES:
        return "INVALID_TIMEOUT"
    if environment_failure(output):
        return "INVALID_ENVIRONMENT"
    failure_count = re.search(r"^REGRESSION FAILURE (\d+)/\d+$", output, re.M)
    if failure_count:
        rows = output.splitlines()
        stops = [i for i, line in enumerate(rows) if line.startswith("FAIL ") and " at PC=" in line]
        if len(stops) == int(failure_count[1]) and stops and all(
                i > 0 and rows[i - 1] in STOP_MESSAGES for i in stops):
            return "FAIL_PROGRAM_LIVENESS"
        return "FAIL_TRACE_MISMATCH"
    if not re.search(r"^START TEST ", output, re.M):
        # sbt compiles the main and test sources before the regression prints START TEST.
        if re.search(r"^\[info\] compiling \d+ Scala sources? to \S+/target/scala-[\d.]+/(?:test-)?classes",
                     output, re.M):
            return "FAIL_CANDIDATE_COMPILE"
        return "INVALID_ENVIRONMENT"
    if not re.search(r"^make run REGRESSION_PATH=", output, re.M):
        return "FAIL_ELABORATION"
    if not re.search(r"^\./obj_dir/VVexRiscv$", output, re.M):
        return "FAIL_CANDIDATE_COMPILE"
    return "FAIL_INCOMPLETE_EXECUTION"


def regression_configuration_mismatch(output: str, verdict: str, expected_start: str) -> bool:
    starts = re.findall(r"^START TEST .*$", output, re.M)
    return any(line != expected_start for line in starts) or (verdict == "PASS" and not starts)


def check_port_test(output: str, code: int, verdict: str, main_class: str, marker: str) -> str:
    """Grade the directed port test that sbt runs after the CPU regression."""
    if verdict in {"INVALID_TIMEOUT", "INVALID_ENVIRONMENT"}:
        return verdict
    cpu_log, entered, port_log = output.partition(f"[info] running (fork) vexriscv.{main_class}")
    if not (entered and re.search(r"^REGRESSION SUCCESS \d+/\d+$", cpu_log, re.M)):
        # sbt runs the port test only after the CPU regression passes.
        return "INVALID_PORT_TEST_MISSING" if verdict == "PASS" else verdict
    if code == 0 and f"[info] {marker}_PASS" in port_log.splitlines():
        return "PASS"
    if re.search(rf"^\[info\] {marker}_MISMATCH .* actual=\d+ expected=\d+$", port_log, re.M):
        return "FAIL_DIRECTED_PUBLIC_OUTPUT_MISMATCH"
    if re.search(r"Error detected in phase|^\[error\]\s+at spinal\.lib\.StreamFifo(?:LowLatency)?\.<init>\(",
                 port_log, re.M):
        return "FAIL_ELABORATION"
    return "FAIL_INCOMPLETE_EXECUTION"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", required=True, type=Path)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--problem", required=True)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--sbt", required=True, type=Path)
    parser.add_argument("--spinal-checkout", type=Path)
    parser.add_argument("--timeout", type=int, default=3600)
    args = parser.parse_args()

    checkout = args.checkout.resolve()
    repo = args.repo.resolve()
    candidate = args.candidate.resolve()
    results = args.results.resolve()
    results.mkdir(parents=True, exist_ok=True)

    if revision(checkout) != VEXRISCV_REVISION:
        parser.error(f"VexRiscv checkout must be at {VEXRISCV_REVISION}")
    population = json.loads((repo / "cpus/vexriscv/SOURCE_UNITS.json").read_text())
    matches = [unit for unit in population["units"] if unit["id"] == args.problem]
    if len(matches) != 1:
        parser.error(f"unknown problem: {args.problem}")
    unit = matches[0]
    profile = profile_for(unit)
    try:
        validate_patch_profile(checkout, repo, profile)
    except ValueError as error:
        parser.error(str(error))

    if unit["repository"] == "vexriscv":
        source = checkout / unit["path"]
    else:
        if args.spinal_checkout is None:
            parser.error("--spinal-checkout is required for a SpinalHDL source module")
        spinal_checkout = args.spinal_checkout.resolve()
        if revision(spinal_checkout) != SPINALHDL_REVISION:
            parser.error(f"SpinalHDL checkout must be at {SPINALHDL_REVISION}")
        upstream_source = spinal_checkout / unit["path"]
        source = checkout / "src/main/scala/spinal/lib/Stream.scala"
        if not upstream_source.is_file() or not source.is_file():
            parser.error("the pinned SpinalHDL source or its recorded integration copy is missing")
        if upstream_source.read_bytes() != source.read_bytes():
            parser.error("the SpinalHDL integration copy differs from the pinned upstream source")

    if not source.is_file() or not candidate.is_file() or not args.sbt.is_file():
        parser.error("source, candidate, or sbt executable is missing")

    replacer = repo / "cpus/vexriscv/harness/replace_scala_definition.py"
    original = source.read_bytes()
    original_hash = sha256(source)
    integrated = results / "integrated-source.scala"
    candidate_copy = results / "candidate.scala"
    fifo_test = (checkout / "src/test/scala" / f"CpuEvalFifoPortTest_{os.getpid()}.scala"
                 if args.problem == "stream_fifo_low_latency" else None)
    test_recipe = json.loads((repo / "cpus/vexriscv/TEST_RECIPE.json").read_bytes())
    configuration_record = repo / "cpus/vexriscv" / test_recipe["configuration_record"]["path"]
    if sha256(configuration_record) != test_recipe["configuration_record"]["sha256"]:
        parser.error("regression configuration record does not match TEST_RECIPE.json")
    expected_start = next(line for line in configuration_record.read_text(encoding="utf-8").splitlines()
                          if line.startswith("START TEST "))
    if args.problem == "stream_fifo":
        stream_fifo_recipe = test_recipe["additional_tests"][args.problem]
        stream_fifo_source = repo / "cpus/vexriscv" / stream_fifo_recipe["source"]
        if sha256(stream_fifo_source) != stream_fifo_recipe["sha256"]:
            parser.error("StreamFifo port test does not match TEST_RECIPE.json")
        stream_fifo_test = checkout / "src/test/scala" / f"CpuEvalStreamFifoPortTest_{os.getpid()}.scala"
    else:
        stream_fifo_test = None
    shutil.copyfile(candidate, candidate_copy)
    started = time.monotonic()

    env = os.environ.copy()
    configuration = test_recipe["configuration"]
    env["PATH"] = f"{args.sbt.parent}:/usr/bin:{env.get('PATH', '')}"
    env.update(configuration)

    try:
        # Remove compiled classes and simulation workspaces so an earlier candidate is never reused.
        for generated in (checkout / "target", checkout / "simWorkspace"):
            if generated.exists():
                shutil.rmtree(generated)
        replace_command = [
            "python3", str(replacer), "--base", str(source), "--candidate", str(candidate),
            "--class-name", unit["class"], "--output", str(integrated),
        ]
        completed = subprocess.run(
            replace_command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        )
        if completed.returncode == 0:
            source.write_bytes(integrated.read_bytes())
            command = ["timeout", str(args.timeout), str(args.sbt), "testOnly vexriscv.TestIndividualFeatures"]
            if fifo_test is not None:
                shutil.copyfile(repo / "cpus/vexriscv/harness/FifoPortTest.scala", fifo_test)
                command.append("Test / runMain vexriscv.FifoPortTest")
            if stream_fifo_test is not None:
                shutil.copyfile(stream_fifo_source, stream_fifo_test)
                command.append(stream_fifo_recipe["sbt_command"])
            lock_path = Path(
                env.get("CPU_EVAL_VEX_EXECUTION_LOCK", "/tmp/cpu-eval-vex-execution.lock")
            )
            lock_path.parent.mkdir(parents=True, exist_ok=True)
            with lock_path.open("w") as lock:
                if profile != "spinal":
                    fcntl.flock(lock, fcntl.LOCK_EX)
                completed = subprocess.run(
                    command, cwd=checkout, env=env, text=True,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                )
            region = integrated_region(source, original.decode(), integrated.read_text(), unit["class"])
            region["class_name"] = unit["class"]
            (results / "candidate-source.json").write_text(json.dumps(region, indent=2) + "\n")
            verdict = classify(completed.stdout, completed.returncode)
            if regression_configuration_mismatch(completed.stdout, verdict, expected_start):
                verdict = "INVALID_CONFIGURATION_MISMATCH"
            elif stream_fifo_test is not None:
                verdict = check_port_test(completed.stdout, completed.returncode, verdict,
                                          "StreamFifoPortTest", "STREAM_FIFO_PORT")
            elif fifo_test is not None:
                verdict = check_port_test(completed.stdout, completed.returncode, verdict,
                                          "FifoPortTest", "FIFO_PORT")
            if source.read_bytes() != integrated.read_bytes():
                verdict = "INVALID_TARGET_MISMATCH"
        else:
            command = replace_command
            verdict = ("FAIL_CANDIDATE_DEFINITION" if completed.returncode == 3
                       else "INVALID_CANDIDATE_DEFINITION")
        raw_log = results / "run.log"
        raw_log.write_text(completed.stdout, encoding="utf-8")
        record = {
            "schema_version": 1,
            "problem": args.problem,
            "candidate_sha256": sha256(candidate_copy),
            "configuration": {"seed": int(configuration["VEXRISCV_REGRESSION_SEED"]),
                              "test_id": int(configuration["VEXRISCV_REGRESSION_TEST_ID"])},
            "patch_profile": profile,
            "command": command,
            "exit_code": completed.returncode,
            "verdict": verdict,
            "wall_seconds": round(time.monotonic() - started, 3),
            "raw_log": "run.log",
            "raw_log_sha256": sha256(raw_log),
        }
        (results / "verdict.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    finally:
        if fifo_test is not None:
            fifo_test.unlink(missing_ok=True)
        if stream_fifo_test is not None:
            stream_fifo_test.unlink(missing_ok=True)
        source.write_bytes(original)
        if sha256(source) != original_hash:
            raise RuntimeError(f"failed to restore {source}")

    if verdict == "PASS":
        return 0
    return 1 if verdict.startswith("FAIL_") else 2


if __name__ == "__main__":
    raise SystemExit(main())
