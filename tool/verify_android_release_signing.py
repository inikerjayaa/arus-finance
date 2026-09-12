"""Fail closed unless Android release signing is explicitly usable.

Does not print/store passwords. `keytool` receives the store password through an
environment variable and proves the requested alias is a PrivateKeyEntry.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
props_path = ROOT / 'android/key.properties'
gradle_path = ROOT / 'android/app/build.gradle.kts'

if not props_path.exists():
    raise SystemExit('FAIL: android/key.properties tidak ditemukan. Release AAB tidak boleh diklaim store-ready.')
if not gradle_path.exists():
    raise SystemExit('FAIL: android/app/build.gradle.kts tidak ditemukan.')

props = {}
for raw in props_path.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith('#') or '=' not in line:
        continue
    k, v = line.split('=', 1)
    props[k.strip()] = v.strip()
required = ('storePassword', 'keyPassword', 'keyAlias', 'storeFile')
missing = [k for k in required if not props.get(k)]
if missing:
    raise SystemExit('FAIL: android/key.properties belum lengkap: ' + ', '.join(missing))

store_raw = props['storeFile'].replace('\\\\', '\\')
store = Path(store_raw).expanduser()
if not store.is_absolute():
    candidates = [ROOT / 'android' / store, ROOT / 'android/app' / store]
    store = next((p for p in candidates if p.exists()), candidates[0])
if not store.exists() or not store.is_file():
    raise SystemExit('FAIL: upload keystore pada storeFile tidak ditemukan.')

text = gradle_path.read_text()
if 'create("release")' not in text:
    raise SystemExit('FAIL: signingConfigs release belum dikonfigurasi. Jalankan python3 tool/configure_android_release_signing.py')
if 'signingConfig = signingConfigs.getByName("release")' not in text:
    raise SystemExit('FAIL: buildTypes.release belum menggunakan signingConfigs release.')
match = re.search(r'release\s*\{(?P<body>.*?)\n\s*\}', text, re.S)
if match and 'signingConfigs.getByName("debug")' in match.group('body'):
    raise SystemExit('FAIL: release build masih memakai debug signing.')

keytool = shutil.which('keytool')
if not keytool:
    raise SystemExit('FAIL: keytool tidak ditemukan; JDK 17 signing proof belum tersedia.')
env = os.environ.copy()
env['ARUS_KEYSTORE_STOREPASS'] = props['storePassword']
probe = subprocess.run(
    [keytool, '-list', '-v', '-keystore', str(store), '-alias', props['keyAlias'], '-storepass:env', 'ARUS_KEYSTORE_STOREPASS'],
    capture_output=True,
    text=True,
    env=env,
    check=False,
)
# Do not forward raw keytool output because it is not needed for the gate.
if probe.returncode != 0:
    raise SystemExit('FAIL: keytool tidak dapat membuka keystore/alias dengan credential yang diberikan.')
combined = probe.stdout + '\n' + probe.stderr
if 'PrivateKeyEntry' not in combined:
    raise SystemExit('FAIL: alias signing bukan PrivateKeyEntry.')
fp = re.search(r'SHA-256\):\s*([0-9A-F:]+)', combined, re.I)
fingerprint = fp.group(1).upper() if fp else 'available-in-keytool'
print('PASS: Android upload/release signing is explicitly configured and keytool-verified; secrets were not printed.')
print('CERT_SHA256=' + fingerprint)
