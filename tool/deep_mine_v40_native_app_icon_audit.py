#!/usr/bin/env python3
"""Fail-closed source/generated-shell audit for SAKU launcher artwork."""
from __future__ import annotations

import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tool/native_app_icon.py"
BOOTSTRAP = ROOT / "bootstrap.sh"


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def png_meta(path: Path) -> tuple[int, int, int]:
    raw = path.read_bytes()
    if len(raw) < 26 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
        fail(f"invalid PNG: {path.relative_to(ROOT)}")
    width, height = struct.unpack(">II", raw[16:24])
    color_type = raw[25]
    return width, height, color_type


def source_audit() -> None:
    if not GENERATOR.exists():
        fail("tool/native_app_icon.py missing")
    source = GENERATOR.read_text()
    required = [
        "NOTURNO = (0x00, 0x16, 0x21)",
        "VULCANICO = (0xFF, 0x41, 0x03)",
        'mipmap-{density}/ic_launcher.png',
        'mipmap-{density}/ic_launcher_round.png',
        "ANDROID_ADAPTIVE_FOREGROUND",
        "mipmap-anydpi-v26",
        "saku_launcher_background",
        'android:scaleX="0.72"',
        "AppIcon.appiconset",
        "ios-marketing",
        "1024x1024",
        "zlib.compress",
    ]
    for token in required:
        if token not in source:
            fail(f"launcher generator missing source invariant: {token}")
    lowered = source.lower()
    for forbidden in ("http://", "https://", "requests.", "urllib.", "pillow", "pil."):
        if forbidden in lowered:
            fail(f"launcher generator must remain standard-library/local: {forbidden}")

    bootstrap = BOOTSTRAP.read_text()
    splash = bootstrap.find("python3 tool/native_splash.py")
    app_icon = bootstrap.find("python3 tool/native_app_icon.py")
    audits = bootstrap.find("bash tool/run_all_audits.sh")
    if min(splash, app_icon, audits) < 0 or not splash < app_icon < audits:
        fail("bootstrap order must be native_splash -> native_app_icon -> audits")


def generated_android_audit() -> None:
    res = ROOT / "android/app/src/main/res"
    if not res.exists():
        return
    expected = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in expected.items():
        for filename in ("ic_launcher.png", "ic_launcher_round.png"):
            path = res / f"mipmap-{density}/{filename}"
            if not path.exists():
                fail(f"generated Android SAKU launcher icon missing: {path.relative_to(ROOT)}")
            width, height, color_type = png_meta(path)
            if (width, height) != (size, size):
                fail(f"Android launcher size mismatch for {density}/{filename}: {width}x{height}")
            if color_type != 2:
                fail(f"Android launcher must be opaque RGB PNG for {density}/{filename}")

    foreground = res / "drawable/saku_launcher_foreground.xml"
    colors = res / "values/saku_launcher_colors.xml"
    if not foreground.exists() or not colors.exists():
        fail("Android adaptive launcher foreground/background resources missing")
    foreground_text = foreground.read_text()
    if 'android:scaleX="0.72"' not in foreground_text or 'android:scaleY="0.72"' not in foreground_text:
        fail("Android adaptive launcher foreground must preserve 72% safe-area scale")
    if "#001621" not in colors.read_text():
        fail("Android adaptive launcher background must remain Noturno #001621")

    for filename in ("ic_launcher.xml", "ic_launcher_round.xml"):
        adaptive = res / f"mipmap-anydpi-v26/{filename}"
        if not adaptive.exists():
            fail(f"Android adaptive launcher XML missing: {adaptive.relative_to(ROOT)}")
        text = adaptive.read_text()
        if "@color/saku_launcher_background" not in text or "@drawable/saku_launcher_foreground" not in text:
            fail(f"Android adaptive launcher wiring invalid: {filename}")


def generated_ios_audit() -> None:
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if not appicon.exists():
        return
    contents = appicon / "Contents.json"
    if not contents.exists():
        fail("generated iOS AppIcon Contents.json missing")
    data = json.loads(contents.read_text())
    images = data.get("images")
    if not isinstance(images, list) or len(images) != 19:
        fail("generated iOS AppIcon must contain exactly 19 required slots")
    marketing = 0
    referenced: set[str] = set()
    for item in images:
        filename = item.get("filename")
        if not isinstance(filename, str) or not filename.startswith("SAKU-AppIcon-"):
            fail("iOS AppIcon contains non-SAKU launcher artwork")
        path = appicon / filename
        if not path.exists():
            fail(f"referenced iOS AppIcon missing: {filename}")
        width, height, color_type = png_meta(path)
        if width != height or color_type != 2:
            fail(f"iOS AppIcon must be square opaque RGB PNG: {filename}")
        referenced.add(filename)
        if item.get("idiom") == "ios-marketing":
            marketing += 1
            if item.get("size") != "1024x1024" or (width, height) != (1024, 1024):
                fail("iOS marketing icon must be 1024x1024")
    if marketing != 1:
        fail("iOS AppIcon must contain one ios-marketing slot")
    disk_pngs = {path.name for path in appicon.glob("*.png")}
    if disk_pngs != referenced:
        fail("unreferenced/template iOS launcher PNGs remain after SAKU generation")


def main() -> None:
    source_audit()
    generated_android_audit()
    generated_ios_audit()
    print("PASS: V40 native SAKU app-icon audit")


if __name__ == "__main__":
    main()
