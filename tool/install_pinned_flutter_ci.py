#!/usr/bin/env python3
"""Install exactly the Arus-pinned Flutter SDK from Flutter's official archive.

The installer validates version, channel, Flutter git hash, bundled Dart version,
and archive SHA-256 before extracting. It supports local manifest/archive fixtures
so the safety contract can be tested without network access.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PIN_PATH = ROOT / "toolchain/flutter_release_pin.json"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def host_key() -> tuple[str, str, str]:
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "linux":
        os_key = "linux"
    elif system == "darwin":
        os_key = "macos"
    else:
        raise SystemExit(f"FAIL: unsupported CI host for Arus native verification: {system}")
    arch_map = {"x86_64": "x64", "amd64": "x64", "arm64": "arm64", "aarch64": "arm64"}
    if machine not in arch_map:
        raise SystemExit(f"FAIL: unsupported host architecture: {machine}")
    arch = arch_map[machine]
    manifest_name = "releases_linux.json" if os_key == "linux" else "releases_macos.json"
    return os_key, arch, manifest_name


def load_json_from_url(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "ArusFinanceNativeCI/1"})
    with urllib.request.urlopen(req, timeout=120) as r, dest.open("wb") as out:
        while True:
            chunk = r.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)


def safe_extract_tar(archive: Path, dest: Path) -> None:
    with tarfile.open(archive, "r:*") as tf:
        # Python 3.12+ filter blocks path traversal/device entries.
        tf.extractall(dest, filter="data")


def safe_extract_zip(archive: Path, dest: Path) -> None:
    dest_resolved = dest.resolve()
    with zipfile.ZipFile(archive) as zf:
        for info in zf.infolist():
            target = (dest / info.filename).resolve()
            if target != dest_resolved and dest_resolved not in target.parents:
                raise SystemExit(f"FAIL: unsafe zip member: {info.filename}")
        zf.extractall(dest)
        # zipfile.extractall() does not reliably restore Unix executable bits.
        # Flutter's macOS SDK is a ZIP, so restore archived permission metadata
        # before the toolchain is invoked by bootstrap/preflight.
        for info in zf.infolist():
            target = dest / info.filename
            mode = (info.external_attr >> 16) & 0o777
            if mode and target.exists() and not target.is_symlink():
                target.chmod(mode)


def ensure_flutter_launchers_executable(flutter_root: Path) -> None:
    # Fail-safe for ZIP producers/runtimes that omit permission metadata.
    launchers = [
        flutter_root / "bin/flutter",
        flutter_root / "bin/dart",
        flutter_root / "bin/cache/dart-sdk/bin/dart",
        flutter_root / "bin/cache/dart-sdk/bin/dartaotruntime",
    ]
    for launcher in launchers:
        if launcher.exists():
            launcher.chmod(launcher.stat().st_mode | 0o111)
    if not os.access(flutter_root / "bin/flutter", os.X_OK):
        raise SystemExit("FAIL: verified Flutter launcher is not executable after extraction.")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--install-dir", required=True)
    ap.add_argument("--manifest-file", help="Offline fixture manifest; skips network manifest fetch.")
    ap.add_argument("--archive-file", help="Offline fixture archive; skips network archive fetch.")
    ns = ap.parse_args()

    pin = json.loads(PIN_PATH.read_text())
    os_key, arch, manifest_name = host_key()
    base = pin["official_manifest_base"].rstrip("/")
    manifest_url = f"{base}/{manifest_name}"
    manifest = json.loads(Path(ns.manifest_file).read_text()) if ns.manifest_file else load_json_from_url(manifest_url)

    candidates = [
        r for r in manifest.get("releases", [])
        if r.get("channel") == pin["channel"]
        and r.get("version") == pin["flutter_version"]
        and r.get("dart_sdk_arch") == arch
    ]
    if len(candidates) != 1:
        raise SystemExit(
            f"FAIL: expected exactly one Flutter {pin['flutter_version']} {os_key}/{arch} release; found {len(candidates)}"
        )
    rel = candidates[0]
    if rel.get("hash") != pin["release_hash"]:
        raise SystemExit("FAIL: Flutter release git hash differs from Arus pin.")
    if rel.get("dart_sdk_version") != pin["dart_version"]:
        raise SystemExit(
            f"FAIL: bundled Dart mismatch; expected {pin['dart_version']} got {rel.get('dart_sdk_version')}"
        )
    expected_sha = rel.get("sha256")
    if not isinstance(expected_sha, str) or len(expected_sha) != 64:
        raise SystemExit("FAIL: official release entry has no valid SHA-256.")
    if not ns.manifest_file and os_key == "linux" and arch == "x64" and expected_sha != pin["linux_x64_sha256"]:
        raise SystemExit("FAIL: Linux x64 release checksum differs from Arus pinned checksum.")

    archive_rel = rel.get("archive")
    if not isinstance(archive_rel, str) or not archive_rel:
        raise SystemExit("FAIL: release archive path missing.")
    archive_url = f"{manifest.get('base_url', base).rstrip('/')}/{archive_rel}"

    install_dir = Path(ns.install_dir).expanduser().resolve()
    if install_dir.exists():
        shutil.rmtree(install_dir)
    install_dir.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="arus-flutter-") as td:
        tdir = Path(td)
        if ns.archive_file:
            archive = Path(ns.archive_file).resolve()
        else:
            suffix = ".zip" if archive_rel.endswith(".zip") else ".tar.xz"
            archive = tdir / f"flutter-sdk{suffix}"
            print(f"CHECK: downloading pinned Flutter {pin['flutter_version']} from official archive")
            download(archive_url, archive)
        actual_sha = sha256_file(archive)
        if actual_sha != expected_sha:
            raise SystemExit(f"FAIL: Flutter SDK SHA-256 mismatch: {actual_sha}")

        extracted = tdir / "extracted"
        extracted.mkdir()
        if archive.name.endswith(".zip") or archive_rel.endswith(".zip"):
            safe_extract_zip(archive, extracted)
        else:
            safe_extract_tar(archive, extracted)
        flutter_root = extracted / "flutter"
        if not (flutter_root / "bin/flutter").exists():
            raise SystemExit("FAIL: verified archive does not contain flutter/bin/flutter.")
        ensure_flutter_launchers_executable(flutter_root)
        shutil.move(str(flutter_root), str(install_dir))

    ensure_flutter_launchers_executable(install_dir)
    github_path = os.environ.get("GITHUB_PATH")
    if github_path:
        with open(github_path, "a", encoding="utf-8") as f:
            f.write(str(install_dir / "bin") + "\n")
    print(f"PASS: pinned Flutter {pin['flutter_version']} / Dart {pin['dart_version']} installed for {os_key}/{arch}")
    print(f"FLUTTER_RELEASE_HASH={pin['release_hash']}")
    print(f"FLUTTER_ARCHIVE_SHA256={expected_sha}")


if __name__ == "__main__":
    main()
