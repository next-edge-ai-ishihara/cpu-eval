#!/usr/bin/env python3
"""Package selected CPU-Eval submissions for local or scheduled evaluation."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
from extract_submission import extract_submission

ROOT = Path(__file__).resolve().parents[2]
SUFFIXES = {
    "boom": (".scala",),
    "cva6": (".sv", ".v"),
    "ibex": (".sv", ".v"),
    "rift2core": (".scala",),
    "veer_el2": (".sv", ".v"),
    "vexriscv": (".scala",),
}
ASSET_CPUS = {"ibex", "veer_el2", "vexriscv"}
REQUIRED_ASSETS = {
    "ibex": ("ibex-source", "spike-install/bin/spike", "programs"),
    "veer_el2": ("veer-el2-source", "veer-generated-tests"),
    "vexriscv": (
        "spinalhdl-source", "profiles/spinal", "profiles/vex-standard", "profiles/debug"
    ),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def parse_candidates(values: list[str], valid: set[str]) -> dict[str, list[Path]]:
    result: dict[str, list[Path]] = {}
    for value in values:
        problem, separator, name = value.partition("=")
        if not separator or problem not in valid:
            raise ValueError(f"invalid candidate assignment: {value}")
        source = Path(name).resolve()
        if not source.is_file():
            raise ValueError(f"candidate must be an existing UTF-8 final-answer file: {source}")
        result.setdefault(problem, []).append(source)
    if not result:
        raise ValueError("at least one --candidate is required")
    counts = {problem: len(paths) for problem, paths in sorted(result.items())}
    if len(set(counts.values())) != 1:
        raise ValueError("all problems must have the same number of candidates: " +
                         ", ".join(f"{problem}={count}" for problem, count in counts.items()))
    return result


def problem_rows(root: Path, cpu: str | None = None) -> list[dict[str, str]]:
    rows = []
    paths = [root / 'cpus' / cpu / 'PROBLEMS.tsv'] if cpu else sorted(root.glob('cpus/*/PROBLEMS.tsv'))
    for path in paths:
        with path.open(encoding='utf-8') as stream:
            for row in csv.DictReader(stream, delimiter='\t'):
                rows.append({'cpu': path.parent.name, 'problem': row['problem'],
                             'directory': (path.parent.relative_to(root) / row['directory']).as_posix(),
                             'specification': (path.parent.relative_to(root) / row['specification']).as_posix(),
                             'test_recipe': (path.parent.relative_to(root) / row['test_recipe']).as_posix()})
    return rows


def prepare() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cpu", required=True, choices=sorted(SUFFIXES))
    parser.add_argument("--candidate", action="append", default=[], metavar="PROBLEM=FILE",
                        help="saved UTF-8 final answer or HDL; extraction is automatic")
    environment = parser.add_mutually_exclusive_group(required=True)
    environment.add_argument("--image", type=Path)
    environment.add_argument("--environment", type=Path, help="directory created by prepare_environment.py")
    parser.add_argument("--assets", type=Path, help="prepared assets for Ibex, VeeR EL2, or VexRiscv")
    parser.add_argument("--reuse-assets", action="store_true",
                        help="reference and hash shared assets in place instead of copying them; local execution only")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--problems-per-chunk", type=int, default=1,
                        help="number of problems per CVA6 chunk; other CPUs require one")
    args = parser.parse_args()
    if args.environment:
        if args.assets:
            parser.error('--assets cannot be combined with --environment')
        from prepare_environment import load_environment
        args.image, args.assets = load_environment(args.environment, args.cpu)
    if args.problems_per_chunk < 1:
        parser.error("--problems-per-chunk must be positive")
    if args.cpu != 'cva6' and args.problems_per_chunk != 1:
        parser.error("--problems-per-chunk greater than one is supported only for CVA6")
    if args.reuse_assets and (args.assets is None or args.cpu not in ASSET_CPUS):
        parser.error("--reuse-assets requires --assets for Ibex, VeeR EL2, or VexRiscv")

    valid = {row['problem'] for row in problem_rows(ROOT, args.cpu)}
    candidates = parse_candidates(args.candidate, valid)
    language = 'scala' if args.cpu in {'boom', 'rift2core', 'vexriscv'} else 'verilog'
    for problem, sources in candidates.items():
        for source in sources:
            source.read_text(encoding='utf-8')
    image = args.image.resolve()
    if not image.is_file():
        raise FileNotFoundError(image)
    if args.cpu in ASSET_CPUS and (args.assets is None or not args.assets.is_dir()):
        raise ValueError(f"--assets is required for {args.cpu}")
    if args.assets is not None:
        for name in REQUIRED_ASSETS.get(args.cpu, ()):
            if not (args.assets / name).exists():
                raise FileNotFoundError(f"required grading asset is missing: {name}")
    destination = args.output.resolve()
    if destination.exists():
        raise FileExistsError(destination)
    if destination == ROOT or ROOT in destination.parents:
        raise ValueError("job output must be outside the repository")
    if args.assets is not None and (destination == args.assets.resolve() or
                                   args.assets.resolve() in destination.parents):
        raise ValueError("job output must not be inside its asset source")

    config = json.loads((ROOT / "tools/evaluation/adapters.json").read_text(encoding="utf-8"))
    adapter = config["adapters"][args.cpu]
    names = {
        "LICENSE",
        "NOTICE",
        "THIRD_PARTY_NOTICES.md",
        "tools/__init__.py",
        "tools/evaluation/adapters.json",
        "tools/evaluation/run_evaluation_chunk.py",
        str(adapter["driver"]),
        *[str(name) for name in adapter.get("support_files", [])],
    }
    if adapter.get("checkout_preparer"):
        names.add(str(adapter["checkout_preparer"]))
    for directory in (ROOT / 'cpus' / args.cpu, ROOT / 'LICENSES'):
        names.update(path.relative_to(ROOT).as_posix() for path in directory.rglob('*')
                     if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc')
    records = {}
    for name in sorted(names):
        if not (ROOT / name).is_file():
            raise FileNotFoundError(f"required evaluation file is missing: {name}")
        records[name] = sha256(ROOT / name)
    distribution_hash = hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest()

    destination.mkdir(parents=True)
    for name in sorted(names):
        target = destination / "repo" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
    external_assets = None
    if args.assets is not None and args.reuse_assets:
        external_assets = {
            "path": str(args.assets.resolve()),
            "files": [{"path": path.relative_to(args.assets.resolve()).as_posix(),
                       "sha256": sha256(path)}
                      for path in sorted(args.assets.resolve().rglob('*')) if path.is_file()],
        }
    elif args.assets is not None:
        shutil.copytree(args.assets.resolve(), destination / "assets")

    submissions = destination / "submissions" / args.cpu
    chunks_dir = destination / "chunks"
    chunks_dir.mkdir(parents=True)
    chunks = []
    for problem, sources in sorted(candidates.items()):
        for sample_index, source in enumerate(sources):
            sample = submissions / problem / f"sample-{sample_index:02d}"
            sample.mkdir(parents=True)
            raw = source.read_bytes()
            text, decision = extract_submission(raw.decode('utf-8'), language)
            (sample / 'response.txt').write_bytes(raw)
            suffix = source.suffix if source.suffix in SUFFIXES[args.cpu] else SUFFIXES[args.cpu][0]
            target = sample / f"submission{suffix}"
            target.write_text(text, encoding='utf-8', newline='')
            write_json(sample / 'extraction.json', {
                **decision,
                'response_sha256': hashlib.sha256(raw).hexdigest(),
                'submission': target.name,
                'submission_sha256': sha256(target),
            })
    problem_names = sorted(candidates)
    for start in range(0, len(problem_names), args.problems_per_chunk):
        index = len(chunks) + 1
        problems = problem_names[start:start + args.problems_per_chunk]
        chunk_path = chunks_dir / f"chunk-{index:03d}.tsv"
        with chunk_path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=["problem"], delimiter="\t", lineterminator="\n")
            writer.writeheader()
            writer.writerows({"problem": problem} for problem in problems)
        chunks.append({
            "index": index,
            "path": chunk_path.relative_to(destination).as_posix(),
            "problems": problems,
            "sha256": sha256(chunk_path),
        })

    execution = {
        "schema_version": 1,
        "evaluation_files_sha256": distribution_hash,
        "cpu": args.cpu,
        "adapter": adapter,
        "image": image.name,
        "image_sha256": sha256(image),
        "problem_count": len(candidates),
        "sample_count": len(next(iter(candidates.values()))),
        "chunks": chunks,
    }
    if external_assets is not None:
        execution["external_assets"] = external_assets
    write_json(destination / "evaluation-job.json", execution)
    with (destination / "bundle-files.sha256").open("w", encoding="utf-8") as stream:
        for path in sorted(destination.rglob("*")):
            if path.is_file() and path.name != "bundle-files.sha256":
                stream.write(f"{sha256(path)}  {path.relative_to(destination).as_posix()}\n")
    print(f"bundle={destination} chunks={len(chunks)} image_sha256={sha256(image)}")
    return 0


def main() -> int:
    try:
        return prepare()
    except (OSError, ValueError) as error:
        print(f"Job preparation failed: {' '.join(str(error).split())}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
