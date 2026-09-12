#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, subprocess
from pathlib import Path
from capture_native_evidence import source_manifest_hash, sha256_file
ROOT=Path(__file__).resolve().parents[1]
PIN_FLUTTER=(ROOT/'toolchain/flutter_version.txt').read_text().strip()
PIN_DART=(ROOT/'toolchain/dart_version.txt').read_text().strip()

def evidence_state(kind:str, current_hash:str, lock_hash:str|None):
    p=ROOT/'build/arus_evidence'/f'{kind}.json'
    if not p.exists(): return {'status':'UNPROVEN','reason':'evidence file not present'}
    try: obj=json.loads(p.read_text())
    except Exception as e: return {'status':'FAIL','reason':f'invalid JSON evidence: {e}'}
    if obj.get('format')!='arus-native-evidence-v2' or obj.get('kind')!=kind or obj.get('status')!='PASS':
        return {'status':'FAIL','reason':'evidence identity/status mismatch'}
    if obj.get('canonical_source_manifest',{}).get('sha256')!=current_hash:
        return {'status':'STALE','reason':'evidence was built from a different canonical source'}
    if lock_hash is None or obj.get('pubspec_lock_sha256')!=lock_hash:
        return {'status':'STALE','reason':'evidence lockfile does not match current committed lock'}
    if f'Flutter {PIN_FLUTTER}' not in obj.get('flutter_version',''):
        return {'status':'FAIL','reason':'Flutter version evidence differs from pin'}
    if f'Dart SDK version: {PIN_DART}' not in obj.get('dart_version',''):
        return {'status':'FAIL','reason':'Dart version evidence differs from pin'}
    return {'status':'PASS','artifact_sha256':obj.get('artifact',{}).get('sha256')}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source-pass', action='store_true', help='set only after tool/run_all_audits.sh succeeds in this same orchestration')
    ap.add_argument('--json-out')
    ap.add_argument('--md-out')
    ns=ap.parse_args()
    source_hash,source_count=source_manifest_hash(include_native=False)
    lock=ROOT/'pubspec.lock'
    lock_hash=sha256_file(lock) if lock.exists() else None
    states={}
    states['SOURCE_NON_NATIVE']={'status':'PASS' if ns.source_pass else 'UNPROVEN', 'canonical_source_sha256':source_hash, 'file_count':source_count}
    states['DEPENDENCY_LOCK']={'status':'PASS','sha256':lock_hash} if lock_hash else {'status':'BLOCKED','reason':'committed pubspec.lock is absent'}
    for kind,label in [('android-compile','ANDROID_COMPILE'),('ios-compile','IOS_COMPILE'),('android-release','ANDROID_STORE_ARTIFACT'),('ios-release','IOS_STORE_ARTIFACT')]:
        states[label]=evidence_state(kind,source_hash,lock_hash)
    compile_ok=states['ANDROID_COMPILE']['status']=='PASS' and states['IOS_COMPILE']['status']=='PASS'
    states['CROSS_PLATFORM_COMPILE']={'status':'PASS' if compile_ok else 'UNPROVEN', 'reason':None if compile_ok else 'both Android and iOS compile evidence are required'}
    # Physical-device proof is intentionally separate and never inferred from compiler/store artifacts.
    device=ROOT/'build/arus_evidence/device-validation.json'
    if device.exists():
        try:
            d=json.loads(device.read_text())
            valid=(d.get('format')=='arus-device-evidence-v1' and d.get('status')=='PASS' and d.get('canonical_source_sha256')==source_hash and d.get('pubspec_lock_sha256')==lock_hash and set(d.get('platforms',[]))=={'android','ios'})
            states['DEVICE_VALIDATION']={'status':'PASS' if valid else 'FAIL', 'reason':None if valid else 'device evidence does not match current source/lock/both platforms'}
        except Exception as e:
            states['DEVICE_VALIDATION']={'status':'FAIL','reason':f'invalid device evidence: {e}'}
    else:
        states['DEVICE_VALIDATION']={'status':'UNPROVEN','reason':'physical-device evidence not present'}
    store_ok=states['ANDROID_STORE_ARTIFACT']['status']=='PASS' and states['IOS_STORE_ARTIFACT']['status']=='PASS'
    states['STORE_ARTIFACTS']={'status':'PASS' if store_ok else 'UNPROVEN','reason':None if store_ok else 'both signed store artifacts are required'}
    overall='READY_FOR_DEVICE' if compile_ok else ('READY_FOR_NATIVE_COMPILE' if lock_hash and states['SOURCE_NON_NATIVE']['status']=='PASS' else 'PRE_NATIVE')
    payload={'format':'arus-release-readiness-v1','overall':overall,'states':states}
    text=json.dumps(payload,indent=2,sort_keys=True)+'\n'
    if ns.json_out: (ROOT/ns.json_out).write_text(text)
    lines=['# Arus Release Readiness','',f'Overall: **{overall}**','']
    for k,v in states.items():
        line=f'- {k}: **{v["status"]}**'
        if v.get('reason'): line += f' — {v["reason"]}'
        lines.append(line)
    md='\n'.join(lines)+'\n'
    if ns.md_out: (ROOT/ns.md_out).write_text(md)
    print(md,end='')

if __name__=='__main__': main()
