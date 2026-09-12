#!/usr/bin/env python3
from pathlib import Path
import hashlib
import sys
lock = Path(sys.argv[1] if len(sys.argv) > 1 else 'pubspec.lock')
sha_file = Path(sys.argv[2] if len(sys.argv) > 2 else 'pubspec.lock.sha256')
if not lock.exists() or not sha_file.exists():
    raise SystemExit('FAIL: lockfile or lock checksum file missing.')
expected = sha_file.read_text().strip().split()[0]
actual = hashlib.sha256(lock.read_bytes()).hexdigest()
if actual != expected:
    raise SystemExit(f'FAIL: pubspec.lock SHA-256 mismatch: {actual}')
print('PASS: pubspec.lock artifact checksum verified: ' + actual)
