#!/usr/bin/env python3
"""Evaluate submitted HDL in a grading container on a compute node."""

import argparse
import atexit
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import traceback
from typing import Mapping


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def container_environment(environment: Mapping[str, str]) -> dict[str, str]:
    result = {name: value for name, value in environment.items()
              if not name.startswith(('SINGULARITYENV_', 'APPTAINERENV_'))}
    for name, value in environment.items():
        if name.lower() in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy'):
            result['SINGULARITYENV_' + name] = value
    return result


def work_root_from_environment(environment: Mapping[str, str], fallback: Path) -> Path:
    return Path(environment.get('TMPDIR') or fallback)


def verify_writable_root(root: Path, job_id: str) -> None:
    probe = root / f".cpu-eval-write-probe-{job_id}"
    try:
        probe.mkdir(parents=True)
        block = probe / "block"
        with block.open("wb") as stream:
            stream.write(b"CPU-Eval evaluation write probe\n")
            stream.flush()
            os.fsync(stream.fileno())
    finally:
        shutil.rmtree(probe, ignore_errors=True)


def write_json(path: Path, value: object) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def verify_bundle(root: Path) -> None:
    checksum_path = root / "bundle-files.sha256"
    for line in checksum_path.read_text(encoding="utf-8").splitlines():
        expected, relative = line.split("  ", 1)
        path = root / relative
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"evaluation bundle hash mismatch: {relative}")


def submission_root(bundle: dict) -> str:
    root = f"/mnt/submissions/{bundle['cpu']}"
    return root


def invocation_timeout_sec(bundle: dict) -> int:
    try:
        timeout = bundle["adapter"]["invocation_timeout_sec"]
    except KeyError as error:
        raise ValueError(
            "grading bundle must explicitly record adapter.invocation_timeout_sec"
        ) from error
    if not isinstance(timeout, int) or isinstance(timeout, bool) or timeout < 1:
        raise ValueError("adapter.invocation_timeout_sec must be a positive integer")
    return timeout


def collect_verdicts(result: Path, cpu: str, problems: list, samples: int) -> Path:
    verdicts = result / "evaluation-verdicts.tsv"
    errors = []
    with verdicts.open("w", encoding="utf-8", newline="") as stream:
        fields = ["problem", "sample_index", "verdict", "evidence", "evidence_sha256"]
        writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for problem in problems:
            for sample in range(samples):
                directory = result / "driver" / f"{problem}__sample-{sample:02d}"
                paths = {
                    "boom": directory / "evaluator" / "evaluation-verdict.json",
                    "cva6": directory / "evaluator" / "verdict.json",
                    "ibex": directory / "evaluator" / "verdict.json",
                    "rift2core": directory / "verdict.json",
                    "veer_el2": directory / "evaluator" / "verdict.json",
                    "vexriscv": directory / "evaluator" / "verdict.json",
                }
                evidence = paths.get(cpu)
                if evidence is None:
                    raise ValueError(f"unsupported verdict adapter: {cpu}")
                evidence_sha256 = ''
                try:
                    record = json.loads(evidence.read_text(encoding="utf-8"))
                    verdict = record['verdict']
                    if not isinstance(verdict, str) or not verdict:
                        raise ValueError('verdict must be a nonempty string')
                    evidence_sha256 = sha256(evidence)
                except FileNotFoundError:
                    verdict = 'INVALID_VERDICT_MISSING'
                    errors.append(f'missing evaluator verdict: {evidence}')
                except (OSError, ValueError, KeyError, TypeError) as error:
                    verdict = 'INVALID_VERDICT_UNREADABLE'
                    errors.append(f'invalid evaluator verdict {evidence}: {error}')
                writer.writerow({
                    "problem": problem,
                    "sample_index": sample,
                    "verdict": verdict,
                    "evidence": str(evidence.relative_to(result)),
                    "evidence_sha256": evidence_sha256,
                })
    error_log = result / 'verdict-collection.error.log'
    if errors:
        error_log.write_text('\n'.join(errors) + '\n', encoding='utf-8')
    else:
        error_log.unlink(missing_ok=True)
    return verdicts


def build_jobs(bundle: dict) -> int:
    limit = bundle["adapter"]["build_jobs"]
    if type(limit) is not int or limit < 1:
        raise ValueError("adapter.build_jobs must be a positive integer")
    return min(limit, len(os.sched_getaffinity(0)))


def run_chunk(args) -> int:
    bundle_manifest = args.bundle.resolve()
    root = bundle_manifest.parent
    archive = root / 'archives' / f'chunk-{args.chunk:03d}.tar.gz'
    if archive.exists():
        raise FileExistsError(f'evaluation result already exists: {archive}')
    verify_bundle(root)
    bundle = json.loads(bundle_manifest.read_text(encoding="utf-8"))
    candidate_timeout = (invocation_timeout_sec(bundle)
                         if bundle['cpu'] in ('boom', 'cva6', 'rift2core') else None)
    chunks = {int(item["index"]): item for item in bundle["chunks"]}
    if args.chunk not in chunks:
        raise ValueError(f"chunk index is outside the bundle: {args.chunk}")
    chunk = chunks[args.chunk]
    chunk_path = root / chunk["path"]
    if sha256(chunk_path) != chunk["sha256"]:
        raise ValueError(f"chunk hash mismatch: {chunk_path}")
    image = args.image.resolve() if args.image else Path.home() / "cpu-eval-grading-images" / bundle["image"]
    if sha256(image) != bundle["image_sha256"]:
        raise ValueError(f"grading image hash mismatch: {image}")

    assets = root / "assets"
    if "external_assets" in bundle:
        external = bundle["external_assets"]
        assets = Path(external["path"])
        for item in external["files"]:
            path = assets / item["path"]
            if not path.is_file() or sha256(path) != item["sha256"]:
                raise ValueError(f"shared grading asset hash mismatch: {path}")

    result = root / "results" / f"chunk-{args.chunk:03d}"
    driver_output = result / "driver"
    work_root = args.work_root.resolve() if args.work_root else work_root_from_environment(
        os.environ,
        root / "work",
    )
    verify_writable_root(work_root, f"{args.job_id}-{args.chunk:03d}")
    scratch_parent = work_root / 'cpu-eval-evaluation'
    scratch_parent.mkdir(parents=True, exist_ok=True)
    eval_root = Path(tempfile.mkdtemp(prefix=f'{args.job_id}-{args.chunk:03d}-', dir=scratch_parent))
    result.mkdir(parents=True, exist_ok=True)
    (result / 'live-runs').mkdir(exist_ok=True)
    (eval_root / 'runs').symlink_to('/mnt/output/live-runs', target_is_directory=True)
    atexit.register(lambda: shutil.rmtree(eval_root, ignore_errors=True))
    started = now()
    common = [
        "singularity", "exec", "--cleanenv",
        "--env", "PYTHONPATH=/mnt/repo",
        "--bind", f"{root / 'repo'}:/mnt/repo:ro",
        "--bind", f"{root / 'submissions'}:/mnt/submissions:ro",
        "--bind", f"{root / 'chunks'}:/mnt/chunks:ro",
        "--bind", f"{result}:/mnt/output",
        "--bind", f"{eval_root}:/mnt/eval-root",
        str(image),
    ]
    driver = [
        "python3", f"/mnt/repo/{bundle['adapter']['driver']}",
        "--problems", f"/mnt/chunks/{Path(chunk['path']).name}",
        "--samples", str(bundle["sample_count"]),
        "--submissions", submission_root(bundle),
        "--output", "/mnt/output/driver",
        "--repo", "/mnt/repo",
    ]
    if bundle["cpu"] == "cva6":
        common[2:2] = ['--env', f'NUM_JOBS={build_jobs(bundle)}']
        mutable_checkout = eval_root / "cva6"
        subprocess.run([
            "singularity", "exec", "--cleanenv",
            "--bind", f"{eval_root}:/mnt/eval-root",
            str(image),
            "cp", "-a", "/opt/cva6-pristine", "/mnt/eval-root/cva6",
        ], check=True, env=container_environment(os.environ))
        riscv = eval_root / "riscv"
        (riscv / "bin").mkdir(parents=True)
        (riscv / "include").mkdir()
        (riscv / "lib").mkdir()
        for tool in ("gcc", "objcopy", "nm"):
            (riscv / "bin" / f"riscv64-unknown-elf-{tool}").symlink_to(
                f"/usr/bin/riscv64-unknown-elf-{tool}"
            )
        driver.extend([
            "--checkout", "/mnt/eval-root/cva6",
            "--riscv-prefix", "/mnt/eval-root/riscv",
            "--cvxif-spike-prefix", "/opt/toolchain/spike-cvxif-all-operations",
            "--invocation-timeout-sec", str(candidate_timeout),
        ])
    elif bundle["cpu"] == "boom":
        mutable_checkout = eval_root / "chipyard"
        mutable_chisel = eval_root / "chisel"
        if not mutable_checkout.exists():
            subprocess.run([
                "singularity", "exec", "--cleanenv",
                "--bind", f"{eval_root}:/mnt/eval-root",
                str(image),
                "cp", "-a", "/opt/boom-pristine", "/mnt/eval-root/chipyard",
            ], check=True, env=container_environment(os.environ))
        if not mutable_chisel.exists():
            subprocess.run([
                "singularity", "exec", "--cleanenv",
                "--bind", f"{eval_root}:/mnt/eval-root",
                str(image),
                "cp", "-a", "/opt/boom-chisel-pristine", "/mnt/eval-root/chisel",
            ], check=True, env=container_environment(os.environ))
        ivy = eval_root / "ivy"
        if not ivy.exists():
            subprocess.run([
                "singularity", "exec", "--cleanenv",
                "--bind", f"{eval_root}:/mnt/eval-root",
                str(image),
                "cp", "-a", "--no-preserve=mode",
                "/opt/boom-ivy-pristine", "/mnt/eval-root/ivy",
            ], check=True, env=container_environment(os.environ))
        (eval_root / "ccache").mkdir(exist_ok=True)
        driver.extend([
            "--worktree", "/mnt/eval-root/chipyard",
            "--chisel-source", "/mnt/eval-root/chisel",
            "--ivy-home", "/mnt/eval-root/ivy",
            "--riscv-tools", "/opt/boom-riscv-tools",
            "--test-root", "/opt/boom-tests",
            "--ccache-dir", "/mnt/eval-root/ccache",
            "--build-jobs", str(build_jobs(bundle)),
            "--test-parallelism", str(bundle["adapter"].get("test_parallelism", 8)),
            "--invocation-timeout-sec", str(
                candidate_timeout
            ),
        ])
    elif bundle["cpu"] == "ibex":
        mutable_checkout = eval_root / "ibex"
        subprocess.run(["cp", "-a", str(assets / "ibex-source"), str(mutable_checkout)], check=True, env=container_environment(os.environ))
        common[2:2] = [
            "--bind", f"{assets}:/mnt/assets:ro",
            "--env", "LD_LIBRARY_PATH=/mnt/assets/spike-install/lib",
        ]
        driver.extend([
            "--ibex-checkout", "/mnt/eval-root/ibex",
            "--spike-install", "/mnt/assets/spike-install",
            "--program-root", "/mnt/assets/programs",
        ])
    elif bundle["cpu"] == "rift2core":
        (eval_root / "short-tests").mkdir()
        common[2:2] = ["--env", "SHORT_TEST_DIR=/mnt/eval-root/short-tests"]
        driver.extend([
            "--eval-root", "/mnt/eval-root",
            "--verilator-jobs", str(build_jobs(bundle)),
            "--test-timeout-sec", str(bundle["adapter"].get("test_timeout_sec", 180)),
            "--test-parallelism", str(bundle["adapter"].get("test_parallelism", 8)),
            "--timeout", str(candidate_timeout),
        ])
    elif bundle["cpu"] == "veer_el2":
        if len(chunk["problems"]) != 1:
            raise ValueError("VeeR EL2 evaluation requires one problem per chunk")
        common[2:2] = ["--bind", f"{assets}:/mnt/assets:ro"]
        checkout = eval_root / "veer-el2"
        subprocess.run([
            "singularity", "exec", "--cleanenv",
            "--bind", f"{root / 'repo'}:/mnt/repo:ro",
            "--bind", f"{assets}:/mnt/assets:ro",
            "--bind", f"{eval_root}:/mnt/eval-root",
            str(image),
            "python3", f"/mnt/repo/{bundle['adapter']['checkout_preparer']}",
            "--repo", "/mnt/repo",
            "--source", "/mnt/assets/veer-el2-source",
            "--generated-tests", "/mnt/assets/veer-generated-tests",
            "--problem", chunk["problems"][0],
            "--output", "/mnt/eval-root/veer-el2",
        ], check=True, env=container_environment(os.environ))
        (eval_root / "empty-venv/bin").mkdir(parents=True)
        driver.extend([
            "--checkout", "/mnt/eval-root/veer-el2",
            "--verilator-bin", "/opt/verilator-5.036/bin",
            "--spike-bin", "/opt/spike/bin",
            "--riscv-dv-venv", "/mnt/eval-root/empty-venv",
        ])
    elif bundle["cpu"] == "vexriscv":
        mutable_profiles = eval_root / "profiles"
        mutable_profiles.mkdir()
        for profile in ("spinal", "vex-standard", "debug"):
            subprocess.run(
                ["cp", "-a", str(assets / "profiles" / profile), str(mutable_profiles / profile)],
                check=True, env=container_environment(os.environ),
            )
        (eval_root / "home").mkdir()
        (eval_root / "coursier").mkdir()
        (eval_root / "sbt-repositories").write_text(
            "[repositories]\n"
            "local\n"
            "central: https://repo.maven.apache.org/maven2/\n"
            "central-mirror: https://maven-central.storage-download.googleapis.com/maven2/\n"
            "sbt-plugin-releases: https://scala.jfrog.io/artifactory/sbt-plugin-releases/, "
            "[organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)"
            "[revision]/[type]s/[artifact](-[classifier]).[ext]\n"
            "sonatype-public: https://oss.sonatype.org/content/repositories/public/\n",
            encoding="utf-8",
        )
        common[2:2] = [
            "--bind", f"{assets}:/mnt/assets:ro",
            "--env", "HOME=/mnt/eval-root/home",
            "--env", "COURSIER_CACHE=/mnt/eval-root/coursier",
            "--env", "VERILATOR_BIN=/usr/bin/verilator_bin",
            "--env", "JAVA_TOOL_OPTIONS=-Dsbt.override.build.repos=true "
            "-Dsbt.repository.config=/mnt/eval-root/sbt-repositories",
        ]
        driver.extend([
            "--evaluator-revision", "sha256:" + bundle["evaluation_files_sha256"],
            "--spinal-checkout", "/mnt/eval-root/profiles/spinal",
            "--vex-standard-checkout", "/mnt/eval-root/profiles/vex-standard",
            "--debug-checkout", "/mnt/eval-root/profiles/debug",
            "--sbt", "/opt/sbt/bin/sbt",
            "--java-home", "/usr/lib/jvm/java-17-openjdk-amd64",
            "--spinal-source-checkout", "/mnt/assets/spinalhdl-source",
        ])
    else:
        raise ValueError(f"unsupported evaluation adapter: {bundle['cpu']}")
    command = common + driver
    if (driver_output / "run.json").is_file():
        command.append("--resume")
    invocation = {
        "schema_version": 1,
        "evaluation_files_sha256": bundle["evaluation_files_sha256"],
        "cpu": bundle["cpu"],
        "chunk": args.chunk,
        "problems": chunk['problems'],
        "sample_count": bundle['sample_count'],
        "chunk_sha256": chunk["sha256"],
        "job_id": args.job_id,
        "image": str(image),
        "image_sha256": bundle["image_sha256"],
        "command": command,
        "started_at_utc": started,
    }
    write_json(result / "invocation.json", invocation)
    with (result / "runner.stdout.log").open('w', encoding='utf-8') as stdout, \
         (result / "runner.stderr.log").open('w', encoding='utf-8') as stderr:
        completed = subprocess.run(command, stdout=stdout, stderr=stderr,
                                   env=container_environment(os.environ))
    collection_status = 0
    try:
        collect_verdicts(result, bundle["cpu"], chunk["problems"], bundle["sample_count"])
        if (result / 'verdict-collection.error.log').is_file():
            collection_status = 2
    except (OSError, ValueError, KeyError):
        collection_status = 2
        (result / "verdict-collection.error.log").write_text(traceback.format_exc(), encoding="utf-8")
    invocation["finished_at_utc"] = now()
    invocation["exit_code"] = completed.returncode
    write_json(result / "invocation.json", invocation)
    archives = root / "archives"
    archives.mkdir(exist_ok=True)
    archive = archives / f"chunk-{args.chunk:03d}.tar.gz"
    temporary_archive = archive.with_suffix(".tar.gz.tmp")
    archive_command = [
        "tar", "-czf", str(temporary_archive),
        "-C", str(root), str(result.relative_to(root)),
    ]
    archived = subprocess.run(
        archive_command,
        universal_newlines=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if archived.returncode != 0:
        (result / "archive.stderr.log").write_text(archived.stderr, encoding="utf-8")
        return archived.returncode
    os.link(temporary_archive, archive)
    temporary_archive.unlink()
    (archives / f"chunk-{args.chunk:03d}.sha256").write_text(
        f"{sha256(archive)}  {archive.name}\n", encoding="utf-8"
    )
    shutil.rmtree(result)
    shutil.rmtree(eval_root)
    return completed.returncode or collection_status


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", required=True, type=Path,
                        help="evaluation-job.json from a prepared evaluation job")
    parser.add_argument("--chunk", required=True, type=int)
    parser.add_argument("--job-id", required=True)
    parser.add_argument("--image", type=Path,
                        help="explicit grading image path; default is HOME/cpu-eval-grading-images/IMAGE")
    parser.add_argument("--work-root", type=Path,
                        help="scratch root; defaults to TMPDIR, then the job directory's work/")
    args = parser.parse_args()
    try:
        return run_chunk(args)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError):
        root = args.bundle.resolve().parent
        archives = root / "archives"
        archive = archives / f"chunk-{args.chunk:03d}.tar.gz"
        if archive.exists():
            print(f"Existing evaluation result preserved: {archive}", file=sys.stderr)
            return 2
        result = root / "results" / f"chunk-{args.chunk:03d}"
        result.mkdir(parents=True, exist_ok=True)
        (result / "runner.exception.log").write_text(traceback.format_exc(), encoding="utf-8")
        archives.mkdir(exist_ok=True)
        try:
            with tarfile.open(archive, "x:gz") as stored:
                stored.add(result, arcname=str(result.relative_to(root)))
        except FileExistsError:
            print(f"Existing evaluation result preserved: {archive}", file=sys.stderr)
            return 2
        (archives / f"chunk-{args.chunk:03d}.sha256").write_text(
            f"{sha256(archive)}  {archive.name}\n", encoding="utf-8")
        print(f"Evaluation failed; evidence retained in {archive}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
