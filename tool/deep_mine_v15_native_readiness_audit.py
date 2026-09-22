"""V15 source contract: native/device boundary hardening without claiming a real native build."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text()

pubspec = read('pubspec.yaml')
hardener = read('tool/native_hardening.py')
native_fixture = read('tool/reference_native_hardening_audit.py')
release_gate = read('tool/native_release_gate.sh')
compile_gate = read('tool/native_compile_gate.sh')
security = read('lib/core/services/security_service.dart')
db = read('lib/core/db/app_database.dart')
lock_gate = read('lib/features/settings/lock_gate.dart')
notifications = read('lib/core/services/local_notification_service.dart')
settings = read('lib/features/settings/settings_screen.dart')
setup = read('docs/NATIVE_SETUP.md')
future = read('future_optional/README.md')
lifecycle = lock_gate[
    lock_gate.index('void didChangeAppLifecycleState'):
    lock_gate.index('Future<void> _refreshPinStateOnResume')
]
reminder_settings = settings[
    settings.index('Future<void> _setReminders'):
    settings.index('Future<void> _setNotificationDetails')
]

checks = {
    'secure-storage minimum includes 11.1 fix line': 'flutter_secure_storage: ^11.1.0' in pubspec,
    'database secure storage fails closed on Android errors': 'AndroidOptions(resetOnError: false)' in db,
    'PIN secure storage fails closed on Android errors': 'AndroidOptions(resetOnError: false)' in security,
    'biometric availability keeps capability checks': 'isDeviceSupported()' in security and 'canCheckBiometrics' in security,
    'Android biometric availability tolerates OEM empty enrolled list': 'defaultTargetPlatform == TargetPlatform.android' in security and 'getAvailableBiometrics()' in security,
    'biometric authentication remains biometric-only': 'biometricOnly: true' in security,
    'lock gate tracks foreground lifecycle': 'bool _foreground = true;' in lock_gate,
    'lock gate prevents duplicate biometric prompts': 'bool _biometricInFlight = false;' in lock_gate,
    'lock gate uses lifecycle generation anti-race': 'int _lifecycleGeneration = 0;' in lock_gate and 'generation != _lifecycleGeneration' in lock_gate,
    # V49 physical UAT refined the lifecycle contract: inactive/hidden can be
    # transient system UI (screenshot, picker, biometric overlay) and therefore
    # must not arm authentication. A real paused/detached boundary still locks
    # synchronously and fail-closed; privacy shielding is tested separately.
    'lock gate locks synchronously on real background boundary': (
        'AppLifecycleState.paused' in lifecycle and
        'AppLifecycleState.detached' in lifecycle and
        '_authenticationBoundaryCrossed = true;' in lifecycle and
        '_locked = _hasPin;' in lifecycle and
        'await ' not in lifecycle
    ),
    'lock gate does not authenticate transient inactive/hidden': (
        'AppLifecycleState.inactive || state == AppLifecycleState.hidden' in lifecycle and
        'Do not mutate authentication' in lifecycle
    ),
    'notification timezone fails closed': 'Zona waktu perangkat tidak dapat dibaca' in notifications and 'tz.setLocalLocation(tz.UTC)' not in notifications,
    'notification init commits only after cleanup': notifications.index('await _cleanLegacyIdsOnce();') < notifications.index('_initialized = true;'),
    'settings catches reminder native failures': (
        'catch (' in reminder_settings and
        'await _reloadNotifications();' in reminder_settings and
        '_snack(context,' in reminder_settings
    ),
    'Android biometric permission retained': 'android.permission.USE_BIOMETRIC' in hardener,
    'Android API24 minimum enforced': "'minSdk = 24'" in hardener or 'minSdk = 24' in hardener,
    'Android API36 compile/target enforced': 'compileSdk = 36' in hardener and 'targetSdk = 36' in hardener,
    'Android FragmentActivity enforced': 'FlutterFragmentActivity' in hardener,
    'Android AppCompat launch theme enforced': 'Theme.AppCompat.DayNight' in hardener,
    'Android AppCompat stable dependency enforced': 'androidx.appcompat:appcompat:1.8.0' in hardener,
    'Android exact-alarm permission intentionally absent': 'SCHEDULE_EXACT_ALARM' not in hardener and 'USE_EXACT_ALARM' not in hardener,
    'Android app backup disabled': "'android:allowBackup': 'false'" in hardener,
    'iOS Face ID description enforced': 'NSFaceIDUsageDescription' in hardener,
    'current iOS 15 deployment floor enforced (V25 platform correction)': 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in hardener,
    'native fixture verifies FragmentActivity': 'FlutterFragmentActivity' in native_fixture,
    'native fixture verifies API floors': "'compileSdk = 36'" in native_fixture and "'minSdk = 24'" in native_fixture,
    'release gate requires lockfile': 'pubspec.lock is missing' in release_gate,
    'release gate enforces dependency lock': 'flutter pub get --enforce-lockfile' in release_gate,
    'release gate runs analyzer/tests': 'flutter analyze' in release_gate and 'flutter test' in release_gate,
    'native gates retain Android AAB path': 'flutter build appbundle --release' in release_gate and 'flutter build appbundle --release' in compile_gate,
    'native gates retain iOS compile/release paths': 'flutter build ios --release --no-codesign' in compile_gate and 'flutter build ipa --release' in release_gate,
    'current Play API36 requirement documented': 'Android 16 / API 36+' in setup,
    'current Apple Xcode26/iOS26 requirement documented': 'Xcode 26+' in setup and 'iOS 26 SDK+' in setup,
    'empty-folder continuity replaced by file sentinel': '100% local-first/device-owned' in future,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: V15 native readiness contract')
    for name in failed:
        print(' -', name)
    raise SystemExit(1)
print(f'PASS: deep-mine V15 native readiness contract ({len(checks)} source checks)')
