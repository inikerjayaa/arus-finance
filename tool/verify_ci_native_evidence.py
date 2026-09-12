#!/usr/bin/env python3
"""Cross-check Android/iOS compile evidence from independent CI runners."""
from pathlib import Path
import argparse
import json

ap = argparse.ArgumentParser()
ap.add_argument('android')
ap.add_argument('ios')
ns = ap.parse_args()
a = json.loads(Path(ns.android).read_text())
i = json.loads(Path(ns.ios).read_text())

for label, obj, kind in [('android', a, 'android-compile'), ('ios', i, 'ios-compile')]:
    if obj.get('status') != 'PASS' or obj.get('kind') != kind:
        raise SystemExit(f'FAIL: {label} evidence is not a PASS {kind} record.')
    if obj.get('format') != 'arus-native-evidence-v2':
        raise SystemExit(f'FAIL: {label} evidence format is not v2.')
    if not obj.get('artifact', {}).get('sha256'):
        raise SystemExit(f'FAIL: {label} artifact hash missing.')
    if not obj.get('canonical_source_manifest', {}).get('sha256'):
        raise SystemExit(f'FAIL: {label} canonical source hash missing.')

if a['pubspec_lock_sha256'] != i['pubspec_lock_sha256']:
    raise SystemExit('FAIL: Android and iOS did not compile the same pubspec.lock.')
if a['canonical_source_manifest']['sha256'] != i['canonical_source_manifest']['sha256']:
    raise SystemExit('FAIL: Android and iOS did not compile the same canonical Arus source.')
if 'Flutter 3.47.2' not in a.get('flutter_version', '') or 'Flutter 3.47.2' not in i.get('flutter_version', ''):
    raise SystemExit('FAIL: one platform evidence was not produced by Flutter 3.47.2.')
if 'Dart SDK version: 3.13.2' not in a.get('dart_version', '') or 'Dart SDK version: 3.13.2' not in i.get('dart_version', ''):
    raise SystemExit('FAIL: one platform evidence was not produced by Dart 3.13.2.')
print('PASS: Android/iOS compile evidence share canonical source + dependency lock + pinned toolchain.')
print('CANONICAL_SOURCE_SHA256=' + a['canonical_source_manifest']['sha256'])
print('PUBSPEC_LOCK_SHA256=' + a['pubspec_lock_sha256'])
