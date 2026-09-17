"""Apply user-facing SAKU branding to generated Android/iOS shells.

Internal package/bundle/project identities stay unchanged for update and local-data
continuity. This patch only changes names and permission copy visible to users.
"""
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "SAKU"
FACE_ID_COPY = "Gunakan Face ID untuk membuka data keuangan SAKU di perangkat ini."


def patch_android() -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        return
    text = manifest.read_text()
    tag = re.search(r"<application\b[^>]*>", text, re.S)
    if not tag:
        raise RuntimeError("AndroidManifest.xml has no <application> tag")
    app = tag.group(0)
    if re.search(r'\sandroid:label="[^"]*"', app):
        app = re.sub(r'\sandroid:label="[^"]*"', f' android:label="{APP_NAME}"', app)
    else:
        app = app[:-1] + f' android:label="{APP_NAME}">'
    manifest.write_text(text[: tag.start()] + app + text[tag.end() :])


def patch_ios() -> None:
    plist = ROOT / "ios/Runner/Info.plist"
    if not plist.exists():
        return
    with plist.open("rb") as f:
        data = plistlib.load(f)
    data["CFBundleDisplayName"] = APP_NAME
    data["CFBundleName"] = APP_NAME
    data["NSFaceIDUsageDescription"] = FACE_ID_COPY
    with plist.open("wb") as f:
        plistlib.dump(data, f, sort_keys=False)


def main() -> None:
    patch_android()
    patch_ios()
    print("Native SAKU branding applied without changing internal app identity.")


if __name__ == "__main__":
    main()
