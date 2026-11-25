#!/usr/bin/env python3
"""Prepare a reusable CPU grading environment, including its sources and tests."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
CPUS = ('boom', 'cva6', 'ibex', 'rift2core', 'veer_el2', 'vexriscv')


def load_environment(directory: Path, cpu: str) -> tuple[Path, Path | None]:
    directory = directory.resolve()
    value = json.loads((directory / 'environment.json').read_text(encoding='utf-8'))
    if value.get('schema_version') != 1 or value.get('cpu') != cpu:
        raise ValueError(f'environment must be prepared for {cpu}')
    if cpu in ('ibex', 'veer_el2', 'vexriscv') and not value.get('assets'):
        raise ValueError(f'prepared {cpu} environment has no sources and tests')
    image = directory / value['image']
    assets = directory / value['assets'] if value.get('assets') else None
    if not image.is_file() or (assets is not None and not assets.is_dir()):
        raise ValueError('prepared environment files are missing')
    return image, assets


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cpu', required=True, choices=CPUS)
    parser.add_argument('--output', required=True, type=Path,
                        help='new directory outside the repository')
    parser.add_argument('--image', type=Path, help='reuse an existing grading image')
    parser.add_argument('--work-root', type=Path,
                        help='image build workspace; required unless --image is supplied')
    parser.add_argument('--runtime', choices=('singularity', 'apptainer'), default='singularity')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        parser.error('output must be a new directory outside the repository')
    if not args.image and not args.work_root:
        parser.error('--work-root is required when building an image')
    if args.work_root and (args.work_root.resolve() == ROOT or ROOT in args.work_root.resolve().parents):
        parser.error('work root must be outside the repository')
    if args.image and not args.image.is_file():
        parser.error('--image must be an existing file')
    if not shutil.which(args.runtime):
        parser.error(f'{args.runtime} is not in PATH')
    if args.cpu == 'veer_el2':
        version = subprocess.check_output(
            ['python3.12', '-c', 'import platform; print(platform.python_version())'], text=True).strip()
        if version != '3.12.3':
            parser.error('VeeR EL2 assembly preparation requires Python 3.12.3')
    output.mkdir(parents=True)
    definitions = json.loads((ROOT / 'tools/environment/evaluation-environments.json').read_text())
    definition = next(row for row in definitions['environments'] if row['id'] == args.cpu)
    image = args.image.resolve() if args.image else output / 'images' / definition['image']
    if not args.image:
        subprocess.run([
            sys.executable, str(ROOT / 'tools/environment/build_environment_images.py'),
            '--bundle', str(ROOT), '--environment', args.cpu,
            '--context-sources', str(ROOT / 'tools/environment/context-sources.json'),
            '--output', str(output / 'images'), '--work-root', str(args.work_root.resolve()),
            '--runtime', args.runtime,
        ], check=True)
    assets = None
    if args.cpu in ('ibex', 'vexriscv'):
        subprocess.run([
            args.runtime, 'exec', '--bind', f'{ROOT}:/mnt/cpu-eval:ro',
            '--bind', f'{output}:/mnt/environment', str(image),
            'python3', '/mnt/cpu-eval/tools/preparation/prepare_evaluation_assets.py',
            '--cpu', args.cpu, '--output', '/mnt/environment/inputs',
        ], check=True)
        assets = output / 'inputs/assets'
    elif args.cpu == 'veer_el2':
        subprocess.run(['bash', str(ROOT / 'tools/preparation/prepare_veer_assets.sh'),
                        str(output / 'inputs')], check=True)
        assets = output / 'inputs/assets'
    sys.path.insert(0, str(ROOT / 'tools/evaluation'))
    from prepare_evaluation_job import REQUIRED_ASSETS
    if not image.is_file():
        raise ValueError(f'image was not produced: {image}')
    for name in REQUIRED_ASSETS.get(args.cpu, ()):
        if assets is None or not (assets / name).exists():
            raise ValueError(f'environment preparation did not produce {name}')
    value = {'schema_version': 1, 'cpu': args.cpu,
             'image': str(image) if args.image else image.relative_to(output).as_posix(),
             'assets': assets.relative_to(output).as_posix() if assets else None}
    (output / 'environment.json').write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    print(f'Prepared {args.cpu} environment: {output}')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Environment preparation failed: {' '.join(str(error).split())}", file=sys.stderr)
        sys.exit(2)
