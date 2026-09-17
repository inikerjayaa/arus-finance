#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKUP = (ROOT / 'lib/core/services/backup_service.dart').read_text()
BUNDLE = (ROOT / 'lib/core/services/custom_icon_backup_bundle.dart').read_text()

checks = {
    'backup imports custom icon bundle': "custom_icon_backup_bundle.dart" in BACKUP,
    'decoded backup carries custom icons': 'customIcons' in BACKUP and 'List<CustomIconBackupEntry>' in BACKUP,
    'portable capture includes referenced custom icons': "'custom_icons'" in BACKUP and 'captureReferenced()' in BACKUP,
    'custom icons remain inside encrypted clear payload': BACKUP.find("'custom_icons'") < BACKUP.find('algorithm.encrypt('),
    'decoder validates optional custom icon payload': "CustomIconBackupBundle.decode(decoded['custom_icons'])" in BACKUP,
    'legacy backup stays format v1 compatible': "decoded['format_version'] != 1" in BACKUP,
    'normal restore validates icon bytes before database replacement': (
        'restoreValidated(decoded.customIcons)' in BACKUP
        and BACKUP.find('restoreValidated(decoded.customIcons)') < BACKUP.find('_restoreDecodedBackup(decoded)')
    ),
    'fresh recovery validates icon bytes before database replacement': (
        BACKUP.count('restoreValidated(decoded.customIcons)') >= 2
        and BACKUP.rfind('restoreValidated(decoded.customIcons)') < BACKUP.find('_restoreDecodedAsFreshRecovery(decoded)')
    ),
    'bundle bounds icon count': 'maxEntries = 64' in BUNDLE,
    'bundle bounds total icon bytes': 'maxTotalBytes = 8 * 1024 * 1024' in BUNDLE,
    'bundle validates sha256 identity': 'sha256.convert(bytes).toString()' in BUNDLE,
    'bundle rejects duplicate custom keys': '!seen.add(key)' in BUNDLE,
    'bundle capture only scans account/category references': "const ['accounts', 'categories']" in BUNDLE,
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if failed:
    raise SystemExit(f'V36 custom icon backup audit failed: {len(failed)} check(s)')
print(f'PASS: V36 custom icon backup audit {len(checks)}/{len(checks)}')
