#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]

def read(path): return (ROOT/path).read_text(encoding='utf-8')
attrs=read('.gitattributes')
create=read('tool/create_git_bootstrap_bundle.sh')
verify=read('tool/verify_git_bootstrap_bundle.sh')
doc=read('docs/GIT_BOOTSTRAP_HANDOFF_V27.md')
status=read('docs/IMPLEMENTATION_STATUS_LOCAL_ONLY.md')
readme=read('README.md')

checks={
    'LF normalization retained': '* text=auto eol=lf' in attrs,
    'binary exclusions retained': all(x in attrs for x in ['*.zip binary','*.jks binary','*.p12 binary']),
    'temporary staging retained': 'mktemp -d' in create and 'tar -C "$ROOT" -cf - .' in create,
    'canonical source not git-initialized in place': 'cd "$stage"' in create and 'git init -q -b main' in create,
    'secret denylist retained': all(x in create for x in ["'.env'", "'key.properties'", "'ExportOptions.plist'", "'*.jks'", "'*.keystore'", "'*.pem'", "'*.key'"]),
    'cache/build/vcs denylist retained': all(x in create for x in ["-name '.git'", "-name '__pycache__'", "-name '.dart_tool'", "-name 'build'"]),
    'fixed metadata retained': all(x in create for x in ['Arus Finance Canonical Builder','arus-finance@local.invalid','2026-09-12T00:00:00Z','Arus Finance V27 canonical Git bootstrap']),
    'main and tag retained': 'git init -q -b main' in create and 'arus-v27-bootstrap' in create,
    'fsck and bundle verify retained': 'git fsck --full --no-dangling' in create and 'git bundle verify' in create,
    'bundle hash manifest retained': 'bundle_sha256' in create and 'tracked_files_manifest_sha256' in create,
    'fresh clone verifier retained': 'git clone -q -b main "$bundle"' in verify and 'sha256sum -c "$files_manifest"' in verify,
    'manifest commit/tree verifier retained': 'git rev-parse HEAD^{tree}' in verify and 'refs/tags/arus-v27-bootstrap' in verify,
    'handoff keeps native claims separate': 'does **not** claim Flutter analyze/test' in doc,
    'canonical status V27': 'Canonical persisted milestone: **V27' in status,
    'README V27 retained': 'V27 adds a deterministic Git bootstrap' in readme,
    'V27 continuity doc retained': (ROOT/'docs/VERSION_CONTINUITY_V1_V27.md').exists(),
    'V27 report retained': (ROOT/'docs/BUG_HUNT_LOCAL_ONLY_V27_REPORT.md').exists(),
    'runner cleans Python audit cache before Git identity': 'find . -type d -name __pycache__ -prune -exec rm -rf {} +' in read('tool/run_all_audits.sh'),
}
failed=[k for k,v in checks.items() if not v]
if failed:
    print('FAIL: V27 Git bootstrap source contract')
    for x in failed: print(' -',x)
    sys.exit(1)
print(f'PASS: V27 Git bootstrap source contract ({len(checks)}/{len(checks)})')
