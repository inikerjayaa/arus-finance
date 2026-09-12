#!/usr/bin/env python3
from pathlib import Path
import json,subprocess,tempfile,shutil
ROOT=Path(__file__).resolve().parents[1]

def run(args,cwd=ROOT): return subprocess.run(args,cwd=cwd,capture_output=True,text=True)
# 1) Current workflows must pass immutable action pin audit.
p=run(['python3','tool/verify_ci_action_pins.py']); assert p.returncode==0,p.stdout+p.stderr
# 2) A mutable tag must be rejected by the verifier.
with tempfile.TemporaryDirectory(prefix='arus-v26-pin-') as td:
    td=Path(td); shutil.copytree(ROOT,td/'repo',dirs_exist_ok=True); repo=td/'repo'
    wf=repo/'.github/workflows/native-verify.yml'
    text=wf.read_text().replace('actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1','actions/checkout@v7.0.1 # v7.0.1',1)
    wf.write_text(text)
    p=run(['python3','tool/verify_ci_action_pins.py'],repo)
    assert p.returncode!=0 and 'full 40-char commit SHA' in (p.stdout+p.stderr)
# 3) Readiness report on canonical pre-native source must truthfully block on missing committed lock.
p=run(['python3','tool/release_readiness_report.py','--source-pass'])
assert p.returncode==0,p.stdout+p.stderr
assert 'DEPENDENCY_LOCK: **BLOCKED**' in p.stdout
assert 'CROSS_PLATFORM_COMPILE: **UNPROVEN**' in p.stdout
assert 'DEVICE_VALIDATION: **UNPROVEN**' in p.stdout
# 4) Workflow shape: no ephemeral resolution in native verification, separate manual candidate flow.
main=(ROOT/'.github/workflows/native-verify.yml').read_text()
boot=(ROOT/'.github/workflows/dependency-lock-bootstrap.yml').read_text()
assert 'flutter pub get --enforce-lockfile' in main
assert "test -f pubspec.lock" in main
assert 'flutter pub get\n' in boot and 'workflow_dispatch:' in boot
assert 'pull_request:' not in boot and 'push:' not in boot
print('PASS: V26 immutable CI + committed-lock + readiness-state reference contract')
