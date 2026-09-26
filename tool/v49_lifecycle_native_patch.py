"""Add Android device-lock truth to SAKU's existing native security channel.

This deliberately distinguishes a genuine keyguard/device-lock transition from
ordinary Android activity pauses caused by Recents, document/image pickers, or
other transient system UI. It is idempotent and runs after native_hardening.py.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android/app/src/main"


def patch_kotlin(path: Path) -> None:
    text = path.read_text()
    if '"isDeviceLocked"' in text:
        return
    package_end = text.find("\n", text.find("package ")) + 1
    for imp in ("android.app.KeyguardManager", "android.content.Context"):
        marker = f"import {imp}\n"
        if marker not in text:
            text = text[:package_end] + marker + text[package_end:]
            package_end += len(marker)
    needle = '                "isSupported" -> result.success(true)\n'
    replacement = needle + '''                "isDeviceLocked" -> {\n                    val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager\n                    result.success(keyguard.isDeviceLocked)\n                }\n'''
    if needle not in text:
        raise RuntimeError(f"Unsupported Kotlin security-channel shape: {path}")
    path.write_text(text.replace(needle, replacement, 1))


def patch_java(path: Path) -> None:
    text = path.read_text()
    if 'case "isDeviceLocked"' in text:
        return
    package_end = text.find("\n", text.find("package ")) + 1
    for imp in ("android.app.KeyguardManager", "android.content.Context"):
        marker = f"import {imp};\n"
        if marker not in text:
            text = text[:package_end] + marker + text[package_end:]
            package_end += len(marker)
    needle = '''                case "isSupported":\n                    result.success(true);\n                    break;\n'''
    replacement = needle + '''                case "isDeviceLocked":\n                    KeyguardManager keyguard = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);\n                    result.success(keyguard != null && keyguard.isDeviceLocked());\n                    break;\n'''
    if needle not in text:
        raise RuntimeError(f"Unsupported Java security-channel shape: {path}")
    path.write_text(text.replace(needle, replacement, 1))


def main() -> None:
    if not ANDROID.exists():
        return
    found = False
    for path in ANDROID.rglob("MainActivity.kt"):
        found = True
        patch_kotlin(path)
    for path in ANDROID.rglob("MainActivity.java"):
        found = True
        patch_java(path)
    if not found:
        raise RuntimeError("Android MainActivity not found")


if __name__ == "__main__":
    main()
