"""Idempotence/contract audit for native_hardening.py using a disposable fixture."""
from pathlib import Path
import tempfile
import shutil
import subprocess
import plistlib

src = Path(__file__).resolve().parent / 'native_hardening.py'
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    (root / 'tool').mkdir()
    shutil.copy2(src, root / 'tool/native_hardening.py')

    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    manifest.parent.mkdir(parents=True)
    manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Arus">
        <activity android:name=".MainActivity" android:theme="@style/LaunchTheme"/>
    </application>
</manifest>''')

    main_activity = root / 'android/app/src/main/kotlin/com/arus/arus_finance/MainActivity.kt'
    main_activity.parent.mkdir(parents=True)
    main_activity.write_text('''package com.arus.arus_finance
import io.flutter.embedding.android.FlutterActivity
class MainActivity: FlutterActivity()
''')

    styles = root / 'android/app/src/main/res/values/styles.xml'
    styles.parent.mkdir(parents=True)
    styles.write_text('''<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>''')

    gradle = root / 'android/app/build.gradle.kts'
    gradle.parent.mkdir(parents=True, exist_ok=True)
    gradle.write_text('''android {
    compileSdk = flutter.compileSdkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
}
''')

    plist = root / 'ios/Runner/Info.plist'
    plist.parent.mkdir(parents=True)
    with plist.open('wb') as f:
        plistlib.dump({'CFBundleName': 'Arus'}, f)

    project = root / 'ios/Runner.xcodeproj/project.pbxproj'
    project.parent.mkdir(parents=True)
    project.write_text('''buildSettings = {
    IPHONEOS_DEPLOYMENT_TARGET = 12.0;
};''')

    podfile = root / 'ios/Podfile'
    podfile.write_text("# platform :ios, '12.0'\n")

    for _ in range(2):
        subprocess.run(
            ['python3', str(root / 'tool/native_hardening.py')],
            check=True,
            capture_output=True,
            text=True,
        )

    m = manifest.read_text()
    g = gradle.read_text()
    a = main_activity.read_text()
    st = styles.read_text()
    assert m.count('ScheduledNotificationReceiver') == 1
    assert m.count('ScheduledNotificationBootReceiver') == 1
    assert m.count('android.permission.POST_NOTIFICATIONS') == 1
    assert m.count('android.permission.RECEIVE_BOOT_COMPLETED') == 1
    assert m.count('android.permission.USE_BIOMETRIC') == 1
    assert 'SCHEDULE_EXACT_ALARM' not in m and 'USE_EXACT_ALARM' not in m
    assert 'android:allowBackup="false"' in m
    assert 'compileSdk = 36' in g and 'targetSdk = 36' in g and 'minSdk = 24' in g
    assert 'JavaVersion.VERSION_17' in g
    assert 'isCoreLibraryDesugaringEnabled = true' in g
    assert g.count('desugar_jdk_libs:2.1.4') == 1
    assert g.count('androidx.appcompat:appcompat:1.8.0') == 1
    assert 'FlutterFragmentActivity' in a and 'FlutterActivity\n' not in a
    assert a.count('arus.finance/screen_protection') == 1
    assert 'MethodChannel' in a and 'configureFlutterEngine' in a
    assert '"isSupported"' in a and '"setEnabled"' in a
    assert 'window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)' in a
    assert 'window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)' in a
    assert 'override fun onCreate' not in a
    assert 'parent="Theme.AppCompat.DayNight"' in st

    with plist.open('rb') as f:
        data = plistlib.load(f)
    assert data['NSFaceIDUsageDescription'].startswith('Gunakan Face ID untuk membuka data keuangan SAKU')
    assert 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in project.read_text()
    assert "platform :ios, '15.0'" in podfile.read_text()

print('PASS: native hardening fixture is idempotent + biometric/reminder/opt-in-screen-protection ready')
