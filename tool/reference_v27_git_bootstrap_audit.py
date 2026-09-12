#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, shutil, subprocess, tempfile, sys

ROOT=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as td:
    out=Path(td)/'out'
    p=subprocess.run(['bash',str(ROOT/'tool/create_git_bootstrap_bundle.sh'),str(out)],cwd=ROOT,text=True,capture_output=True)
    if p.returncode:
        print(p.stdout); print(p.stderr,file=sys.stderr); raise SystemExit('FAIL: V27 bootstrap creation fixture')
    bundle=out/'arus_finance_v27_canonical.bundle'
    manifest=out/'arus_finance_v27_git_manifest.json'
    files=out/'arus_finance_v27_tracked_files.sha256'
    q=subprocess.run(['bash',str(ROOT/'tool/verify_git_bootstrap_bundle.sh'),str(bundle),str(manifest),str(files)],cwd=ROOT,text=True,capture_output=True)
    if q.returncode:
        print(q.stdout); print(q.stderr,file=sys.stderr); raise SystemExit('FAIL: V27 bootstrap verification fixture')
    m=json.loads(manifest.read_text())
    if len(m['commit_sha1']) != 40 or len(m['tree_sha1']) != 40 or len(m['bundle_sha256']) != 64:
        raise SystemExit('FAIL: malformed V27 Git evidence')
    # Recreate independently and require identical commit/tree and tracked-file manifest.
    out2=Path(td)/'out2'
    r=subprocess.run(['bash',str(ROOT/'tool/create_git_bootstrap_bundle.sh'),str(out2)],cwd=ROOT,text=True,capture_output=True)
    if r.returncode: raise SystemExit('FAIL: second V27 bootstrap creation')
    m2=json.loads((out2/'arus_finance_v27_git_manifest.json').read_text())
    for key in ('commit_sha1','tree_sha1','tracked_files_manifest_sha256','tracked_file_count'):
        if m[key] != m2[key]: raise SystemExit(f'FAIL: V27 deterministic {key}')
    # Git pack/bundle container bytes are not required to be deterministic; Git may
    # choose a different valid pack representation for the same immutable objects.
    # Each emitted bundle is instead bound to its own SHA-256 and independently verified.
    h1=hashlib.sha256(bundle.read_bytes()).hexdigest()
    h2=hashlib.sha256((out2/'arus_finance_v27_canonical.bundle').read_bytes()).hexdigest()
    if h1 != m['bundle_sha256'] or h2 != m2['bundle_sha256']:
        raise SystemExit('FAIL: V27 bundle hash not bound to emitted artifact')
    q2=subprocess.run(['bash',str(ROOT/'tool/verify_git_bootstrap_bundle.sh'),str(out2/'arus_finance_v27_canonical.bundle'),str(out2/'arus_finance_v27_git_manifest.json'),str(out2/'arus_finance_v27_tracked_files.sha256')],cwd=ROOT,text=True,capture_output=True)
    if q2.returncode:
        raise SystemExit('FAIL: second V27 bootstrap verification fixture')
    print('PASS: V27 deterministic Git object/bootstrap reference fixture')
