#!/usr/bin/env python3

import argparse
from contextlib import ExitStack
import fcntl
import hashlib
from itertools import chain
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
from typing import FrozenSet, List, Optional

from build_boom_test_assets import directed_test_names, required_upstream_tests


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_tree(
    path: Path,
    excluded_names: FrozenSet[str] = frozenset(),
    exclude_dangling_symlinks: bool = False,
) -> str:
    digest = hashlib.sha256()
    for entry in sorted(path.rglob("*"), key=lambda item: item.as_posix()):
        if any(part in excluded_names for part in entry.relative_to(path).parts):
            continue
        relative = entry.relative_to(path).as_posix().encode()
        if entry.is_symlink():
            if exclude_dangling_symlinks and not entry.exists():
                continue
            digest.update(b"L\0" + relative + b"\0" + os.readlink(entry).encode() + b"\0")
        elif entry.is_file():
            digest.update(b"F\0" + relative + b"\0")
            digest.update(bytes.fromhex(sha256_file(entry)))
        elif entry.is_dir():
            digest.update(b"D\0" + relative + b"\0")
    return digest.hexdigest()


def materialize_definition(source: Path, destination: Path, parent_image: Optional[Path]) -> None:
    lines = source.read_text(encoding="utf-8").splitlines()
    if parent_image is not None:
        if not lines or lines[0] != "Bootstrap: localimage" or not lines[1].startswith("From: "):
            raise ValueError(f"{source}: expected a localimage header")
        lines[1] = f"From: {parent_image}"
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def smoke_command(runtime: str, image: Path, command: str) -> List[str]:
    return [runtime, "exec", str(image), "sh", "-c", command]


def boom_test_smoke_check(source_root: Path) -> str:
    manifest = json.loads((source_root / "tools/environment/boom-directed-test-assets.json").read_text())
    directed = directed_test_names(manifest["assets"])
    expected = directed | required_upstream_tests(source_root, directed)
    names = "".join(f"{name}\n" for name in sorted(expected)).encode()
    digest = hashlib.sha256(names).hexdigest()
    return ('test "$(cut -c 67- /opt/boom-tests/SHA256SUMS.tests | LC_ALL=C sort | sha256sum)"'
            f' = "{digest}  -"')


def input_record(environment: dict, definition: Path, context_root: Path, image_root: Path) -> dict:
    context = []
    for item in environment["context"]:
        path = context_root / environment["id"] / item["name"]
        if not path.exists():
            raise FileNotFoundError(f"missing build context: {path}")
        context.append({"name": item["name"], "sha256": sha256_tree(path)})
    parent = environment.get("parent")
    parent_entry = None
    if parent:
        parent_image = image_root / f"{parent}-eval.sif"
        if not parent_image.is_file():
            raise FileNotFoundError(f"missing parent image: {parent_image}")
        parent_entry = {"id": parent, "sha256": sha256_file(parent_image)}
    record = {
        "definition_sha256": sha256_file(definition),
        "context": context,
        "parent": parent_entry,
        "smoke_command": environment["smoke_command"],
    }
    if context:
        record["context_permission_policy"] = "world-readable-v1"
    return record


def readable_context(path: Path) -> None:
    """Expose copied public build inputs to ordinary users inside the image."""
    for entry in chain((path,), path.rglob("*")):
        if entry.is_symlink():
            continue
        mode = entry.stat().st_mode
        if stat.S_ISDIR(mode):
            entry.chmod(stat.S_IMODE(mode) | 0o555)
        elif stat.S_ISREG(mode):
            entry.chmod(stat.S_IMODE(mode) | 0o444 | (0o111 if mode & 0o111 else 0))


def same_build_inputs(previous: dict, current: dict) -> bool:
    return {key: value for key, value in previous.items() if key != "smoke_command"} == {
        key: value for key, value in current.items() if key != "smoke_command"
    }


def write_receipt(path: Path, record: dict) -> None:
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def publish_image(source: Path, destination: Path, expected_sha256: str) -> None:
    temporary = destination.with_name(f".{destination.name}.tmp-{os.getpid()}")
    try:
        shutil.copyfile(source, temporary)
        actual = sha256_file(temporary)
        if actual != expected_sha256:
            raise ValueError(
                f"image changed while publishing: expected {expected_sha256}, got {actual}"
            )
        os.replace(temporary, destination)
    finally:
        if temporary.exists():
            temporary.unlink()


def build_one(
    environment: dict,
    bundle: Path,
    output: Path,
    context_root: Path,
    work_root: Path,
    runtime: str,
) -> str:
    environment_id = environment["id"]
    if environment_id == "boom":
        test_check = boom_test_smoke_check(context_root / "boom/boom-directed-tests")
        environment = dict(environment, smoke_command=f"{environment['smoke_command']} && {test_check}")
    definition_source = bundle / environment["definition"]
    image = output / environment["image"]
    receipt = output / f"{environment_id}.receipt.json"
    inputs = input_record(environment, definition_source, context_root, output)

    if receipt.is_file() and image.is_file():
        previous = json.loads(receipt.read_text(encoding="utf-8"))
        image_hash = sha256_file(image)
        if previous.get("image_sha256") == image_hash:
            if previous.get("inputs") == inputs:
                write_receipt(receipt, previous)
                return "reused"
            if same_build_inputs(previous.get("inputs", {}), inputs):
                subprocess.run(smoke_command(runtime, image, environment["smoke_command"]), check=True)
                previous["inputs"] = inputs
                write_receipt(receipt, previous)
                return "revalidated"

    parent = environment.get("parent")
    parent_image = output / f"{parent}-eval.sif" if parent else None
    work_root.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=f"cpu-eval-{environment_id}-", dir=work_root))
    try:
        definition = work / definition_source.name
        materialize_definition(definition_source, definition, parent_image)
        for item in environment["context"]:
            shutil.copytree(
                context_root / environment_id / item["name"],
                work / item["name"],
                symlinks=True,
            )
            readable_context(work / item["name"])
        temporary_image = work / environment["image"]
        subprocess.run(
            [runtime, "build", "--fakeroot", str(temporary_image), str(definition)],
            cwd=work,
            check=True,
        )
        subprocess.run(smoke_command(runtime, temporary_image, environment["smoke_command"]), check=True)
        image_hash = sha256_file(temporary_image)
        publish_image(temporary_image, image, image_hash)
        record = {
            "environment": environment_id,
            "inputs": inputs,
            "image": environment["image"],
            "image_sha256": image_hash,
        }
        write_receipt(receipt, record)
        return "built"
    finally:
        shutil.rmtree(work, ignore_errors=True)


def safe_context_path(path: str) -> Path:
    candidate = Path(path)
    if candidate.is_absolute() or not candidate.parts or ".." in candidate.parts:
        raise ValueError(f"unsafe context path: {path}")
    return candidate


def fetch_git_revision(url: str, revision: str, repository: Path) -> None:
    repository.mkdir(parents=True)
    subprocess.run(["git", "-C", str(repository), "init", "-q"], check=True)
    subprocess.run(
        ["git", "-C", str(repository), "fetch", "--depth", "1", url, revision], check=True
    )


def git_archive_tree(url: str, revision: str, destination: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="cpu-eval-git-") as temporary:
        repository = Path(temporary) / "repository"
        fetch_git_revision(url, revision, repository)
        destination.mkdir(parents=True)
        extract_git_archive(repository, revision, destination)


def extract_git_archive(
    repository: Path, revision: str, destination: Path, *paths: str
) -> None:
    process = subprocess.Popen(
        ["git", "-C", str(repository), "archive", revision, *paths], stdout=subprocess.PIPE
    )
    assert process.stdout is not None
    with process.stdout:
        with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
            archive.extractall(destination, filter="data")
    if process.wait() != 0:
        raise subprocess.CalledProcessError(process.returncode, process.args)


def build_rift2core_golden_catalog(manifest: dict, destination: Path) -> None:
    compiler_version = subprocess.check_output(
        ["riscv64-unknown-elf-gcc", "-dumpfullversion"], text=True
    ).strip()
    if compiler_version != manifest["gcc_version"]:
        raise ValueError(f"riscv64-unknown-elf-gcc version differs: {compiler_version}")
    objcopy_version = subprocess.check_output(
        ["riscv64-unknown-elf-objcopy", "--version"], text=True
    ).splitlines()[0].split()[-1]
    if objcopy_version != manifest["binutils_version"]:
        raise ValueError(f"riscv64-unknown-elf-objcopy version differs: {objcopy_version}")

    with tempfile.TemporaryDirectory(prefix="cpu-eval-golden-source-") as temporary:
        repositories = {}
        for name in ("riscv_tests", "riscv_test_env", "rift2core"):
            source = manifest[name]
            repository = Path(temporary) / name
            fetch_git_revision(source["url"], source["revision"], repository)
            repositories[name] = repository

        def source_file(repository_name: str, path: str) -> bytes:
            source = manifest[repository_name]
            return subprocess.check_output(
                ["git", "-C", str(repositories[repository_name]), "show",
                 f"{source['revision']}:{path}"]
            )

        build = Path(temporary) / "build"
        for local, repository_name, source in (
            ("env/encoding.h", "riscv_test_env", "encoding.h"),
            ("env/p/link.ld", "riscv_test_env", "p/link.ld"),
            ("isa/macros/scalar/test_macros.h", "riscv_tests", "isa/macros/scalar/test_macros.h"),
            ("env/p/riscv_test.h", "rift2core", "tb/compile/riscv-tests/env/p/riscv_test.h"),
        ):
            target = build / local
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source_file(repository_name, source))

        source_tree = build / "source"
        source_tree.mkdir()
        extract_git_archive(
            repositories["riscv_tests"], manifest["riscv_tests"]["revision"], source_tree,
            "isa",
        )

        images = destination / "images"
        passing = destination / "passing-images"
        compiled = build / "compiled"
        images.mkdir(parents=True)
        passing.mkdir()
        compiled.mkdir()
        for test in manifest["tests"]:
            name = test["name"]
            if re.fullmatch(r"rv64(?:mi|si|ua|uc|ui|um)-p-[A-Za-z0-9_-]+", name) is None:
                raise ValueError(f"invalid RISC-V test name: {name}")
            suite, case = name.split("-p-", 1)
            source = source_tree / "isa" / suite / f"{case}.S"
            binary = compiled / name
            subprocess.run([
                "riscv64-unknown-elf-gcc", "-save-temps=obj", "-march=rv64g", "-mabi=lp64", "-static",
                "-mcmodel=medany", "-fvisibility=hidden", "-nostdlib", "-nostartfiles",
                "-fcommon", f"-I{build / 'env/p'}", f"-I{build / 'isa/macros/scalar'}",
                f"-T{build / 'env/p/link.ld'}", str(source), "-o", str(binary),
            ], check=True)
            shutil.copy2(binary, images / name)
            if sha256_file(binary) != test["elf_sha256"]:
                raise ValueError(f"golden executable differs: {name}")
            verilog = images / f"{name}.verilog"
            subprocess.run(
                ["riscv64-unknown-elf-objcopy", "-O", "verilog", str(binary), str(verilog)],
                check=True,
            )
            verilog.write_bytes(verilog.read_bytes().replace(b"@800", b"@000"))
            if sha256_file(verilog) != test["verilog_sha256"]:
                raise ValueError(f"golden Verilog image differs: {name}")
            (passing / name).symlink_to(f"../images/{name}")
            (passing / f"{name}.verilog").symlink_to(f"../images/{name}.verilog")


def build_boom_chipyard(specification: dict, destination: Path, bundle: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="cpu-eval-chipyard-") as temporary:
        repository = Path(temporary) / "chipyard"
        fetch_git_revision(specification["url"], specification["revision"], repository)
        subprocess.run(
            ["git", "-C", str(repository), "checkout", "--detach", specification["revision"]],
            check=True,
        )
        subprocess.run([
            "git", "-C", str(repository), "submodule", "update", "--init", "--depth", "1",
            "--jobs", "4", "--", *specification["submodules"],
        ], check=True)
        for parent, names in specification["nested_submodules"].items():
            subprocess.run([
                "git", "-C", str(repository / safe_context_path(parent)), "submodule",
                "update", "--init", "--depth", "1", "--", *names,
            ], check=True)

        def ignored(directory: str, names: List[str]) -> List[str]:
            return [
                name for name in names
                if name == ".git" or (
                    (Path(directory) / name).is_symlink()
                    and not (Path(directory) / name).exists()
                )
            ]

        shutil.copytree(repository, destination, symlinks=True, ignore=ignored)

    for item in specification["patches"]:
        target = destination if item["directory"] == "." else destination / safe_context_path(item["directory"])
        patch = bundle / safe_context_path(item["path"])
        subprocess.run(["git", "-C", str(target), "apply", str(patch)], check=True)
    collision = specification["directed_test"]
    source = bundle / safe_context_path(collision["source"])
    target = destination / safe_context_path(collision["target"])
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    makefrag = destination / safe_context_path(collision["makefrag"])
    text = makefrag.read_text(encoding="utf-8")
    before = "ldst move structural recoding \\\n"
    if text.count(before) != 1:
        raise ValueError(f"unexpected RISC-V test Makefrag: {makefrag}")
    makefrag.write_text(
        text.replace(before, "ldst move structural recoding arbiter_collision \\\n"),
        encoding="utf-8",
    )


def materialize_context_source(
    specification: dict, destination: Path, bundle: Optional[Path] = None
) -> None:
    kind = specification["kind"]
    if kind == "git_archive":
        git_archive_tree(specification["url"], specification["revision"], destination)
    elif kind == "git_files":
        destination.mkdir(parents=True)
        with tempfile.TemporaryDirectory(prefix="cpu-eval-git-files-") as temporary:
            repositories: dict[tuple[str, str], Path] = {}
            for item in specification["files"]:
                target = destination / safe_context_path(item["target"])
                target.parent.mkdir(parents=True, exist_ok=True)
                source = (item["url"], item["revision"])
                repository = repositories.get(source)
                if repository is None:
                    repository = Path(temporary) / str(len(repositories))
                    fetch_git_revision(item["url"], item["revision"], repository)
                    repositories[source] = repository
                data = subprocess.check_output(
                    ["git", "-C", str(repository), "show", f"{item['revision']}:{item['path']}"]
                )
                target.write_bytes(data)
                if item.get("executable"):
                    target.chmod(0o755)
        for name, contents in specification.get("literal_files", {}).items():
            target = destination / safe_context_path(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(contents, encoding="utf-8")
    elif kind == "rift2core_golden_catalog":
        if bundle is None:
            raise ValueError("the evaluation repository is required for the golden catalog")
        manifest_path = bundle / safe_context_path(specification["manifest"])
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        build_rift2core_golden_catalog(manifest, destination)
    elif kind == "boom_chipyard":
        if bundle is None:
            raise ValueError("the evaluation repository is required for the Chipyard context")
        build_boom_chipyard(specification, destination, bundle)
    else:
        raise ValueError(f"unknown context source kind: {kind}")
    for name in specification.get("empty_directories", []):
        (destination / safe_context_path(name)).mkdir(parents=True, exist_ok=True)
    actual = sha256_tree(destination)
    if actual != specification["sha256"]:
        raise ValueError(f"context source hash differs: {actual} != {specification['sha256']}")


def stage_context(manifest: dict, bundle: Path, source_file: Path, context_root: Path) -> None:
    sources = json.loads(source_file.read_text(encoding="utf-8"))["sources"]
    with ExitStack() as temporary_sources:
        for environment in manifest["environments"]:
            for item in environment["context"]:
                destination = context_root / environment["id"] / item["name"]
                if "repository_files" in item:
                    temporary = temporary_sources.enter_context(
                        tempfile.TemporaryDirectory(prefix="cpu-eval-repository-context-")
                    )
                    source = Path(temporary) / "source"
                    matched = set()
                    for pattern in item["repository_files"]:
                        safe_context_path(pattern)
                        matched.update(path for path in bundle.glob(pattern)
                                       if path.is_file() or path.is_symlink())
                    if not matched:
                        raise FileNotFoundError(
                            f"repository context has no matching files: {environment['id']}/{item['name']}"
                        )
                    for path in sorted(matched):
                        target = source / path.relative_to(bundle)
                        target.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(path, target, follow_symlinks=False)
                else:
                    key = f"{environment['id']}/{item['name']}"
                    if key not in sources:
                        raise KeyError(f"missing context source declaration: {key}")
                    declaration = sources[key]
                    if destination.is_dir() and sha256_tree(destination) == declaration["sha256"]:
                        continue
                    temporary = temporary_sources.enter_context(
                        tempfile.TemporaryDirectory(prefix="cpu-eval-context-")
                    )
                    source = Path(temporary) / "source"
                    materialize_context_source(declaration, source, bundle)
                if not source.exists():
                    raise FileNotFoundError(f"missing declared context source: {source}")
                destination.parent.mkdir(parents=True, exist_ok=True)
                excluded_names = frozenset(item.get("exclude_names", []))
                exclude_dangling = bool(item.get("exclude_dangling_symlinks", False))
                source_hash = sha256_tree(source, excluded_names, exclude_dangling)
                if destination.exists() and source_hash == sha256_tree(destination):
                    continue

                temporary = destination.with_name(f".{destination.name}.staging-{os.getpid()}")
                shutil.rmtree(temporary, ignore_errors=True)
                def ignored(directory: str, names: List[str]) -> List[str]:
                    ignored_names = [name for name in names if name in excluded_names]
                    if exclude_dangling:
                        ignored_names.extend(
                            name
                            for name in names
                            if (Path(directory) / name).is_symlink()
                            and not (Path(directory) / name).exists()
                        )
                    return sorted(set(ignored_names))

                ignore = ignored if excluded_names or exclude_dangling else None
                shutil.copytree(source, temporary, symlinks=True, ignore=ignore)
                if sha256_tree(temporary) != source_hash:
                    shutil.rmtree(temporary, ignore_errors=True)
                    raise ValueError(f"staged context changed while copying: {source}")
                shutil.rmtree(destination, ignore_errors=True)
                os.replace(temporary, destination)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True,
                        help="CPU-Eval repository root")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--context-sources", type=Path)
    parser.add_argument(
        "--stage-only", action="store_true", help="Prepare build contexts without building images."
    )
    parser.add_argument(
        "--work-root",
        type=Path, required=True,
        help="Node-local directory for staged contexts and image build work.",
    )
    parser.add_argument("--runtime", choices=("singularity", "apptainer"))
    parser.add_argument(
        "--context-name", action="append", default=[],
        help="With --stage-only, prepare only the named context within selected environments.",
    )
    parser.add_argument(
        "--environment",
        action="append",
        default=[],
        help="Build or revalidate only the named environment (repeatable).",
    )
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    for name, path in (("output", args.output), ("work-root", args.work_root)):
        resolved = path.resolve()
        if resolved == bundle or bundle in resolved.parents:
            parser.error(f"--{name} must be outside the repository")
    manifest = json.loads((bundle / "tools/environment/evaluation-environments.json").read_text(encoding="utf-8"))
    declared = {environment["id"] for environment in manifest["environments"]}
    unknown = sorted(set(args.environment) - declared)
    if unknown:
        parser.error("unknown environment: " + ", ".join(unknown))
    selected = set(args.environment) if args.environment else declared
    if not args.stage_only:
        by_id = {environment['id']: environment for environment in manifest['environments']}
        pending = list(selected)
        while pending:
            parent = by_id[pending.pop()].get('parent')
            if parent and parent not in selected:
                if parent not in by_id:
                    parser.error('unknown parent environment: ' + parent)
                selected.add(parent)
                pending.append(parent)
    selected_manifest = {
        "environments": [
            environment
            for environment in manifest["environments"]
            if environment["id"] in selected
        ]
    }
    if args.context_name:
        if not args.stage_only:
            parser.error("--context-name requires --stage-only")
        declared_contexts = {
            item["name"] for environment in selected_manifest["environments"]
            for item in environment["context"]
        }
        unknown_contexts = sorted(set(args.context_name) - declared_contexts)
        if unknown_contexts:
            parser.error("unknown context: " + ", ".join(unknown_contexts))
        selected_manifest = {
            "environments": [
                dict(environment, context=[
                    item for item in environment["context"]
                    if item["name"] in args.context_name
                ])
                for environment in selected_manifest["environments"]
            ]
        }
    args.output.mkdir(parents=True, exist_ok=True)
    work_root = args.work_root.resolve()
    context_root = work_root / "context"
    if args.context_sources:
        stage_context(selected_manifest, bundle, args.context_sources, context_root)
    if args.stage_only:
        if not args.context_sources:
            parser.error("--stage-only requires --context-sources")
        print(context_root, flush=True)
        return 0
    runtime = args.runtime or shutil.which("apptainer") or shutil.which("singularity")
    if runtime is None:
        parser.error("neither apptainer nor singularity is available")
    results = {}
    locks = args.output / ".locks"
    locks.mkdir(exist_ok=True)
    for environment in selected_manifest["environments"]:
        environment_id = environment["id"]
        with (locks / f"{environment_id}.lock").open("a", encoding="utf-8") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            results[environment_id] = build_one(
                environment,
                bundle,
                args.output,
                context_root,
                work_root / "build",
                runtime,
            )
        print(f"{environment_id}\t{results[environment_id]}", flush=True)
    (args.output / "build-summary.json").write_text(
        json.dumps(results, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
