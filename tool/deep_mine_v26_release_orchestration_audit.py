#!/usr/bin/env python3
from pathlib import Path
import json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
read=lambda p:(ROOT/p).read_text()
wf=read('.github/workflows/native-verify.yml')
lock_wf=read('.github/workflows/dependency-lock-bootstrap.yml')
pins=json.loads(read('toolchain/github_actions_pins.json'))
report=read('tool/release_readiness_report.py')
orch=read('tool/release_orchestrator.sh')
checks={
 'native verify requires committed lock before Flutter install': "test -f pubspec.lock" in wf and 'flutter pub get --enforce-lockfile' in wf,
 'native verify no longer resolves dependency graph': 'Resolve dependency graph' not in wf and 'run: flutter pub get\n' not in wf,
 'manual lock bootstrap is workflow_dispatch only': 'workflow_dispatch:' in lock_wf and 'pull_request:' not in lock_wf and 'push:' not in lock_wf,
 'lock candidate explicitly not proof': 'NOT compile/release proof' in lock_wf,
 'cross-platform jobs compare checked-out committed lock': wf.count('cmp --silent pubspec.lock .ci/lock/pubspec.lock')==2,
 'GitHub action pin manifest has four audited actions': len(pins)==4,
 'all workflow action refs use full SHA verifier retained': (ROOT/'tool/verify_ci_action_pins.py').exists(),
 'Dependabot GitHub Actions maintenance retained': 'package-ecosystem: github-actions' in read('.github/dependabot.yml'),
 'release readiness source/lock/compile/device/store states separated': all(x in report for x in ['SOURCE_NON_NATIVE','DEPENDENCY_LOCK','ANDROID_COMPILE','IOS_COMPILE','DEVICE_VALIDATION','STORE_ARTIFACTS']),
 'readiness evidence rejects stale canonical source': 'different canonical source' in report,
 'readiness evidence rejects stale lock': 'does not match current committed lock' in report,
 'device evidence requires both platforms': "set(d.get('platforms',[]))=={'android','ios'}" in report,
 'orchestrator exposes source/status/compile/store': all(x in orch for x in ['source)','status)','compile)','store)']),
 'V26 handoff doc retained': (ROOT/'docs/RELEASE_ORCHESTRATION_V26.md').exists(),
 'V26 reference audit retained': (ROOT/'tool/reference_v26_release_orchestration_audit.py').exists(),
}
failed=[k for k,v in checks.items() if not v]
if failed:
    print('FAIL: V26 release orchestration contract')
    for x in failed: print(' -',x)
    raise SystemExit(1)
p=subprocess.run(['python3','tool/verify_ci_action_pins.py'],cwd=ROOT,capture_output=True,text=True)
if p.returncode:
    print(p.stdout,p.stderr); raise SystemExit(p.returncode)
print(f'PASS: deep-mine V26 release orchestration contract ({len(checks)} source checks + immutable-pin verifier)')
