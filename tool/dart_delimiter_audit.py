from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
errors=[]

pairs={')':'(',']':'[','}':'{'}
opens=set(pairs.values())
for f in list((root/'lib').rglob('*.dart'))+list((root/'test').rglob('*.dart')):
    s=f.read_text(errors='ignore')
    stack=[]; i=0; state='code'; quote=''; triple=False
    while i<len(s):
        c=s[i]; n=s[i+1] if i+1<len(s) else ''
        if state=='line':
            if c=='\n': state='code'
            i+=1; continue
        if state=='block':
            if c=='*' and n=='/': state='code'; i+=2
            else: i+=1
            continue
        if state=='string':
            if triple:
                if s.startswith(quote*3,i): state='code'; i+=3; triple=False; continue
                i+=1; continue
            if c=='\\': i+=2; continue
            if c==quote: state='code'
            i+=1; continue
        # code
        if c=='/' and n=='/': state='line'; i+=2; continue
        if c=='/' and n=='*': state='block'; i+=2; continue
        # raw-string prefix is harmless here; quote handling is enough for delimiter balance.
        if c in "'\"":
            quote=c; triple=s.startswith(c*3,i); state='string'; i+=3 if triple else 1; continue
        if c=='\\':
            errors.append(f'{f.relative_to(root)}: invalid backslash outside string/comment at {i}')
            break
        if c in opens: stack.append((c,i))
        elif c in pairs:
            if not stack or stack[-1][0]!=pairs[c]: errors.append(f'{f.relative_to(root)}: mismatched {c} at {i}'); break
            stack.pop()
        i+=1
    if state in ('string','block'): errors.append(f'{f.relative_to(root)}: unterminated {state}')
    if stack: errors.append(f'{f.relative_to(root)}: unclosed {stack[-1][0]}')
if errors:
    print('FAIL'); [print('-',e) for e in errors]; sys.exit(1)
print('PASS: Dart delimiter/string/comment structural audit')
