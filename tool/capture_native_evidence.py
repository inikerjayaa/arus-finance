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
EXCLUDED_DIRS = {'build', '.dart_tool', '.git', 'Pods', '.symlinks', '__pycache__'}
CANONICAL_ROOTS = {'lib', 'test', 'tool', 'docs', 'toolchain', '.github'}
CANONICAL_EXTRAS = {
    'pubspec.yaml',
    'pubspec.lock',
    'analysis_options.yaml',
    'bootstrap.sh',
    '.gitignore',
}


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


def _fixture_canonical_files() -> list[Path]:
    """Deterministic fallback for isolated historical fixtures with no .git."""
    files: list[Path] = []
    for root_name in CANONICAL_ROOTS:
        base = ROOT / root_name
        if not base.exists():
            continue
        for path in base.rglob('*'):
            if not path.is_file():
                continue
            rel = path.relative_to(ROOT)
            if any(part in EXCLUDED_DIRS for part in rel.parts):
                continue
            if path.name in EXCLUDED_NAMES or path.suffix in EXCLUDED_SUFFIXES:
                continue
            files.append(path)
    for rel_text in CANONICAL_EXTRAS:
        path = ROOT / rel_text
        if path.is_file():
            files.append(path)
    return files


def _tracked_canonical_files() -> list[Path]:
    """Return canonical files from Git, with fixture-only non-Git fallback.

    Real checkouts use only `git ls-files`, so runner-created untracked residue
    can never change cross-platform canonical source identity. Historical unit
    fixtures intentionally copy this script into a temporary directory without
    `.git`; only that isolated case falls back to a deterministic filesystem
    scan of the canonical roots.

    Historical readiness fixtures also intentionally remove pubspec.lock to
    prove DEPENDENCY_LOCK=BLOCKED. That one tracked file may therefore be absent
    while calculating a readiness source hash. Actual native evidence creation
    still requires pubspec.lock in main(). Every other missing tracked canonical
    file remains a hard failure.
    """
    if not (ROOT / '.git').exists():
        return _fixture_canonical_files()

    try:
        result = subprocess.run(
            ['git', 'ls-files', '-z'],
            cwd=ROOT,
            capture_output=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'FAIL: cannot enumerate tracked canonical source: {error}')

    files: list[Path] = []
    for raw in result.stdout.split(b'\0'):
        if not raw:
            continue
        rel = Path(os.fsdecode(raw))
        rel_posix = rel.as_posix()
        if not (
            (rel.parts and rel.parts[0] in CANONICAL_ROOTS)
            or rel_posix in CANONICAL_EXTRAS
        ):
            continue
        if any(part in EXCLUDED_DIRS for part in rel.parts):
            continue
        if rel.name in EXCLUDED_NAMES or rel.suffix in EXCLUDED_SUFFIXES:
            continue
        path = ROOT / rel
        if not path.is_file():
            if rel_posix == 'pubspec.lock':
                continue
            raise SystemExit(f'FAIL: tracked canonical source missing from worktree: {rel_posix}')
        files.append(path)
    return files


def _generated_native_files() -> list[Path]:
    files: list[Path] = []
    for name in ('android', 'ios'):
        base = ROOT / name
        if not base.exists():
            continue
        for path in base.rglob('*'):
            if not path.is_file():
                continue
            rel = path.relative_to(ROOT)
            if any(part in EXCLUDED_DIRS for part in rel.parts):
                continue
            if path.name in EXCLUDED_NAMES or path.suffix in EXCLUDED_SUFFIXES:
                continue
            files.append(path)
    return files


def source_manifest_hash(*, include_native: bool) -> tuple[str, int]:
    # Canonical identity is based on the checked-out tracked source only.
    # Generated Android/iOS shells are added solely to the full native-shell
    # evidence hash and never to the cross-platform canonical comparison.
    files = _tracked_canonical_files()
    if include_native:
        files.extend(_generated_native_files())
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
