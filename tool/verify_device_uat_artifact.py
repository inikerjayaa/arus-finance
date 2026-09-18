#!/usr/bin/env python3
"""Verify an extracted Android device-UAT artifact before physical installation.

Expected files are emitted by `.github/workflows/native-verify.yml`:
- app-release.apk
- android-device-uat-apk.sha256
- android-device-uat-apk-signing.txt

This tool never installs or modifies an app/device.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sys

APK_NAME = "app-release.apk"
SHA_NAME = "android-device-uat-apk.sha256"
SIGNING_NAME = "android-device-uat-apk-signing.txt"
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _expected_sha(path: Path) -> str:
    text = path.read_text(encoding="utf-8", errors="strict").strip()
    if not text:
        raise ValueError(f"{path.name} is empty")
    value = text.split()[0]
    if not HEX64.fullmatch(value):
        raise ValueError(f"{path.name} does not start with a SHA-256 digest")
    return value.lower()


def _signing_fingerprints(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    fingerprints = [
        line.strip()
        for line in lines
        if "certificate SHA-256 digest" in line
        or "certificate SHA256 digest" in line
    ]
    return fingerprints


def verify(directory: Path) -> int:
    directory = directory.resolve()
    apk = directory / APK_NAME
    sha_file = directory / SHA_NAME
    signing = directory / SIGNING_NAME

    missing = [p.name for p in (apk, sha_file, signing) if not p.is_file()]
    if missing:
        print("FAIL: missing required artifact file(s): " + ", ".join(missing), file=sys.stderr)
        return 2

    try:
        expected = _expected_sha(sha_file)
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 2

    actual = _sha256(apk)
    if actual != expected:
        print("FAIL: APK SHA-256 mismatch", file=sys.stderr)
        print(f"expected: {expected}", file=sys.stderr)
        print(f"actual:   {actual}", file=sys.stderr)
        return 1

    fingerprints = _signing_fingerprints(signing)
    print("PASS: Android device-UAT APK checksum matches CI evidence")
    print(f"APK_SHA256={actual}")
    if fingerprints:
        print("Signing certificate evidence:")
        for line in fingerprints:
            print(f"  {line}")
    else:
        print(
            "WARN: signing evidence exists but no SHA-256 certificate line was recognized; "
            "inspect android-device-uat-apk-signing.txt manually."
        )
    print("NOTE: checksum/signing evidence is not DEVICE PASS or store-signing proof.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "artifact_dir",
        type=Path,
        help="Directory containing the extracted Android device-UAT artifact files",
    )
    args = parser.parse_args()
    return verify(args.artifact_dir)


if __name__ == "__main__":
    raise SystemExit(main())
