"""V16 source contract: truthful native gates + deterministic first-build preparation."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text()

bootstrap = read('bootstrap.sh')
compile_gate = read('tool/native_compile_gate.sh')
release_gate = read('tool/native_release_gate.sh')
preflight = read('tool/native_toolchain_preflight.sh')
configure_signing = read('tool/configure_android_release_signing.py')
verify_signing = read('tool/verify_android_release_signing.py')
lock_gate = read('lib/features/settings/lock_gate.dart')
gitignore = read('.gitignore')
setup = read('docs/NATIVE_SETUP.md')
validation = read('docs/NATIVE_VALIDATION_MATRIX.md')

checks = {
    'bootstrap stages flutter create outside canonical source tree': 'mktemp -d' in bootstrap and '$TMP_ROOT/arus_native_shell' in bootstrap,
    'bootstrap copies only native shells back': 'cp -a "$TMP_ROOT/arus_native_shell/android"' in bootstrap and 'cp -a "$TMP_ROOT/arus_native_shell/ios"' in bootstrap,
    'bootstrap refuses accidental native overwrite': 'ARUS_REGENERATE_NATIVE' in bootstrap and 'fail-closed' in bootstrap,
    'bootstrap proves lockfile creation': '[[ -f pubspec.lock ]]' in bootstrap,
    'compile gate is explicitly non-store claim': 'not a store-signing claim' in compile_gate,
    'compile gate uses exact dependency lock': 'flutter pub get --enforce-lockfile' in compile_gate,
    'compile gate requires real analyzer/tests': 'flutter analyze' in compile_gate and 'flutter test' in compile_gate,
    'platform-specific gates require only selected native shell': '[[ -d android ]]' in compile_gate and '[[ -d ios ]]' in compile_gate and '[[ -d android ]]' in release_gate and '[[ -d ios ]]' in release_gate,
    'compile gate Android release-mode build retained': 'flutter build appbundle --release' in compile_gate,
    'compile gate iOS no-codesign build retained': 'flutter build ios --release --no-codesign' in compile_gate,
    'release all cannot silently skip iOS': "'all' memerlukan macOS" in release_gate and 'SKIP:' not in release_gate,
    'release gate requires Android signing verifier': 'verify_android_release_signing.py' in release_gate,
    'release gate requires signed iOS IPA path': 'flutter build ipa --release' in release_gate and 'flutter build ios --release --no-codesign' not in release_gate,
    'Android signing config follows local key.properties model': 'rootProject.file("key.properties")' in configure_signing,
    'Android signing config never embeds passwords': 'storePassword = "' not in configure_signing and 'keyPassword = "' not in configure_signing,
    'Android signing patch replaces debug release signing': 'signingConfigs.getByName("debug")' in configure_signing and 'signingConfigs.getByName("release")' in configure_signing,
    'Android signing verifier requires all credential metadata': all(x in verify_signing for x in ['storePassword', 'keyPassword', 'keyAlias', 'storeFile']),
    'Android signing verifier requires keystore file existence': 'store.exists()' in verify_signing,
    'Android signing verifier rejects debug signing': 'release build masih memakai debug signing' in verify_signing,
    'signing metadata is excluded from source control': 'android/key.properties' in gitignore,
    'toolchain preflight requires exact pinned Dart 3.13.2': 'DART_PIN_FILE' in preflight and 'Dart harus tepat $PINNED_DART' in preflight,
    'toolchain preflight requires JDK17': 'JDK 17' in preflight and 'JAVA_MAJOR' in preflight,
    'toolchain preflight requires Android API36': 'platforms/android-36' in preflight,
    'toolchain preflight requires macOS Xcode26 CocoaPods': all(x in preflight for x in ['Xcode 26+', 'CocoaPods', 'uname -s']),
    'lock screen biometric action is enrollment-gated in UI': '_biometricAvailable' in lock_gate and 'if (_biometricAvailable)' in lock_gate,
    'lock screen refreshes actual biometric enrollment': lock_gate.count('canUseBiometrics()') >= 2,
    'native setup separates compile and store release proof': 'Compile gate' in setup and 'Store-release gate' in setup,
    'native setup documents Android upload signing': 'key.properties' in setup and 'configure_android_release_signing.py' in setup,
    'device matrix covers biometric lifecycle': 'BIOMETRIC' in validation and 'background' in validation.lower(),
    'device matrix covers reboot reminders': 'REBOOT' in validation,
    'device matrix covers recovery and storage full': 'STORAGE_FULL' in validation and 'RECOVERY' in validation,
    'device matrix forbids production claim on partial gates': 'NO PARTIAL PASS' in validation,
}
failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: V16 truthful native gate contract')
    for name in failed:
        print(' -', name)
    raise SystemExit(1)
print(f'PASS: deep-mine V16 truthful native gate contract ({len(checks)} source checks)')
