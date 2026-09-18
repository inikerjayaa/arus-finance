#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
VERIFY_TARGET = ROOT / "tool/verify_device_uat_artifact.py"
EVIDENCE_TARGET = ROOT / "tool/capture_native_evidence.py"


def _load(name: str, target: Path):
    spec = importlib.util.spec_from_file_location(name, target)
    if spec is None or spec.loader is None:
        raise SystemExit(f"FAIL: unable to load {target.name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


verify_module = _load("verify_device_uat_artifact", VERIFY_TARGET)
evidence_module = _load("capture_native_evidence", EVIDENCE_TARGET)

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
        good = verify_module.verify(directory)
    if good != 0:
        raise SystemExit(f"FAIL: valid UAT fixture returned {good}")

    apk.write_bytes(payload + b"-tampered")
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        tampered = verify_module.verify(directory)
    if tampered == 0:
        raise SystemExit("FAIL: tampered UAT fixture was accepted")

# Cross-platform canonical evidence must ignore untracked runner residue.
canonical_before, count_before = evidence_module.source_manifest_hash(include_native=False)
probe = ROOT / "docs/.v42-untracked-evidence-probe.tmp"
if probe.exists():
    raise SystemExit("FAIL: V42 evidence probe path unexpectedly exists")
try:
    probe.write_text("runner-specific transient content\n")
    canonical_after, count_after = evidence_module.source_manifest_hash(include_native=False)
finally:
    probe.unlink(missing_ok=True)

if canonical_after != canonical_before or count_after != count_before:
    raise SystemExit("FAIL: untracked runner residue changed canonical source identity")

print("PASS: V42 UAT artifact verifier accepts valid checksum and rejects tampering")
print("PASS: V42 canonical evidence ignores untracked runner residue")
