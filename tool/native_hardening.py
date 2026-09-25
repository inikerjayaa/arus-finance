"""Idempotent native-runner hardening after `flutter create`.

Production finance data remains local/device-owned. The hardener keeps raw OS
app-data backup/device transfer disabled and applies the native requirements of
SAKU's current security/reminder plugins.
"""
from pathlib import Path
import re
import plistlib

ROOT = Path(__file__).resolve().parents[1]


def _kotlin_import(text: str, value: str) -> str:
    marker = f'import {value}'
    if marker in text:
        return text
    package = re.search(r'^\s*package[^\n]*\n', text, re.M)
    if not package:
        raise RuntimeError('Kotlin MainActivity has no package declaration')
    return text[: package.end()] + marker + '\n' + text[package.end() :]


def _java_import(text: str, value: str) -> str:
    marker = f'import {value};'
    if marker in text:
        return text
    package = re.search(r'^\s*package[^;]*;\s*\n', text, re.M)
    if not package:
        raise RuntimeError('Java MainActivity has no package declaration')
    return text[: package.end()] + marker + '\n' + text[package.end() :]


def _patch_main_activity() -> None:
    android = ROOT / 'android/app/src/main'
    if not android.exists():
        return

    kotlin_class = '''class MainActivity : FlutterFragmentActivity() {
    private val screenProtectionChannel = "arus.finance/screen_protection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenProtectionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(true)
                "isDeviceLocked" -> {
                    val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                    result.success(keyguard.isDeviceLocked)
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "enabled boolean is required",
                            null,
                        )
                    } else {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
'''

    for path in list(android.rglob('MainActivity.kt')):
        text = path.read_text()
        text = text.replace(
            'import io.flutter.embedding.android.FlutterActivity',
            'import io.flutter.embedding.android.FlutterFragmentActivity',
        )
        text = re.sub(r'\bFlutterActivity\s*\(\)', 'FlutterFragmentActivity()', text)
        for value in [
            'android.app.KeyguardManager',
            'android.content.Context',
            'android.view.WindowManager',
            'io.flutter.embedding.android.FlutterFragmentActivity',
            'io.flutter.embedding.engine.FlutterEngine',
            'io.flutter.plugin.common.MethodChannel',
        ]:
            text = _kotlin_import(text, value)
        class_start = re.search(
            r'\bclass\s+MainActivity\s*:\s*FlutterFragmentActivity\(\)',
            text,
        )
        if not class_start:
            raise RuntimeError('Unsupported Kotlin MainActivity shape')
        path.write_text(text[: class_start.start()] + kotlin_class)

    java_class = '''public class MainActivity extends FlutterFragmentActivity {
    private static final String SCREEN_PROTECTION_CHANNEL = "arus.finance/screen_protection";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            SCREEN_PROTECTION_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "isSupported":
                    result.success(true);
                    break;
                case "isDeviceLocked":
                    KeyguardManager keyguard =
                        (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
                    result.success(keyguard != null && keyguard.isDeviceLocked());
                    break;
                case "setEnabled":
                    Boolean enabled = call.argument("enabled");
                    if (enabled == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "enabled boolean is required",
                            null
                        );
                    } else {
                        if (enabled) {
                            getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                        } else {
                            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                        }
                        result.success(true);
                    }
                    break;
                default:
                    result.notImplemented();
            }
        });
    }
}
'''

    for path in list(android.rglob('MainActivity.java')):
        text = path.read_text()
        text = text.replace(
            'import io.flutter.embedding.android.FlutterActivity;',
            'import io.flutter.embedding.android.FlutterFragmentActivity;',
        )
        text = re.sub(
            r'extends\s+FlutterActivity\b',
            'extends FlutterFragmentActivity',
            text,
        )
        for value in [
            'android.app.KeyguardManager',
            'android.content.Context',
            'android.view.WindowManager',
            'io.flutter.embedding.android.FlutterFragmentActivity',
            'io.flutter.embedding.engine.FlutterEngine',
            'io.flutter.plugin.common.MethodChannel',
        ]:
            text = _java_import(text, value)
        class_start = re.search(
            r'\bpublic\s+class\s+MainActivity\s+extends\s+FlutterFragmentActivity',
            text,
        )
        if not class_start:
            raise RuntimeError('Unsupported Java MainActivity shape')
        path.write_text(text[: class_start.start()] + java_class)


def _patch_launch_theme() -> None:
    res = ROOT / 'android/app/src/main/res'
    if not res.exists():
        return
    for styles in res.glob('values*/styles.xml'):
        text = styles.read_text()
        text = re.sub(
            r'(<style\s+name="LaunchTheme"\s+parent=")[^"]+("[^>]*>)',
            r'\1Theme.AppCompat.DayNight\2',
            text,
        )
        styles.write_text(text)


def patch_android() -> None:
    manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
    if not manifest.exists():
        return
    text = manifest.read_text()

    manifest_match = re.search(r'<manifest\b[^>]*>', text, re.S)
    if not manifest_match:
        raise RuntimeError('AndroidManifest.xml has no <manifest> root tag')
    permissions = [
        'android.permission.USE_BIOMETRIC',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
    ]
    additions = []
    for permission in permissions:
        marker = f'<uses-permission android:name="{permission}"/>'
        if marker not in text:
            additions.append('    ' + marker)
    if additions:
        text = (
            text[: manifest_match.end()]
            + '\n'
            + '\n'.join(additions)
            + text[manifest_match.end() :]
        )

    if '<application' in text:
        tag = re.search(r'<application\b[^>]*>', text, re.S)
        if tag:
            app = tag.group(0)
            attrs = {
                'android:allowBackup': 'false',
                'android:fullBackupContent': '@xml/backup_rules',
                'android:dataExtractionRules': '@xml/data_extraction_rules',
            }
            for key, value in attrs.items():
                if re.search(rf'\s{re.escape(key)}="[^"]*"', app):
                    app = re.sub(
                        rf'\s{re.escape(key)}="[^"]*"',
                        f' {key}="{value}"',
                        app,
                    )
                else:
                    app = app[:-1] + f' {key}="{value}">'
            text = text[: tag.start()] + app + text[tag.end() :]

    manifest.write_text(text)
    _patch_main_activity()
    _patch_launch_theme()


def patch_ios() -> None:
    info = ROOT / 'ios/Runner/Info.plist'
    if not info.exists():
        return
    with info.open('rb') as fh:
        data = plistlib.load(fh)
    data.setdefault(
        'NSFaceIDUsageDescription',
        'Gunakan Face ID untuk membuka data keuangan SAKU yang tersimpan lokal di perangkat Anda.',
    )
    with info.open('wb') as fh:
        plistlib.dump(data, fh, sort_keys=False)


def main() -> None:
    patch_android()
    patch_ios()


if __name__ == '__main__':
    main()
