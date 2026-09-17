"""Apply SAKU public branding to generated Android/iOS shells.

Internal package/project identity intentionally stays unchanged for now so the
upgrade path and local device data are not put at risk by a cosmetic rename.
"""
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]


def patch_android() -> None:
    manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
    if not manifest.exists():
        return
    text = manifest.read_text()
    application = re.search(r'<application\b[^>]*>', text, re.S)
    if not application:
        raise RuntimeError('AndroidManifest.xml has no <application> tag')
    tag = application.group(0)
    if re.search(r'\sandroid:label="[^"]*"', tag):
        tag = re.sub(r'\sandroid:label="[^"]*"', ' android:label="SAKU"', tag)
    else:
        tag = tag[:-1] + ' android:label="SAKU">'
    manifest.write_text(text[: application.start()] + tag + text[application.end() :])


def patch_ios() -> None:
    plist = ROOT / 'ios/Runner/Info.plist'
    if not plist.exists():
        return
    with plist.open('rb') as f:
        data = plistlib.load(f)
    data['CFBundleDisplayName'] = 'SAKU'
    data['NSFaceIDUsageDescription'] = (
        'Gunakan Face ID untuk membuka data keuangan SAKU di perangkat ini.'
    )
    with plist.open('wb') as f:
        plistlib.dump(data, f, sort_keys=False)


def main() -> None:
    patch_android()
    patch_ios()
    print('SAKU native public branding applied; package identity preserved.')


if __name__ == '__main__':
    main()
