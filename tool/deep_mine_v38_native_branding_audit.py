#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = (ROOT / 'bootstrap.sh').read_text()
BRANDING = (ROOT / 'tool/native_branding.py').read_text()

checks = {
    'bootstrap preserves internal org identity': '--org com.arus' in BOOTSTRAP,
    'bootstrap preserves internal Flutter project identity': '--project-name arus_finance' in BOOTSTRAP,
    'bootstrap applies hardening before branding': BOOTSTRAP.find('python3 tool/native_hardening.py') < BOOTSTRAP.find('python3 tool/native_branding.py'),
    'bootstrap invokes native branding': 'python3 tool/native_branding.py' in BOOTSTRAP,
    'native branding pins visible app name to SAKU': 'APP_NAME = "SAKU"' in BRANDING,
    'Android visible app label is sourced from SAKU app name': '_set_android_attr(app, "android:label", APP_NAME)' in BRANDING,
    'Android standard launcher binding is explicit': '_set_android_attr(app, "android:icon", "@mipmap/ic_launcher")' in BRANDING,
    'Android round launcher binding is explicit': '_set_android_attr(app, "android:roundIcon", "@mipmap/ic_launcher_round")' in BRANDING,
    'iOS display name is SAKU': 'data["CFBundleDisplayName"] = APP_NAME' in BRANDING,
    'iOS bundle visible name is SAKU': 'data["CFBundleName"] = APP_NAME' in BRANDING,
    'Face ID copy names SAKU': 'data keuangan SAKU' in BRANDING,
}

manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    generated = manifest.read_text()
    checks.update({
        'generated Android manifest label is SAKU': 'android:label="SAKU"' in generated,
        'generated Android manifest uses SAKU launcher resource': 'android:icon="@mipmap/ic_launcher"' in generated,
        'generated Android manifest uses SAKU round launcher resource': 'android:roundIcon="@mipmap/ic_launcher_round"' in generated,
    })

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(f'V38 native branding audit failed: {len(failed)} check(s)')
print(f'PASS: V38 native branding audit {len(checks)}/{len(checks)}')
