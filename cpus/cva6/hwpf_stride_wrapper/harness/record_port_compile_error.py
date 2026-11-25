"""Translate a scoped wrapper port compile receipt into native compile evidence."""

from hashlib import sha256
import json
import os
from pathlib import Path
import sys
from tempfile import mkdtemp


MODULE = "hwpf_stride_wrapper"
FAILED = "FAIL_CANDIDATE_COMPILE: compiler error identifies candidate.sv"


def record(candidate, lines, log_root):
    if len(lines) != 2 or lines[0] != FAILED or not lines[1].startswith("PORT_RESULT="):
        raise ValueError("port output is not a single candidate compile receipt")
    source = Path(lines[1].removeprefix("PORT_RESULT="))
    if source.is_symlink() or source.resolve().parent != log_root.resolve() or not source.name.startswith(MODULE + "-ports-"):
        raise ValueError("port receipt is outside the wrapper log root")
    if {path.name for path in source.iterdir()} != {"build.log", "result.json", "runtime.log", "exit-code.txt"}:
        raise ValueError("port receipt paths differ")
    result = json.loads((source / "result.json").read_bytes())
    recipe = json.loads((Path(__file__).resolve().parent.parent / "TEST_RECIPE.json").read_bytes())
    candidate_digest = sha256(candidate.read_bytes()).hexdigest()
    if (result["module"] != MODULE or result["candidate_sha256"] != candidate_digest
            or result["input_sha256"]["candidate.sv"] != candidate_digest
            or result["input_sha256"]["stride_ports_tb.sv"] != recipe["port_testbench_sha256"]
            or result["cpu_revision"] != recipe["cpu_revision"]
            or result["hpdcache_revision"] != recipe["source_submodule_revision"]
            or result["exit_code"] != 1 or type(result["build_exit_code"]) is not int
            or result["build_exit_code"] <= 0 or result["build_exit_code"] in (124, 137, 143)
            or "runtime_exit_code" in result or (source / "exit-code.txt").read_bytes().strip() != b"1"
            or (source / "runtime.log").read_text().strip() != FAILED):
        raise ValueError("port receipt does not identify the submitted build failure")
    build = (source / "build.log").read_bytes()
    if not build:
        raise ValueError("port compiler output is missing")
    parent = log_root / MODULE
    parent.mkdir(exist_ok=True)
    target = Path(mkdtemp(prefix="ports-", dir=parent))
    (target / "build.log").write_bytes(build)
    (target / "candidate-compile-error.txt").write_bytes(build)
    (target / "exit-code.txt").write_text("1\n")
    for name in ("build.log", "result.json", "runtime.log", "exit-code.txt"):
        (source / name).unlink()
    source.rmdir()
    print(FAILED)
    print("PORT_RESULT=" + str(target))


if __name__ == "__main__":
    try:
        record(Path(sys.argv[1]), sys.stdin.read().splitlines(), Path(os.environ["CPU_EVAL_LOG_ROOT"]))
    except (KeyError, OSError, ValueError) as error:
        print("INVALID: " + str(error), file=sys.stderr)
        sys.exit(2)
