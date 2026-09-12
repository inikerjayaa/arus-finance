"""Executable fixture for Android signing patch/verifier using a real temporary keystore."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
keytool = shutil.which('keytool')
if not keytool:
    raise SystemExit('FAIL: reference signing audit requires JDK keytool')

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    (root / 'tool').mkdir(parents=True)
    for name in ('configure_android_release_signing.py', 'verify_android_release_signing.py'):
        shutil.copy2(ROOT / 'tool' / name, root / 'tool' / name)

    gradle = root / 'android/app/build.gradle.kts'
    gradle.parent.mkdir(parents=True)
    gradle.write_text('''plugins {\n    id("com.android.application")\n}\n\nandroid {\n    namespace = "com.arus.arus_finance"\n    defaultConfig {\n        applicationId = "com.arus.arus_finance"\n    }\n    buildTypes {\n        release {\n            signingConfig = signingConfigs.getByName("debug")\n        }\n    }\n}\n''')
    keystore = root / 'android/upload-keystore.jks'
    env = os.environ.copy()
    env['ARUS_FIXTURE_PASS'] = 'fixturepass123'
    subprocess.run([
        keytool, '-genkeypair', '-alias', 'upload', '-keyalg', 'RSA', '-keysize', '2048',
        '-validity', '3650', '-dname', 'CN=Arus Fixture,O=Arus,C=ID',
        '-keystore', str(keystore), '-storetype', 'JKS',
        '-storepass:env', 'ARUS_FIXTURE_PASS', '-keypass:env', 'ARUS_FIXTURE_PASS',
    ], check=True, capture_output=True, text=True, env=env)
    (root / 'android/key.properties').write_text('''storePassword=fixturepass123\nkeyPassword=fixturepass123\nkeyAlias=upload\nstoreFile=upload-keystore.jks\n''')

    for _ in range(2):
        subprocess.run(['python3', str(root / 'tool/configure_android_release_signing.py')], check=True, capture_output=True, text=True)

    text = gradle.read_text()
    assert text.count('import java.io.FileInputStream') == 1
    assert text.count('import java.util.Properties') == 1
    assert text.count('val keystoreProperties = Properties()') == 1
    assert text.count('create("release")') == 1
    assert text.count('signingConfig = signingConfigs.getByName("release")') == 1
    assert 'signingConfig = signingConfigs.getByName("debug")' not in text

    ok = subprocess.run(['python3', str(root / 'tool/verify_android_release_signing.py')], check=True, capture_output=True, text=True)
    assert 'keytool-verified' in ok.stdout
    assert 'CERT_SHA256=' in ok.stdout

    # Wrong alias must fail closed even though the keystore file itself is valid.
    props = root / 'android/key.properties'
    props.write_text(props.read_text().replace('keyAlias=upload', 'keyAlias=missing'))
    failed_alias = subprocess.run(['python3', str(root / 'tool/verify_android_release_signing.py')], capture_output=True, text=True)
    assert failed_alias.returncode != 0
    assert 'keytool' in (failed_alias.stdout + failed_alias.stderr)

    # Missing credentials must fail closed.
    props.unlink()
    failed = subprocess.run(['python3', str(root / 'tool/verify_android_release_signing.py')], capture_output=True, text=True)
    assert failed.returncode != 0
    assert 'key.properties' in (failed.stdout + failed.stderr)

print('PASS: Android release signing fixture uses real keystore + alias proof + idempotent fail-closed checks')
