"""V17 source contract: reproducible native execution handoff + modern iOS baseline."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text()
preflight = read('tool/native_toolchain_preflight.sh')
compile_gate = read('tool/native_compile_gate.sh')
release_gate = read('tool/native_release_gate.sh')
evidence = read('tool/capture_native_evidence.py')
ios_verify = read('tool/verify_ios_modern_contract.py')
signing = read('tool/verify_android_release_signing.py')
pubspec = read('pubspec.yaml')
pin = read('toolchain/flutter_version.txt').strip()
setup = read('docs/NATIVE_SETUP.md')

checks = {
    'Flutter toolchain is explicitly pinned to 3.47.2': pin == '3.47.2',
    'preflight enforces exact Flutter pin': 'Flutter harus tepat $PINNED_FLUTTER' in preflight,
    'Dart is exactly pinned to 3.13.2': 'DART_PIN_FILE' in preflight and 'Dart harus tepat $PINNED_DART' in preflight,
    'SwiftPM explicitly enabled in project config': 'enable-swift-package-manager: true' in pubspec,
    'iOS preflight is SwiftPM-first': 'Swift Package Manager path' in preflight and 'SwiftPM-first' in preflight,
    'CocoaPods is conditional on actual Podfile fallback': 'if [[ -f ios/Podfile ]]' in preflight and 'command -v pod' in preflight,
    'iOS build gets UIScene post-build verifier': 'verify_ios_modern_contract.py' in compile_gate and 'verify_ios_modern_contract.py' in release_gate,
    'UIScene verifier requires real scene manifest': 'UIApplicationSceneManifest' in ios_verify and '_UIApplicationSceneManifest' in ios_verify,
    'iOS verifier retains Face ID and current iOS15 floor': 'NSFaceIDUsageDescription' in ios_verify and 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in ios_verify,
    'compile artifacts must exist before PASS': 'expected Android AAB artifact missing' in compile_gate and 'expected iOS Runner.app artifact missing' in compile_gate,
    'store IPA must exist before PASS': 'signed IPA artifact tidak ditemukan' in release_gate,
    'native evidence is emitted for all four proof kinds': all(k in evidence for k in ['android-compile','ios-compile','android-release','ios-release']),
    'native evidence hashes artifact and source manifest': 'artifact_hash' in evidence and 'source_manifest_hash' in evidence and 'pubspec_lock_sha256' in evidence,
    'native evidence excludes signing secrets': "EXCLUDED_NAMES = {'key.properties'}" in evidence and "EXCLUDED_SUFFIXES = {'.jks', '.keystore'}" in evidence,
    'Android signing verifier invokes keytool privately': '-storepass:env' in signing and 'ARUS_KEYSTORE_STOREPASS' in signing,
    'Android signing requires PrivateKeyEntry': 'PrivateKeyEntry' in signing,
    'native setup documents pinned Flutter': 'Flutter 3.47.2' in setup,
    'native setup documents SwiftPM-first': 'Swift Package Manager' in setup and 'Podfile' in setup,
    'V17 executable fixture retained': (ROOT / 'tool/reference_v17_native_execution_audit.py').exists(),
    'V17 milestone report retained': (ROOT / 'docs/BUG_HUNT_LOCAL_ONLY_V17_REPORT.md').exists(),
    'V17 native execution handoff retained': (ROOT / 'docs/NATIVE_EXECUTION_HANDOFF.md').exists(),
}
failed = [k for k,v in checks.items() if not v]
if failed:
    print('FAIL: V17 native execution contract')
    for x in failed: print(' -', x)
    raise SystemExit(1)
print(f'PASS: deep-mine V17 native execution contract ({len(checks)} source checks)')
