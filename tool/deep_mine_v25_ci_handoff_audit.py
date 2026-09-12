#!/usr/bin/env python3
"""V25 source contract: official pinned SDK CI + current iOS support floor."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
read=lambda p:(ROOT/p).read_text()
workflow=read('.github/workflows/native-verify.yml')
installer=read('tool/install_pinned_flutter_ci.py')
preflight=read('tool/native_toolchain_preflight.sh')
hardener=read('tool/native_hardening.py')
ios_verify=read('tool/verify_ios_modern_contract.py')
evidence=read('tool/capture_native_evidence.py')
bootstrap=read('bootstrap.sh')
pin=json.loads(read('toolchain/flutter_release_pin.json'))
setup=read('docs/NATIVE_SETUP.md')

checks={
 'official Flutter version pinned': pin['flutter_version']=='3.47.2' and pin['release_hash']=='d3b14c876900e553bc736ca19295fc09e3853e8e',
 'bundled Dart version pinned': pin['dart_version']=='3.13.2' and read('toolchain/dart_version.txt').strip()=='3.13.2',
 'official Linux SHA pin retained': pin['linux_x64_sha256']=='447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185',
 'installer validates release hash': 'release git hash differs from Arus pin' in installer,
 'installer validates bundled Dart': 'bundled Dart mismatch' in installer,
 'installer validates archive SHA256': 'Flutter SDK SHA-256 mismatch' in installer,
 'installer uses safe extraction': 'filter="data"' in installer and 'unsafe zip member' in installer,
 'preflight enforces exact Dart pin': 'DART_PIN_FILE' in preflight and 'Dart harus tepat $PINNED_DART' in preflight,
 'bootstrap enforces supplied lockfile': 'flutter pub get --enforce-lockfile' in bootstrap,
 'compile CI has no signing secrets': '${{ secrets.' not in workflow,
 'compile CI uses normal PR not privileged PR target': 'pull_request:' in workflow and 'pull_request_target' not in workflow,
 'compile CI permissions read-only': 'contents: read' in workflow,
 'compile CI shares one committed lockfile': 'arus-pubspec-lock-v26' in workflow and workflow.count('arus-pubspec-lock-v26') >= 3 and 'flutter pub get --enforce-lockfile' in workflow,
 'Android compile CI uses API36 helper': 'ensure_android_sdk_36_ci.sh' in workflow and 'native_compile_gate.sh android' in workflow,
 'iOS compile CI uses macOS26': 'runs-on: macos-26' in workflow and 'native_compile_gate.sh ios' in workflow,
 'cross-platform evidence verifier required': 'verify_ci_native_evidence.py' in workflow,
 'evidence v2 has canonical cross-platform hash': "'format': 'arus-native-evidence-v2'" in evidence and 'canonical_source_manifest' in evidence,
 'current iOS support floor is 15': 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in hardener and 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in ios_verify,
 'current docs say iOS15 floor': 'iOS 15.0+' in setup,
 'V25 CI handoff document retained': (ROOT/'docs/NATIVE_CI_HANDOFF_V25.md').exists(),
 'V25 reference audit retained': (ROOT/'tool/reference_v25_ci_handoff_audit.py').exists(),
}
failed=[k for k,v in checks.items() if not v]
if failed:
    print('FAIL: V25 native CI handoff contract')
    for x in failed: print(' -',x)
    raise SystemExit(1)
print(f'PASS: deep-mine V25 native CI handoff contract ({len(checks)} source checks)')
