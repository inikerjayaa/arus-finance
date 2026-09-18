#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "tool/verify_device_uat_artifact.py"

spec = importlib.util.spec_from_file_location("verify_device_uat_artifact", TARGET)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: unable to load verify_device_uat_artifact.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with TemporaryDirectory() as tmp:
    directory = Path(tmp)
    apk = directory / "app-release.apk"
    sha_file = directory / "android-device-uat-apk.sha256"
    signing = directory / "android-device-uat-apk-signing.txt"

    payload = b"SAKU-UAT-reference-fixture"
    apk.write_bytes(payload)
    digest = hashlib.sha256(payload).hexdigest()
    sha_file.write_text(f"{digest}  build/app/outputs/flutter-apk/app-release.apk\n")
    signing.write_text(
        "Signer #1 certificate SHA-256 digest: " + ("ab" * 32) + "\n"
    )

    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        good = module.verify(directory)
    if good != 0:
        raise SystemExit(f"FAIL: valid UAT fixture returned {good}")

    apk.write_bytes(payload + b"-tampered")
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        tampered = module.verify(directory)
    if tampered == 0:
        raise SystemExit("FAIL: tampered UAT fixture was accepted")

print("PASS: V42 UAT artifact verifier accepts valid checksum and rejects tampering")
