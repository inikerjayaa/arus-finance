#!/usr/bin/env python3
"""Materialize SAKU's bundled Plus Jakarta Sans fonts deterministically.

The application itself never fetches fonts at runtime. Build/test environments
materialize the exact upstream font blobs pinned below, verify the Git blob SHA,
and then Flutter bundles them into the app.
"""

from __future__ import annotations

import hashlib
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets" / "fonts"
UPSTREAM_COMMIT = "18d1cd2f7ea10481919d2f05c1f7064b7307fc26"
BASE = (
    "https://raw.githubusercontent.com/tokotype/PlusJakartaSans/"
    f"{UPSTREAM_COMMIT}/fonts/ttf"
)

FONTS = {
    "PlusJakartaSans-Regular.ttf": "cb874458c3911fcb7a12da70f66e4154863c9841",
    "PlusJakartaSans-Medium.ttf": "5d8dd8ab476e4bc9766af41d9ee0e183da2c15fe",
    "PlusJakartaSans-SemiBold.ttf": "c12d4b0e72bde4d78af22aa73184024d2495bef3",
    "PlusJakartaSans-Bold.ttf": "2d49642350842c27fc88ff90d6445eeda1766f7e",
}


def git_blob_sha(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def valid(path: Path, expected_blob_sha: str) -> bool:
    if not path.is_file():
        return False
    try:
        return git_blob_sha(path.read_bytes()) == expected_blob_sha
    except OSError:
        return False


def download(name: str, expected_blob_sha: str) -> None:
    target = FONT_DIR / name
    if valid(target, expected_blob_sha):
        print(f"OK: {name} already materialized")
        return

    url = f"{BASE}/{name}"
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "SAKU-build/1.0"},
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            data = response.read()
    except Exception as exc:  # pragma: no cover - environment/network failure
        raise RuntimeError(
            f"Unable to download pinned brand font {name}. "
            "Builds need network only while materializing bundled assets; "
            "the finished app remains fully offline for typography."
        ) from exc

    actual = git_blob_sha(data)
    if actual != expected_blob_sha:
        raise RuntimeError(
            f"Pinned font verification failed for {name}: "
            f"expected Git blob {expected_blob_sha}, got {actual}"
        )

    target.write_bytes(data)
    print(f"OK: materialized {name} ({len(data)} bytes)")


def main() -> int:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for name, blob_sha in FONTS.items():
        download(name, blob_sha)
    print("PASS: SAKU bundled Plus Jakarta Sans fonts are ready")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
