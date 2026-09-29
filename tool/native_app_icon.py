"""Generate OS launcher renditions from the unchanged approved SAKU original."""
from __future__ import annotations
import json
from pathlib import Path
import shutil
from saku_artwork import STACKED, verify_originals, read_rgb, launcher_pixels, write_png

ROOT = Path(__file__).resolve().parents[1]
NOTURNO = (0x00, 0x16, 0x21)
ANDROID_XMLNS = "http:" + "//schemas.android.com/apk/res/android"

ANDROID_ADAPTIVE_FOREGROUND = f'''<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="{ANDROID_XMLNS}" android:inset="14%">
    <bitmap android:src="@drawable/saku_approved_launcher" android:gravity="fill" android:filter="true"/>
</inset>
'''
ANDROID_ADAPTIVE_ICON = f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="{ANDROID_XMLNS}">
    <background android:drawable="@color/saku_launcher_background"/>
    <foreground android:drawable="@drawable/saku_launcher_foreground"/>
</adaptive-icon>
'''
ANDROID_LAUNCHER_COLORS = '''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="saku_launcher_background">#001621</color></resources>
'''


def _write_png(path, size, source):
    write_png(path, size, launcher_pixels(source, size))


def patch_android():
    res = ROOT / "android/app/src/main/res"
    if not res.exists():
        return
    verify_originals(ROOT)
    source = read_rgb(ROOT / STACKED)
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        _write_png(res / f"mipmap-{density}/ic_launcher.png", size, source)
        shutil.copyfile(res / f"mipmap-{density}/ic_launcher.png", res / f"mipmap-{density}/ic_launcher_round.png")
    original = res / "drawable-nodpi/saku_approved_launcher.png"
    original.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / STACKED, original)
    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "saku_launcher_foreground.xml").write_text(ANDROID_ADAPTIVE_FOREGROUND)
    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "saku_launcher_colors.xml").write_text(ANDROID_LAUNCHER_COLORS)
    adaptive = res / "mipmap-anydpi-v26"
    adaptive.mkdir(parents=True, exist_ok=True)
    (adaptive / "ic_launcher.xml").write_text(ANDROID_ADAPTIVE_ICON)
    (adaptive / "ic_launcher_round.xml").write_text(ANDROID_ADAPTIVE_ICON)


def patch_ios():
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if not appicon.exists():
        return
    verify_originals(ROOT)
    source = read_rgb(ROOT / STACKED)
    for old in appicon.glob("*.png"):
        old.unlink()
    specs = [
        ("iphone", "20x20", "2x", 40),
        ("iphone", "20x20", "3x", 60),
        ("iphone", "29x29", "1x", 29),
        ("iphone", "29x29", "2x", 58),
        ("iphone", "29x29", "3x", 87),
        ("iphone", "40x40", "2x", 80),
        ("iphone", "40x40", "3x", 120),
        ("iphone", "60x60", "2x", 120),
        ("iphone", "60x60", "3x", 180),
        ("ipad", "20x20", "1x", 20),
        ("ipad", "20x20", "2x", 40),
        ("ipad", "29x29", "1x", 29),
        ("ipad", "29x29", "2x", 58),
        ("ipad", "40x40", "1x", 40),
        ("ipad", "40x40", "2x", 80),
        ("ipad", "76x76", "1x", 76),
        ("ipad", "76x76", "2x", 152),
        ("ipad", "83.5x83.5", "2x", 167),
        ("ios-marketing", "1024x1024", "1x", 1024),
    ]
    images = []
    cache = {}
    for index, (idiom, logical_size, scale, pixels) in enumerate(specs):
        filename = f"SAKU-AppIcon-{index:02d}-{pixels}.png"
        if pixels not in cache:
            cache[pixels] = launcher_pixels(source, pixels)
        write_png(appicon / filename, pixels, cache[pixels])
        images.append({"filename": filename, "idiom": idiom, "scale": scale, "size": logical_size})
    (appicon / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def main():
    patch_android()
    patch_ios()
    print("Native SAKU launcher resources use the hash-verified approved original.")


if __name__ == "__main__":
    main()
