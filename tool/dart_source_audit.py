from pathlib import Path
import re, sys
root=Path(__file__).resolve().parents[1]
errors=[]

# Local imports must resolve.
for f in (root/'lib').rglob('*.dart'):
    txt=f.read_text(errors='ignore')
    for imp in re.findall(r"^import\s+'([^']+)'",txt,flags=re.M):
        if imp.startswith(('dart:','package:')): continue
        target=(f.parent/imp).resolve()
        if not target.exists(): errors.append(f'{f.relative_to(root)}: missing import {imp}')

# Production must remain local-only and no historical sync shim in runtime.
prod='\n'.join(p.read_text(errors='ignore') for p in (root/'lib').rglob('*.dart') if p.name != 'schema.dart')
for token in ['package:supabase','_queueSync(','sync_operations','sync_conflicts']:
    if token.lower() in prod.lower(): errors.append(f'production token forbidden: {token}')

# Key hardening contracts.
required={
  'lib/core/db/app_database.dart':['PRAGMA synchronous = FULL','assertQuickIntegrity','unlocked_this_device'],
  'lib/core/services/backup_service.dart':['database.assertQuickIntegrity()','Backup gagal integrity check'],
  'lib/core/services/security_service.dart':['unlocked_this_device','_failedAttemptsKey','_lockUntilKey'],
  'lib/data/local_finance_repository.dart':['voidTransaction(','final DateTime Function() _clock','intended leg for DRAFT','_requirePostableDate','sourceChunkSize = 300','chunkSize = 400'],
}
for rel,tokens in required.items():
    txt=(root/rel).read_text(errors='ignore')
    for token in tokens:
        if token not in txt: errors.append(f'{rel}: missing {token}')


settings=(root/'lib/features/settings/settings_screen.dart').read_text(errors='ignore')
if settings.count('await tempFile.delete()') < 2:
    errors.append('temporary CSV/backup share files are not cleaned up')

# Common accidental mega-query regression.
repo=(root/'lib/data/local_finance_repository.dart').read_text(errors='ignore')
if 'limit: 1000000' in repo or 'LIMIT 1000000' in repo: errors.append('mega-query regression in repository')

if errors:
    print('FAIL')
    for e in errors: print('-',e)
    sys.exit(1)
print('PASS: Dart/local-only structural source audit')
