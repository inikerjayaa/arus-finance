"""Create a secret-free evidence record for a successful native build gate."""
from __future__ import annotations
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_NAMES = {'key.properties'}
EXCLUDED_SUFFIXES = {'.jks', '.keystore'}
EXCLUDED_DIRS = {'build', '.dart_tool', '.git', 'Pods', '.symlinks'}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def tree_hash(path: Path) -> str:
    h = hashlib.sha256()
    files = [p for p in path.rglob('*') if p.is_file()]
    for p in sorted(files, key=lambda x: x.relative_to(path).as_posix()):
        rel = p.relative_to(path).as_posix()
        h.update(rel.encode())
        h.update(b'\0')
        h.update(bytes.fromhex(sha256_file(p)))
    return h.hexdigest()


def artifact_hash(path: Path) -> tuple[str, str]:
    if path.is_file():
        return 'file', sha256_file(path)
    if path.is_dir():
        return 'directory-tree', tree_hash(path)
    raise SystemExit(f'FAIL: build artifact tidak ditemukan: {path}')


def cmd_output(args: list[str]) -> str:
    p = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=False)
    out = (p.stdout + '\n' + p.stderr).strip()
    return out[:8000]


def source_manifest_hash(*, include_native: bool) -> tuple[str, int]:
    roots = [ROOT / x for x in ('lib', 'test', 'tool', 'docs', 'toolchain', '.github')]
    extras = [ROOT / x for x in ('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml', 'bootstrap.sh', '.gitignore')]
    if include_native:
        if (ROOT / 'android').exists(): roots.append(ROOT / 'android')
        if (ROOT / 'ios').exists(): roots.append(ROOT / 'ios')
    files: list[Path] = []
    for base in roots:
        if base.exists():
            for p in base.rglob('*'):
                if not p.is_file(): continue
                rel = p.relative_to(ROOT)
                if any(part in EXCLUDED_DIRS for part in rel.parts): continue
                if p.name in EXCLUDED_NAMES or p.suffix in EXCLUDED_SUFFIXES: continue
                files.append(p)
    for p in extras:
        if p.exists(): files.append(p)
    files = sorted(set(files), key=lambda p: p.relative_to(ROOT).as_posix())
    h = hashlib.sha256()
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        h.update(rel.encode())
        h.update(b'\0')
        h.update(bytes.fromhex(sha256_file(p)))
    return h.hexdigest(), len(files)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--kind', required=True, choices=['android-compile','ios-compile','android-release','ios-release'])
    ap.add_argument('--artifact', required=True)
    ns = ap.parse_args()

    artifact = (ROOT / ns.artifact).resolve() if not Path(ns.artifact).is_absolute() else Path(ns.artifact)
    atype, ahash = artifact_hash(artifact)
    native_manifest_hash, native_manifest_count = source_manifest_hash(include_native=True)
    canonical_manifest_hash, canonical_manifest_count = source_manifest_hash(include_native=False)
    lock = ROOT / 'pubspec.lock'
    if not lock.exists():
        raise SystemExit('FAIL: pubspec.lock hilang; evidence tidak boleh dibuat tanpa resolved dependency graph.')

    payload = {
        'format': 'arus-native-evidence-v2',
        'kind': ns.kind,
        'status': 'PASS',
        'created_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'artifact': {
            'path': os.path.relpath(artifact, ROOT),
            'type': atype,
            'sha256': ahash,
        },
        # Keep source_manifest as the full native-shell hash for backward readability.
        'source_manifest': {'sha256': native_manifest_hash, 'file_count': native_manifest_count},
        'canonical_source_manifest': {'sha256': canonical_manifest_hash, 'file_count': canonical_manifest_count},
        'pubspec_lock_sha256': sha256_file(lock),
        'flutter_version': cmd_output(['flutter', '--version']),
        'dart_version': cmd_output(['dart', '--version']),
        'java_version': cmd_output(['java', '-version']) if ns.kind.startswith('android') else None,
        'xcode_version': cmd_output(['xcodebuild', '-version']) if ns.kind.startswith('ios') else None,
    }
    outdir = ROOT / 'build/arus_evidence'
    outdir.mkdir(parents=True, exist_ok=True)
    out = outdir / f'{ns.kind}.json'
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + '\n')
    print(f'PASS: native evidence written: {out.relative_to(ROOT)}')
    print(f'ARTIFACT_SHA256={ahash}')
    print(f'NATIVE_SOURCE_MANIFEST_SHA256={native_manifest_hash}')
    print(f'CANONICAL_SOURCE_MANIFEST_SHA256={canonical_manifest_hash}')

if __name__ == '__main__':
    main()
