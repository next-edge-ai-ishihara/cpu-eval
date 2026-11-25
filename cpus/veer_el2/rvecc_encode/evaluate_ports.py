#!/usr/bin/env python3

import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time


MASKS = (0x56AAAD5B, 0x9B33366D, 0xE3C3C78E, 0x03FC07F0, 0x03FFF800, 0xFC000000)
EVALUATION_TIMEOUT_SECONDS = 900
STOP_TIMEOUT_SECONDS = 0.15


def child_subreaper(enabled=None):
    library = ctypes.CDLL(None, use_errno=True)
    previous = ctypes.c_int()
    if library.prctl(37, ctypes.byref(previous), 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'cannot read child subreaper setting')
    if enabled is not None and library.prctl(36, int(enabled), 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'cannot set child subreaper setting')
    return previous.value


def stop_group(process):
    deadline = time.monotonic() + STOP_TIMEOUT_SECONDS
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=max(0, deadline - time.monotonic()))
    while True:
        try:
            while time.monotonic() < deadline and os.waitpid(-process.pid, os.WNOHANG)[0]:
                pass
        except ChildProcessError:
            pass
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            return
        if time.monotonic() >= deadline:
            raise RuntimeError('owned child process group did not stop within the cleanup limit')
        time.sleep(min(0.01, max(0, deadline - time.monotonic())))


def execute(command, log, seconds, env=None):
    process = None
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
    previous_subreaper = None
    try:
        previous_subreaper = child_subreaper(True)
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   env=env, start_new_session=True,
                                   preexec_fn=lambda: signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask))
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        return subprocess.CompletedProcess(command, process.wait(timeout=seconds))
    finally:
        try:
            if process is not None:
                stop_group(process)
        finally:
            try:
                if previous_subreaper is not None:
                    child_subreaper(previous_subreaper)
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)


def expected(data):
    syndrome = sum(((data & mask).bit_count() & 1) << bit for bit, mask in enumerate(MASKS))
    return syndrome | (((data.bit_count() + syndrome.bit_count()) & 1) << 6)


def vectors():
    values = [0, 0xFFFFFFFF]
    values += [1 << bit for bit in range(32)]
    values += [0xFFFFFFFF ^ (1 << bit) for bit in range(32)]
    values += [(1 << first) | (1 << second) for first in range(32) for second in range(first + 1, 32)]
    values += [0xAAAAAAAA, 0x55555555, 0xF0F0F0F0, 0x0F0F0F0F, 0x12345678, 0x87654321, 0x5A3C69F0, 0xDEADBEEF]
    return values


def main():
    deadline = time.monotonic() + EVALUATION_TIMEOUT_SECONDS
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_file():
        print("CPU_EVAL_INVALID: supply the candidate module or installed beh_lib.sv", file=sys.stderr)
        return 2
    source_path = Path(sys.argv[1]).resolve()
    source = source_path.read_text()
    lexical = re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"',
                     lambda token: re.sub(r'[^\n]', ' ', token.group(0)),
                     source, flags=re.DOTALL)
    match = re.search(r"(?ms)\bmodule\s+rvecc_encode\b.*?\bendmodule\b", lexical)
    if match is None:
        print("FAIL: rvecc_encode definition is unavailable in the installed source", file=sys.stderr)
        return 2
    root = Path(os.environ.get("CPU_EVAL_RESULTS_DIR", tempfile.gettempdir()))
    root.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="ecc-ports-", dir=root))
    print(f"ECC port-test logs: {run}", flush=True)
    candidate = run / "candidate.sv"
    candidate.write_text(source[match.start():match.end()] + "\n")
    cases = vectors()
    (run / "expectations.json").write_text(json.dumps([{"index": i, "din": value, "ecc": expected(value)} for i, value in enumerate(cases)], indent=2) + "\n")
    lines = ["module tb;", "logic [31:0] din; wire [6:0] ecc;", "rvecc_encode dut(.din(din), .ecc_out(ecc));", "initial begin"]
    for index, value in enumerate(cases):
        lines += [f"din=32'h{value:08x}; #1;", f'$display("ECC_OBS {index} %08h %02h",din,ecc);']
    lines += [f'$display("ECC_PORT_COMPLETE checks={len(cases)}");', "$finish; end", "endmodule"]
    test = run / "tb.sv"
    test.write_text("\n".join(lines) + "\n")
    (run / "inputs.json").write_text(json.dumps({"source": str(Path(sys.argv[1]).resolve()), "candidate_sha256": hashlib.sha256(candidate.read_bytes()).hexdigest(), "test_sha256": hashlib.sha256(test.read_bytes()).hexdigest()}, indent=2) + "\n")
    tool = os.environ.get("VERILATOR", "verilator")
    with tempfile.TemporaryDirectory(prefix="ecc-ports-build-") as directory:
        work = Path(directory)
        build_env = os.environ.copy()
        build_env["CCACHE_DIR"] = str(work / "ccache")
        command = [tool, "--binary", "--timing", "--assert", "-j", "2", "--top-module", "tb", "--Mdir", str(work / "obj"), "-Wno-fatal", str(candidate), str(test)]
        (run / "command.json").write_text(json.dumps(command, indent=2) + "\n")
        phase = "build"
        try:
            with (run / "build.log").open("w") as log:
                build = execute(command, log, max(0, deadline - time.monotonic()), build_env)
            if build.returncode:
                line_offset = source.count("\n", 0, match.start())
                build_diagnostics = (run / "build.log").read_text(errors="replace")
                # The submission grader attributes diagnostics in the installed
                # source, while Verilator sees only the extracted definition.
                location = re.compile(
                    rf"(?m)^(%(?:Error|Warning)[^:\n]*: ){re.escape(str(candidate))}:(\d+)(?=:)"
                )
                print(location.sub(
                    lambda diagnostic: f"{diagnostic[1]}{source_path}:{int(diagnostic[2]) + line_offset}",
                    build_diagnostics,
                ), end="", file=sys.stderr)
                (run / "result.json").write_text(json.dumps({"exit": build.returncode, "returncode": 2, "phase": phase, "accepted": False, "classification": "FAIL_CANDIDATE_COMPILE"}, indent=2) + "\n")
                return 2
            phase = "runtime"
            with (run / "runtime.log").open("w") as log:
                execution = execute([str(work / "obj/Vtb")], log, max(0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            (run / "result.json").write_text(json.dumps({"exit": 2, "phase": phase, "accepted": False, "timed_out": True}, indent=2) + "\n")
            print(f"CPU_EVAL_INVALID: ECC port-test {phase} timed out", file=sys.stderr)
            return 2
        except SystemExit:
            (run / "result.json").write_text(json.dumps({"exit": 2, "phase": phase, "accepted": False, "interrupted": True}, indent=2) + "\n")
            raise
        except RuntimeError as error:
            (run / "result.json").write_text(json.dumps({"exit": 2, "phase": phase, "accepted": False, "cleanup_error": str(error)}, indent=2) + "\n")
            print(f"CPU_EVAL_INVALID: {error}", file=sys.stderr)
            return 2
    text = (run / "runtime.log").read_text()
    rows = re.findall(r"(?m)^ECC_OBS (\d+) ([0-9a-fA-F]{8}) ([0-9a-fA-F]{2})$", text)
    errors = sum((int(i) != index or int(data, 16) != value or int(ecc, 16) != expected(value)) for index, ((i, data, ecc), value) in enumerate(zip(rows, cases)))
    complete = f"ECC_PORT_COMPLETE checks={len(cases)}" in text.splitlines()
    success = execution.returncode == 0 and len(rows) == len(cases) and not errors and complete
    (run / "result.json").write_text(json.dumps({"exit": execution.returncode, "observations": len(rows), "expected_count": len(cases), "errors": errors, "complete": complete, "accepted": success}, indent=2) + "\n")
    print(f"{'PASS' if success else 'FAIL'}: ECC ports observations={len(rows)} expected={len(cases)} errors={errors}")
    return 0 if success else 1


if __name__ == "__main__":
    def terminate(signum, frame):
        print("CPU_EVAL_INVALID: interrupted by signal " + str(signum), flush=True)
        raise SystemExit(2)
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"CPU_EVAL_INVALID: {error}", file=sys.stderr)
        raise SystemExit(2)
