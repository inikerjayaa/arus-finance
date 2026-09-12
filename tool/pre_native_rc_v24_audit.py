from pathlib import Path
import sys
import re
ROOT=Path(__file__).resolve().parents[1]
read=lambda r:(ROOT/r).read_text()
status=read('docs/IMPLEMENTATION_STATUS_LOCAL_ONLY.md')
matrix=read('docs/TEST_MATRIX.md')
rc=read('docs/PRE_NATIVE_RELEASE_CANDIDATE_V24.md')
readme=read('README.md')
runner=read('tool/run_all_audits.sh')
continuity=read('tool/version_continuity_audit.py')
canonical_match=re.search(r'Canonical persisted milestone: \*\*V(\d+)', status)
continuity_match=re.search(r'V1→V(\d+) continuity contract', continuity)
checks={
 'canonical status advanced beyond V24 while V24 freeze remains documented':bool(canonical_match) and int(canonical_match.group(1)) > 24 and 'V24' in rc,
 'README carries V20':'V20 long-session hardening' in readme,
 'README carries V21':'V21 rebuild isolation' in readme,
 'README carries V22':'V22 timeline query/filter/result state' in readme,
 'README carries V23':'V23 sensitive-UI privacy hardening' in readme,
 'README carries V24 freeze':'V24 is the pre-native release-candidate freeze' in readme,
 'test matrix carries V20 request ordering':'79. Out-of-order timeline requests' in matrix,
 'test matrix carries V21 rebuild boundary':'83. Routine controller notifications' in matrix,
 'test matrix carries V22 atomic filter state':'84. Failed timeline search/filter/reset' in matrix,
 'test matrix carries V23 privacy shield':'85. Android financial UI' in matrix and '86. Inactive/hidden/paused' in matrix,
 'RC truthfully separates source/native states':'SOURCE / NON-NATIVE RC: READY' in rc and 'Flutter analyzer PASS' in rc and 'Android COMPILE/DEVICE/STORE PASS' in rc,
 'RC handoff requires pubspec lock':'pubspec.lock' in rc,
 'RC handoff requires all audits':'tool/run_all_audits.sh' in rc,
 'RC handoff requires Android and iOS device validation':'Android release' in rc and 'macOS/Xcode' in rc and 'device validation matrix' in rc,
 'runner carries V20':'deep_mine_v20_long_session_audit.py' in runner,
 'runner carries V21':'deep_mine_v21_rebuild_isolation_audit.py' in runner,
 'runner carries V22':'deep_mine_v22_atomic_filter_state_audit.py' in runner,
 'runner carries V23':'deep_mine_v23_privacy_shield_audit.py' in runner,
 'continuity remains at or beyond V24':bool(continuity_match) and int(continuity_match.group(1)) >= 24,
 'V24 continuity doc exists':(ROOT/'docs/VERSION_CONTINUITY_V1_V24.md').exists(),
}
# Hygiene over persistent source, excluding generated platform/build dirs if absent.
for p in ROOT.rglob('*'):
    if not p.is_file(): continue
    rel=p.relative_to(ROOT)
    if any(part in {'.git','.dart_tool','build','__pycache__'} for part in rel.parts):
        continue
    if p.suffix in {'.pyc','.tmp','.bak','.orig'}:
        print('FAIL: transient artifact', rel); sys.exit(1)
    if p.suffix in {'.dart','.py','.sh','.md','.yaml','.yml'}:
        text=p.read_text(errors='ignore')
        conflict_markers = ['<' * 7, '>' * 7, '=' * 7]
        if any(marker in text for marker in conflict_markers):
            print('FAIL: merge conflict marker', rel); sys.exit(1)
failed=[k for k,v in checks.items() if not v]
if failed:
 print('FAIL: V24 pre-native RC contract')
 for k in failed: print(' -',k)
 sys.exit(1)
print(f'PASS: V24 pre-native RC contract ({len(checks)} checks + source hygiene)')
