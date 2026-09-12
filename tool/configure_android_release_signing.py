"""Idempotently patch generated Flutter Kotlin Gradle for Android release signing.

Secrets are never stored here. The developer creates android/key.properties locally.
This follows Flutter's documented Kotlin DSL release-signing pattern.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / 'android/app/build.gradle.kts'


def find_block(text: str, marker: str, start: int = 0):
    pos = text.find(marker, start)
    if pos < 0:
        return None
    brace = text.find('{', pos + len(marker) - 1)
    if brace < 0:
        return None
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return pos, brace, i
    return None


def main() -> None:
    if not GRADLE.exists():
        raise SystemExit('FAIL: android/app/build.gradle.kts belum ada. Jalankan bootstrap terlebih dahulu.')
    text = GRADLE.read_text()

    imports = ['import java.io.FileInputStream', 'import java.util.Properties']
    if any(line not in text for line in imports):
        prefix = ''.join(line + '\n' for line in imports if line not in text)
        text = prefix + text

    loader = '''\nval keystoreProperties = Properties()\nval keystorePropertiesFile = rootProject.file("key.properties")\nif (keystorePropertiesFile.exists()) {\n    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n}\n\n'''
    if 'val keystoreProperties = Properties()' not in text:
        plugins = text.find('plugins {')
        if plugins < 0:
            raise SystemExit('FAIL: blok plugins Kotlin Gradle tidak ditemukan.')
        # Insert after the plugins block, where top-level vals are valid.
        pblock = find_block(text, 'plugins {', plugins)
        if pblock is None:
            raise SystemExit('FAIL: blok plugins Kotlin Gradle rusak.')
        text = text[:pblock[2] + 1] + loader + text[pblock[2] + 1:]

    android = find_block(text, 'android {')
    if android is None:
        raise SystemExit('FAIL: blok android Kotlin Gradle tidak ditemukan.')

    if 'create("release")' not in text[android[1]:android[2] + 1]:
        signing = '''\n    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties.getProperty("keyAlias")\n            keyPassword = keystoreProperties.getProperty("keyPassword")\n            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }\n            storePassword = keystoreProperties.getProperty("storePassword")\n        }\n    }\n\n'''
        build_types_pos = text.find('buildTypes {', android[1], android[2])
        if build_types_pos < 0:
            raise SystemExit('FAIL: blok buildTypes Kotlin Gradle tidak ditemukan.')
        text = text[:build_types_pos] + signing + text[build_types_pos:]

    # Recompute blocks after mutation.
    android = find_block(text, 'android {')
    build_types = find_block(text, 'buildTypes {', android[1] if android else 0)
    if build_types is None:
        raise SystemExit('FAIL: blok buildTypes Kotlin Gradle tidak ditemukan setelah patch.')
    release = find_block(text, 'release {', build_types[1])
    if release is None or release[2] > build_types[2]:
        raise SystemExit('FAIL: blok release Kotlin Gradle tidak ditemukan.')
    release_text = text[release[1] + 1:release[2]]
    release_text = release_text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )
    if 'signingConfig = signingConfigs.getByName("release")' not in release_text:
        release_text = '\n            signingConfig = signingConfigs.getByName("release")' + release_text
    text = text[:release[1] + 1] + release_text + text[release[2]:]

    GRADLE.write_text(text)
    print('PASS: Android release signing Gradle contract configured (secrets remain local in android/key.properties).')


if __name__ == '__main__':
    main()
