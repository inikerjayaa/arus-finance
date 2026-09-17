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
    'Android visible app label is SAKU': 'android:label="{APP_NAME}"' in BRANDING,
    'iOS display name is SAKU': 'data["CFBundleDisplayName"] = APP_NAME' in BRANDING,
    'iOS bundle visible name is SAKU': 'data["CFBundleName"] = APP_NAME' in BRANDING,
    'Face ID copy names SAKU': 'data keuangan SAKU' in BRANDING,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(f'V38 native branding audit failed: {len(failed)} check(s)')
print(f'PASS: V38 native branding audit {len(checks)}/{len(checks)}')
