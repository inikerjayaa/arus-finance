#!/usr/bin/env python3
from __future__ import annotations
import json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
PINS = json.loads((ROOT/'toolchain/github_actions_pins.json').read_text())
WORKFLOWS = sorted((ROOT/'.github/workflows').glob('*.yml')) + sorted((ROOT/'.github/workflows').glob('*.yaml'))
uses_re = re.compile(r'^\s*-?\s*uses:\s*([^\s#]+)(?:\s*#\s*(.*))?\s*$')
sha_re = re.compile(r'^[0-9a-f]{40}$')
errors=[]
seen=set()
for wf in WORKFLOWS:
    for no,line in enumerate(wf.read_text().splitlines(),1):
        m=uses_re.match(line)
        if not m: continue
        ref=m.group(1)
        if ref.startswith('./'):
            continue
        if '@' not in ref:
            errors.append(f'{wf.relative_to(ROOT)}:{no}: action ref missing @: {ref}')
            continue
        action,rev=ref.rsplit('@',1)
        seen.add(action)
        if not sha_re.fullmatch(rev):
            errors.append(f'{wf.relative_to(ROOT)}:{no}: action must use full 40-char commit SHA: {ref}')
            continue
        pin=PINS.get(action)
        if pin is None:
            errors.append(f'{wf.relative_to(ROOT)}:{no}: action not present in audited pin manifest: {action}')
            continue
        if rev != pin['sha']:
            errors.append(f'{wf.relative_to(ROOT)}:{no}: {action} SHA differs from audited {pin["version"]} pin')
        comment=(m.group(2) or '')
        if pin['version'] not in comment:
            errors.append(f'{wf.relative_to(ROOT)}:{no}: comment must record human version {pin["version"]}')
unused=sorted(set(PINS)-seen)
if unused:
    errors.append('pin manifest contains unused actions: '+', '.join(unused))
if errors:
    print('FAIL: GitHub Actions immutable-pin contract')
    for e in errors: print(' -',e)
    sys.exit(1)
print(f'PASS: GitHub Actions immutable-pin contract ({len(WORKFLOWS)} workflows, {len(seen)} actions)')
