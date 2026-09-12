#!/usr/bin/env python3
"""Executable V25 reference audit for pinned Flutter installer + CI evidence handoff."""
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import os
import platform
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PIN = json.loads((ROOT/'toolchain/flutter_release_pin.json').read_text())
WORKFLOW = ROOT/'.github/workflows/native-verify.yml'


def run(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True, **kwargs)


def yaml_section_keys(text: str, section: str) -> set[str]:
    """Return direct mapping keys for a simple top-level YAML section.

    This audit intentionally avoids a PyYAML runtime dependency so it runs on
    both GitHub Ubuntu and macOS images using only the Python standard library.
    The canonical workflow uses plain mapping keys, so indentation is enough
    for the trust-boundary assertions below.
    """
    lines = text.splitlines()
    marker = f'{section}:'
    try:
        start = lines.index(marker) + 1
    except ValueError as exc:
        raise AssertionError(f'missing workflow section: {section}') from exc
    keys: set[str] = set()
    for line in lines[start:]:
        if line and not line.startswith(' '):
            break
        match = re.match(r'^  ([A-Za-z0-9_-]+):(?:\s.*)?$', line)
        if match:
            keys.add(match.group(1))
    return keys


# 1) Workflow structure / trust boundary.
text = WORKFLOW.read_text()
assert yaml_section_keys(text, 'jobs') == {'verify-lock','android-compile','ios-compile','evidence-consistency'}
triggers = yaml_section_keys(text, 'on')
assert {'workflow_dispatch','push','pull_request'} <= triggers
assert 'pull_request_target' not in triggers and 'workflow_run' not in triggers
assert 'permissions:\n  contents: read\n' in text
assert '${{ secrets.' not in text, 'compile CI must not consume signing secrets'
for token in ['actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1','actions/setup-java@de7274f081f381c8f8158605e0321c36c376e2e6','actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a','actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c']:
    assert token in text, token
assert 'runs-on: macos-26' in text
assert 'tool/verify_ci_native_evidence.py' in text
assert 'tool/install_pinned_flutter_ci.py' in text
assert 'tool/ensure_android_sdk_36_ci.sh' in text
assert 'flutter pub get --enforce-lockfile' in text
assert 'test -f pubspec.lock' in text

# 2) Offline positive/negative installer fixtures.
with tempfile.TemporaryDirectory(prefix='arus-v25-installer-') as td:
    td=Path(td)
    machine = platform.machine().lower()
    fixture_arch = 'arm64' if machine in {'arm64', 'aarch64'} else 'x64'
    archive=td/'flutter_fixture.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
        info = zipfile.ZipInfo('flutter/bin/flutter')
        info.external_attr = 0o100755 << 16
        zf.writestr(info, '#!/bin/sh\necho fixture\n')
    sha=hashlib.sha256(archive.read_bytes()).hexdigest()
    manifest={
        'base_url':'https://example.invalid/flutter',
        'current_release':{'stable':PIN['release_hash']},
        'releases':[{
            'hash':PIN['release_hash'], 'channel':'stable', 'version':PIN['flutter_version'],
            'dart_sdk_version':PIN['dart_version'], 'dart_sdk_arch':fixture_arch,
            'release_date':'2026-08-27T17:48:28Z',
            'archive':'stable/test/flutter_fixture.zip', 'sha256':sha,
        }]
    }
    manifest_path=td/'manifest.json'; manifest_path.write_text(json.dumps(manifest))
    install=td/'sdk'
    p=run(['python3','tool/install_pinned_flutter_ci.py','--install-dir',str(install),'--manifest-file',str(manifest_path),'--archive-file',str(archive)])
    assert p.returncode == 0, p.stdout+p.stderr
    assert (install/'bin/flutter').exists()
    assert os.access(install/'bin/flutter', os.X_OK), 'installer must preserve/restore Flutter executable bit'

    bad=dict(manifest); bad['releases']=[dict(manifest['releases'][0], hash='0'*40)]
    bad_path=td/'bad-hash.json'; bad_path.write_text(json.dumps(bad))
    p=run(['python3','tool/install_pinned_flutter_ci.py','--install-dir',str(td/'bad-sdk'),'--manifest-file',str(bad_path),'--archive-file',str(archive)])
    assert p.returncode != 0 and 'release git hash differs' in (p.stdout+p.stderr)

    bad2=dict(manifest); bad2['releases']=[dict(manifest['releases'][0], sha256='f'*64)]
    bad2_path=td/'bad-sha.json'; bad2_path.write_text(json.dumps(bad2))
    p=run(['python3','tool/install_pinned_flutter_ci.py','--install-dir',str(td/'bad-sdk2'),'--manifest-file',str(bad2_path),'--archive-file',str(archive)])
    assert p.returncode != 0 and 'SHA-256 mismatch' in (p.stdout+p.stderr)

# 3) Evidence cross-platform equality contract.
with tempfile.TemporaryDirectory(prefix='arus-v25-evidence-') as td:
    td=Path(td)
    base={
        'format':'arus-native-evidence-v2','status':'PASS',
        'canonical_source_manifest':{'sha256':'1'*64,'file_count':100},
        'source_manifest':{'sha256':'2'*64,'file_count':120},
        'pubspec_lock_sha256':'3'*64,
        'artifact':{'sha256':'4'*64,'path':'artifact','type':'file'},
        'flutter_version':'Flutter 3.47.2 • channel stable',
        'dart_version':'Dart SDK version: 3.13.2 (stable)',
    }
    a=dict(base, kind='android-compile')
    i=dict(base, kind='ios-compile', source_manifest={'sha256':'5'*64,'file_count':121}, artifact={'sha256':'6'*64,'path':'Runner.app','type':'directory-tree'})
    ap=td/'android.json'; ip=td/'ios.json'
    ap.write_text(json.dumps(a)); ip.write_text(json.dumps(i))
    p=run(['python3','tool/verify_ci_native_evidence.py',str(ap),str(ip)])
    assert p.returncode == 0, p.stdout+p.stderr
    i_bad=dict(i, pubspec_lock_sha256='7'*64); ip.write_text(json.dumps(i_bad))
    p=run(['python3','tool/verify_ci_native_evidence.py',str(ap),str(ip)])
    assert p.returncode != 0 and 'same pubspec.lock' in (p.stdout+p.stderr)

print('PASS: V25 pinned Flutter installer + native CI handoff reference contract')
