"""Executable fixtures for V17 pinned toolchain, SwiftPM-first preflight, iOS modern contract, and evidence hygiene."""
from pathlib import Path
import json
import os
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def write_exec(path: Path, body: str) -> None:
    path.write_text('#!/usr/bin/env bash\nset -e\n' + body)
    path.chmod(0o755)

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    (root / 'tool').mkdir()
    (root / 'toolchain').mkdir()
    shutil.copy2(ROOT / 'tool/native_toolchain_preflight.sh', root / 'tool/native_toolchain_preflight.sh')
    (root / 'toolchain/flutter_version.txt').write_text('3.47.2\n')
    (root / 'toolchain/dart_version.txt').write_text('3.13.2\n')
    (root / 'pubspec.yaml').write_text('''name: fixture\nenvironment:\n  sdk: ">=3.12.0 <4.0.0"\nflutter:\n  config:\n    enable-swift-package-manager: true\n''')

    fake = root / 'fakebin'
    fake.mkdir()
    write_exec(fake / 'flutter', 'echo "Flutter ${ARUS_FAKE_FLUTTER_VERSION:-3.47.2} • channel stable"\n')
    write_exec(fake / 'dart', 'echo "Dart SDK version: 3.13.2 (stable)" >&2\n')
    write_exec(fake / 'java', 'echo "openjdk version \\"17.0.13\\"" >&2\n')
    write_exec(fake / 'xcodebuild', 'printf "Xcode 26.0\\nBuild version 17A000\\n"\n')
    write_exec(fake / 'uname', 'echo Darwin\n')
    env = os.environ.copy()
    env['PATH'] = str(fake) + os.pathsep + env['PATH']

    # Exact Flutter pin is accepted, nearby version is rejected.
    ok = subprocess.run(['bash', 'tool/native_toolchain_preflight.sh', 'bootstrap'], cwd=root, env=env, capture_output=True, text=True)
    assert ok.returncode == 0, ok.stdout + ok.stderr
    bad_env = env.copy(); bad_env['ARUS_FAKE_FLUTTER_VERSION'] = '3.47.1'
    bad = subprocess.run(['bash', 'tool/native_toolchain_preflight.sh', 'bootstrap'], cwd=root, env=bad_env, capture_output=True, text=True)
    assert bad.returncode != 0 and 'tepat 3.47.2' in (bad.stdout + bad.stderr)

    # Android requires API36 and JDK17, but not an iOS shell.
    sdk = root / 'android-sdk'
    (sdk / 'platforms/android-36').mkdir(parents=True)
    (sdk / 'build-tools/36.0.0').mkdir(parents=True)
    android_env = env.copy(); android_env['ANDROID_SDK_ROOT'] = str(sdk)
    android = subprocess.run(['bash', 'tool/native_toolchain_preflight.sh', 'android'], cwd=root, env=android_env, capture_output=True, text=True)
    assert android.returncode == 0, android.stdout + android.stderr

    # iOS SwiftPM-first path must not require CocoaPods when there is no Podfile.
    ios = subprocess.run(['bash', 'tool/native_toolchain_preflight.sh', 'ios'], cwd=root, env=env, capture_output=True, text=True)
    assert ios.returncode == 0 and 'Swift Package Manager path' in ios.stdout, ios.stdout + ios.stderr

    # But a real Podfile fallback must require `pod`.
    (root / 'ios').mkdir()
    (root / 'ios/Podfile').write_text("platform :ios, '15.0'\n")
    no_pod = subprocess.run(['bash', 'tool/native_toolchain_preflight.sh', 'ios'], cwd=root, env=env, capture_output=True, text=True)
    assert no_pod.returncode != 0 and 'CocoaPods' in (no_pod.stdout + no_pod.stderr)
    write_exec(fake / 'pod', 'echo 1.16.2\n')
    pod_ok = subprocess.run(['bash', 'tool/native_toolchain_preflight.sh', 'ios'], cwd=root, env=env, capture_output=True, text=True)
    assert pod_ok.returncode == 0 and 'fallback detected' in pod_ok.stdout

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    (root / 'tool').mkdir()
    shutil.copy2(ROOT / 'tool/verify_ios_modern_contract.py', root / 'tool/verify_ios_modern_contract.py')
    (root / 'pubspec.yaml').write_text('''name: fixture\nflutter:\n  config:\n    enable-swift-package-manager: true\n''')
    plist = root / 'ios/Runner/Info.plist'
    plist.parent.mkdir(parents=True)
    with plist.open('wb') as f:
        plistlib.dump({
            'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False},
            'NSFaceIDUsageDescription': 'Face ID fixture',
        }, f)
    proj = root / 'ios/Runner.xcodeproj/project.pbxproj'
    proj.parent.mkdir(parents=True)
    proj.write_text('IPHONEOS_DEPLOYMENT_TARGET = 15.0;\n')
    ok = subprocess.run(['python3', 'tool/verify_ios_modern_contract.py'], cwd=root, capture_output=True, text=True)
    assert ok.returncode == 0, ok.stdout + ok.stderr
    with plist.open('wb') as f:
        plistlib.dump({'NSFaceIDUsageDescription': 'Face ID fixture'}, f)
    bad = subprocess.run(['python3', 'tool/verify_ios_modern_contract.py'], cwd=root, capture_output=True, text=True)
    assert bad.returncode != 0 and 'UIApplicationSceneManifest' in (bad.stdout + bad.stderr)

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    (root / 'tool').mkdir()
    shutil.copy2(ROOT / 'tool/capture_native_evidence.py', root / 'tool/capture_native_evidence.py')
    (root / 'lib').mkdir(); (root / 'lib/main.dart').write_text('void main() {}\n')
    (root / 'pubspec.yaml').write_text('name: fixture\n')
    (root / 'pubspec.lock').write_text('packages: {}\n')
    (root / 'toolchain').mkdir(); (root / 'toolchain/flutter_version.txt').write_text('3.47.2\n')
    (root / 'android').mkdir(); (root / 'android/key.properties').write_text('storePassword=TOP_SECRET_A\n')
    (root / 'android/upload.jks').write_text('TOP_SECRET_KEYSTORE\n')
    artifact = root / 'artifact.aab'; artifact.write_bytes(b'fixture artifact')
    fake = root / 'fakebin'; fake.mkdir()
    write_exec(fake / 'flutter', 'echo "Flutter 3.47.2 • channel stable"\n')
    write_exec(fake / 'dart', 'echo "Dart SDK version: 3.13.2 (stable)" >&2\n')
    write_exec(fake / 'java', 'echo "openjdk version \\"17.0.13\\"" >&2\n')
    env = os.environ.copy(); env['PATH'] = str(fake) + os.pathsep + env['PATH']
    r1 = subprocess.run(['python3','tool/capture_native_evidence.py','--kind','android-compile','--artifact','artifact.aab'], cwd=root, env=env, capture_output=True, text=True)
    assert r1.returncode == 0, r1.stdout + r1.stderr
    evpath = root / 'build/arus_evidence/android-compile.json'
    one = json.loads(evpath.read_text())
    raw = evpath.read_text()
    assert 'TOP_SECRET' not in raw
    first_manifest = one['source_manifest']['sha256']
    (root / 'android/key.properties').write_text('storePassword=TOP_SECRET_B\n')
    r2 = subprocess.run(['python3','tool/capture_native_evidence.py','--kind','android-compile','--artifact','artifact.aab'], cwd=root, env=env, capture_output=True, text=True)
    assert r2.returncode == 0
    two = json.loads(evpath.read_text())
    assert two['source_manifest']['sha256'] == first_manifest
    assert two['artifact']['sha256'] == one['artifact']['sha256']

print('PASS: V17 native execution fixtures — pinned Flutter, SwiftPM fallback logic, UIScene verifier, secret-free build evidence')
