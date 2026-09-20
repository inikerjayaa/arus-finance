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

        receiver_block = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""
        if 'ScheduledNotificationReceiver' not in text:
            text = text.replace('</application>', receiver_block + '    </application>')

    manifest.write_text(text)

    xml = ROOT / 'android/app/src/main/res/xml'
    xml.mkdir(parents=True, exist_ok=True)
    (xml / 'backup_rules.xml').write_text(
        '''<?xml version="1.0" encoding="utf-8"?>\n<full-backup-content>\n    <exclude domain="root" path="."/>\n    <exclude domain="file" path="."/>\n    <exclude domain="database" path="."/>\n    <exclude domain="sharedpref" path="."/>\n    <exclude domain="external" path="."/>\n</full-backup-content>\n'''
    )
    (xml / 'data_extraction_rules.xml').write_text(
        '''<?xml version="1.0" encoding="utf-8"?>\n<data-extraction-rules>\n    <cloud-backup>\n        <exclude domain="root" path="."/>\n        <exclude domain="file" path="."/>\n        <exclude domain="database" path="."/>\n        <exclude domain="sharedpref" path="."/>\n        <exclude domain="external" path="."/>\n    </cloud-backup>\n    <device-transfer>\n        <exclude domain="root" path="."/>\n        <exclude domain="file" path="."/>\n        <exclude domain="database" path="."/>\n        <exclude domain="sharedpref" path="."/>\n        <exclude domain="external" path="."/>\n    </device-transfer>\n</data-extraction-rules>\n'''
    )

    gradle = ROOT / 'android/app/build.gradle.kts'
    if gradle.exists():
        g = gradle.read_text()
        g = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', g)
        g = re.sub(r'compileSdk\s*=\s*\d+', 'compileSdk = 36', g)
        g = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 36', g)
        g = re.sub(r'targetSdk\s*=\s*\d+', 'targetSdk = 36', g)
        g = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', g)
        g = re.sub(r'minSdk\s*=\s*\d+', 'minSdk = 24', g)
        g = g.replace('JavaVersion.VERSION_11', 'JavaVersion.VERSION_17')
        g = g.replace('JavaVersion.VERSION_1_8', 'JavaVersion.VERSION_17')
        g = re.sub(r'jvmTarget\s*=\s*"(?:1\.8|11)"', 'jvmTarget = "17"', g)

        if 'isCoreLibraryDesugaringEnabled = true' not in g:
            g = g.replace(
                'compileOptions {',
                'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
                1,
            )
        if 'multiDexEnabled = true' not in g and 'defaultConfig {' in g:
            g = g.replace('defaultConfig {', 'defaultConfig {\n        multiDexEnabled = true', 1)

        dependencies = [
            'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
            'implementation("androidx.appcompat:appcompat:1.8.0")',
        ]
        missing = [dep for dep in dependencies if dep not in g]
        if missing:
            if 'dependencies {' in g:
                insertion = 'dependencies {\n' + '\n'.join(f'    {dep}' for dep in missing)
                g = g.replace('dependencies {', insertion, 1)
            else:
                g += '\n\ndependencies {\n' + '\n'.join(f'    {dep}' for dep in missing) + '\n}\n'
        gradle.write_text(g)

    _patch_main_activity()
    _patch_launch_theme()


def patch_ios() -> None:
    plist = ROOT / 'ios/Runner/Info.plist'
    if plist.exists():
        with plist.open('rb') as f:
            data = plistlib.load(f)
        data['NSFaceIDUsageDescription'] = (
            'Gunakan Face ID untuk membuka data keuangan SAKU di perangkat ini.'
        )
        with plist.open('wb') as f:
            plistlib.dump(data, f, sort_keys=False)

    project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
    if project.exists():
        text = project.read_text()
        text = re.sub(
            r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[0-9.]+;',
            'IPHONEOS_DEPLOYMENT_TARGET = 15.0;',
            text,
        )
        project.write_text(text)

    podfile = ROOT / 'ios/Podfile'
    if podfile.exists():
        text = podfile.read_text()
        if re.search(r'^\s*platform\s*:ios\s*,', text, re.M):
            text = re.sub(
                r'^\s*platform\s*:ios\s*,\s*[\'\"][0-9.]+[\'\"]',
                "platform :ios, '15.0'",
                text,
                flags=re.M,
            )
        else:
            text = "platform :ios, '15.0'\n" + text
        podfile.write_text(text)


def main() -> None:
    patch_android()
    patch_ios()
    print('Native hardening applied (idempotent, biometric + reminder + opt-in runtime screen protection ready).')


if __name__ == '__main__':
    main()
