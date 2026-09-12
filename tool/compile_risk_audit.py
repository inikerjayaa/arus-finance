from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
errors=[]

method_re = re.compile(r'^\s*(?:Future<[^>]+>|Future<void>|void|bool|int|String|double|List<[^>]+>|Set<[^>]+>|Map<[^>]+>|[A-Z][A-Za-z0-9_<>? ,]*)\s+([a-z_][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:async\s*)?\{\s*$')

for path in ROOT.joinpath('lib').rglob('*.dart'):
    lines=path.read_text(encoding='utf-8').splitlines()
    sigs=[]
    in_triple=None
    for i,line in enumerate(lines):
        # crude but effective triple-string state so SQL bodies are ignored.
        for token in ("'''", '\"\"\"'):
            if line.count(token) % 2 == 1:
                if in_triple is None: in_triple=token
                elif in_triple==token: in_triple=None
        if in_triple is not None:
            continue
        stripped=line.strip()
        if i+1 < len(lines):
            b=lines[i+1].strip()
            if stripped == b and stripped and len(stripped)>=12 and not stripped.startswith(('//','///','*','/*')) and stripped not in {'},', ');', '}', '{'}:
                errors.append(f'{path.relative_to(ROOT)}:{i+1}: consecutive duplicate statement: {stripped[:100]}')
        m=method_re.match(line)
        if m and ('/data/' in str(path) or '/core/services/' in str(path)):
            sigs.append(m.group(1))
    seen=set()
    for name in sigs:
        if name in seen and name not in {'build'}:
            errors.append(f'{path.relative_to(ROOT)}: duplicate method candidate: {name}')
        seen.add(name)


# Private lower-case helper calls in production Dart are compile-critical and should resolve
# to a lower-case private method/function in the same library file. Private
# class constructors start with an upper-case letter after '_' and are ignored.
helper_call_re = re.compile(r'(?<![A-Za-z0-9_])(_[a-z][A-Za-z0-9_]*)\s*\(')
helper_def_re = re.compile(
    r'^\s*(?:[A-Za-z_][A-Za-z0-9_<>,? .]*\s+)?(_[a-z][A-Za-z0-9_]*)\s*\([^;]*\)\s*(?:async\s*)?(?:=>|\{)',
    re.M,
)
callable_field_re = re.compile(
    r'\b(?:[A-Za-z][A-Za-z0-9_<>?, ]*\s+)?Function\([^;\n]*\)\s+(_[a-z][A-Za-z0-9_]*)\s*;',
    re.M,
)
helper_scan_paths = list(ROOT.joinpath('lib').rglob('*.dart'))
for path in helper_scan_paths:
    text = path.read_text(encoding='utf-8')
    calls = set(helper_call_re.findall(text))
    defs = set(helper_def_re.findall(text))
    callable_fields = set(callable_field_re.findall(text))
    for name in sorted(calls - defs - callable_fields):
        errors.append(f'{path.relative_to(ROOT)}: unresolved private helper candidate: {name}')

if errors:
    print('FAIL: compile-risk audit')
    for e in errors: print(' -',e)
    sys.exit(1)
print('PASS: compile-risk duplicate/declaration/private-helper source audit')
