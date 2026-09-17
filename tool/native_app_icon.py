"""Generate deterministic SAKU launcher icons for generated native shells.

The repository intentionally regenerates android/ and ios/ during bootstrap.
This script replaces Flutter's template launcher artwork with a local, offline
SAKU mark derived from the same Design4 geometry/colors used by native_splash.
It uses only Python's standard library so CI has no image-tool dependency.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
NOTURNO = (0x00, 0x16, 0x21)
VULCANICO = (0xFF, 0x41, 0x03)
VULCANICO_SHADE = (0xE8, 0x3A, 0x02)
SKIN = (0xFF, 0xB4, 0x8F)
ON_NOTURNO = (0xFD, 0xFC, 0xF9)

ANDROID_ADAPTIVE_FOREGROUND = '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="240"
    android:viewportHeight="240">
    <group
        android:pivotX="120"
        android:pivotY="120"
        android:scaleX="0.72"
        android:scaleY="0.72">
        <group android:translateY="24">
            <path android:fillColor="#FF4103" android:pathData="M50,78 Q120,55 190,78 L186,148 Q182,174 128,176 L91,176 Q50,172 48,140 Z"/>
            <path android:fillColor="#E83A02" android:pathData="M165,75 Q205,100 180,164 Q162,177 143,173 Q174,120 165,75 Z"/>
            <path android:fillColor="#FFB48F" android:pathData="M90,28 L150,50 L145,92 Q120,105 84,88 Z"/>
            <group android:rotation="-10" android:pivotX="105" android:pivotY="40">
                <path android:fillColor="#FDFCF9" android:pathData="M65,12 H145 Q155,12 155,22 V58 Q155,68 145,68 H65 Q55,68 55,58 V22 Q55,12 65,12 Z"/>
            </group>
            <path android:fillColor="@android:color/transparent" android:strokeColor="#001621" android:strokeWidth="5.5" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M55,86 Q118,110 184,83"/>
            <path android:fillColor="@android:color/transparent" android:strokeColor="#001621" android:strokeWidth="4.5" android:strokeLineCap="round" android:pathData="M70,125 H82 M91,124 H103 M112,123 H124 M133,122 H145 M154,121 H166"/>
            <path android:fillColor="#001621" android:pathData="M174,96 A8,8 0,1 0,190 96 A8,8 0,1 0,174 96"/>
            <path android:fillColor="@android:color/transparent" android:strokeColor="#FF4103" android:strokeWidth="7" android:strokeLineCap="round" android:pathData="M170,55 L176,40 M185,65 L202,52"/>
        </group>
    </group>
</vector>
'''

ANDROID_ADAPTIVE_ICON = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/saku_launcher_background"/>
    <foreground android:drawable="@drawable/saku_launcher_foreground"/>
</adaptive-icon>
'''

ANDROID_LAUNCHER_COLORS = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="saku_launcher_background">#001621</color>
</resources>
'''


def _quad(p0: tuple[float, float], p1: tuple[float, float], p2: tuple[float, float], steps: int = 28) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1.0 - t
        out.append((
            mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0],
            mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1],
        ))
    return out


def _transform(points: list[tuple[float, float]], size: int) -> list[tuple[float, float]]:
    scale = size / 240.0
    return [(x * scale, (y + 24.0) * scale) for x, y in points]


def _fill_polygon(buf: bytearray, size: int, points: list[tuple[float, float]], color: tuple[int, int, int]) -> None:
    if len(points) < 3:
        return
    min_y = max(0, int(math.floor(min(y for _, y in points))))
    max_y = min(size - 1, int(math.ceil(max(y for _, y in points))))
    n = len(points)
    for py in range(min_y, max_y + 1):
        scan_y = py + 0.5
        xs: list[float] = []
        for i in range(n):
            x1, y1 = points[i]
            x2, y2 = points[(i + 1) % n]
            if y1 == y2:
                continue
            if (y1 <= scan_y < y2) or (y2 <= scan_y < y1):
                t = (scan_y - y1) / (y2 - y1)
                xs.append(x1 + t * (x2 - x1))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            left = max(0, int(math.ceil(xs[i] - 0.5)))
            right = min(size - 1, int(math.floor(xs[i + 1] - 0.5)))
            if right < left:
                continue
            row = py * size * 3
            for px in range(left, right + 1):
                idx = row + px * 3
                buf[idx:idx + 3] = bytes(color)


def _draw_disc(buf: bytearray, size: int, cx: float, cy: float, radius: float, color: tuple[int, int, int]) -> None:
    min_x = max(0, int(math.floor(cx - radius)))
    max_x = min(size - 1, int(math.ceil(cx + radius)))
    min_y = max(0, int(math.floor(cy - radius)))
    max_y = min(size - 1, int(math.ceil(cy + radius)))
    rr = radius * radius
    c = bytes(color)
    for y in range(min_y, max_y + 1):
        dy = (y + 0.5) - cy
        row = y * size * 3
        for x in range(min_x, max_x + 1):
            dx = (x + 0.5) - cx
            if dx * dx + dy * dy <= rr:
                idx = row + x * 3
                buf[idx:idx + 3] = c


def _draw_segment(buf: bytearray, size: int, a: tuple[float, float], b: tuple[float, float], width: float, color: tuple[int, int, int]) -> None:
    ax, ay = a
    bx, by = b
    length = max(1.0, math.hypot(bx - ax, by - ay))
    steps = max(1, int(math.ceil(length * 1.5)))
    radius = width / 2.0
    for i in range(steps + 1):
        t = i / steps
        _draw_disc(buf, size, ax + (bx - ax) * t, ay + (by - ay) * t, radius, color)


def _draw_polyline(buf: bytearray, size: int, points: list[tuple[float, float]], width: float, color: tuple[int, int, int]) -> None:
    for a, b in zip(points, points[1:]):
        _draw_segment(buf, size, a, b, width, color)


def _rotate(points: list[tuple[float, float]], center: tuple[float, float], degrees: float) -> list[tuple[float, float]]:
    cx, cy = center
    angle = math.radians(degrees)
    ca = math.cos(angle)
    sa = math.sin(angle)
    out: list[tuple[float, float]] = []
    for x, y in points:
        dx = x - cx
        dy = y - cy
        out.append((cx + dx * ca - dy * sa, cy + dx * sa + dy * ca))
    return out


def _render_icon(size: int) -> bytearray:
    buf = bytearray(bytes(NOTURNO) * (size * size))
    scale = size / 240.0

    pocket = [(50.0, 78.0)]
    pocket += _quad((50.0, 78.0), (120.0, 55.0), (190.0, 78.0))[1:]
    pocket.append((186.0, 148.0))
    pocket += _quad((186.0, 148.0), (182.0, 174.0), (128.0, 176.0))[1:]
    pocket.append((91.0, 176.0))
    pocket += _quad((91.0, 176.0), (50.0, 172.0), (48.0, 140.0))[1:]
    _fill_polygon(buf, size, _transform(pocket, size), VULCANICO)

    shade = [(165.0, 75.0)]
    shade += _quad((165.0, 75.0), (205.0, 100.0), (180.0, 164.0))[1:]
    shade += _quad((180.0, 164.0), (162.0, 177.0), (143.0, 173.0))[1:]
    shade += _quad((143.0, 173.0), (174.0, 120.0), (165.0, 75.0))[1:]
    _fill_polygon(buf, size, _transform(shade, size), VULCANICO_SHADE)

    skin = [(90.0, 28.0), (150.0, 50.0), (145.0, 92.0)]
    skin += _quad((145.0, 92.0), (120.0, 105.0), (84.0, 88.0))[1:]
    _fill_polygon(buf, size, _transform(skin, size), SKIN)

    card = _rotate([(59.0, 13.0), (154.0, 13.0), (154.0, 66.0), (59.0, 66.0)], (106.5, 39.5), -10.0)
    _fill_polygon(buf, size, _transform(card, size), ON_NOTURNO)

    seam = _quad((55.0, 86.0), (118.0, 110.0), (184.0, 83.0))
    _draw_polyline(buf, size, _transform(seam, size), 5.5 * scale, NOTURNO)

    for a, b in [
        ((70.0, 125.0), (82.0, 125.0)),
        ((91.0, 124.0), (103.0, 124.0)),
        ((112.0, 123.0), (124.0, 123.0)),
        ((133.0, 122.0), (145.0, 122.0)),
        ((154.0, 121.0), (166.0, 121.0)),
    ]:
        aa, bb = _transform([a, b], size)
        _draw_segment(buf, size, aa, bb, 4.5 * scale, NOTURNO)

    eye = _transform([(182.0, 96.0)], size)[0]
    _draw_disc(buf, size, eye[0], eye[1], 8.0 * scale, NOTURNO)

    for a, b in [((170.0, 55.0), (176.0, 40.0)), ((185.0, 65.0), (202.0, 52.0))]:
        aa, bb = _transform([a, b], size)
        _draw_segment(buf, size, aa, bb, 7.0 * scale, VULCANICO)

    return buf


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def _write_png(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = _render_icon(size)
    scanlines = b"".join(b"\x00" + bytes(raw[y * size * 3:(y + 1) * size * 3]) for y in range(size))
    png = b"\x89PNG\r\n\x1a\n"
    png += _png_chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
    png += _png_chunk(b"IDAT", zlib.compress(scanlines, level=9))
    png += _png_chunk(b"IEND", b"")
    path.write_bytes(png)


def patch_android() -> None:
    res = ROOT / "android/app/src/main/res"
    if not res.exists():
        return
    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        _write_png(res / f"mipmap-{density}/ic_launcher.png", size)
        _write_png(res / f"mipmap-{density}/ic_launcher_round.png", size)

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


def patch_ios() -> None:
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if not appicon.exists():
        return
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
    images: list[dict[str, str]] = []
    for index, (idiom, logical_size, scale, pixels) in enumerate(specs):
        filename = f"SAKU-AppIcon-{index:02d}-{pixels}.png"
        _write_png(appicon / filename, pixels)
        images.append({
            "filename": filename,
            "idiom": idiom,
            "scale": scale,
            "size": logical_size,
        })
    (appicon / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )


def main() -> None:
    patch_android()
    patch_ios()
    print("Native SAKU launcher icons generated from local Design4 geometry.")


if __name__ == "__main__":
    main()
