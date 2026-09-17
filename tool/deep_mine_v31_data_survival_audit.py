from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
backup = (ROOT / 'lib/core/services/backup_service.dart').read_text()
settings = (ROOT / 'lib/features/settings/settings_screen.dart').read_text()


def appears_before(text: str, first: str, second: str) -> bool:
    a = text.find(first)
    b = text.find(second)
    return a >= 0 and b >= 0 and a < b


checks = {
    'portable backup stays encrypted with Argon2id + AES-GCM': (
        "'format': 'arus-finance-encrypted-backup'" in backup
        and 'Argon2id(memory: 64 * 1024, parallelism: 2, iterations: 3, hashLength: 32)' in backup
        and 'AesGcm.with256bits()' in backup
    ),
    'portable backup rejects weak passphrases': (
        "if (value.length < 8)" in backup
        and 'Passphrase backup minimal 8 karakter.' in backup
    ),
    'portable restore captures local recovery before destructive replacement': appears_before(
        backup,
        'await createLocalRecoveryGeneration(force: true);',
        '_restoreDecodedBackup(decoded);',
    ),
    'restore replacement remains database-transaction atomic': (
        'Existing live data is unchanged if any' in backup
        and 'database.transaction((db)' in backup
        and '_validateLedger(db);' in backup
    ),
    'fresh recovery uses validated crash-safe replacement with rollback': (
        'beginFreshRecovery()' in backup
        and 'markFreshRecoveryValidated(session)' in backup
        and 'rollbackFreshRecovery(session)' in backup
        and 'finalizeFreshRecovery(session)' in backup
    ),
    'new local recovery is verified before old generations are pruned': appears_before(
        backup,
        'await _decodeLocalRecovery(pending);',
        'for (final extra in generations.skip(keep))',
    ),
    'local recovery retains multiple generations by default': (
        'int keep = 3' in backup
        and "entity.path.endsWith('.arusrecovery')" in backup
    ),
    'backup and recovery inputs are size bounded': (
        'const maxBackupBytes = 64 * 1024 * 1024;' in backup
        and 'const maxRecoveryBytes = 64 * 1024 * 1024;' in backup
    ),
    'backup payload is ledger validated before capture': (
        'database.readSnapshot((db)' in backup
        and '_validateLedger(db);' in backup
        and "'tables': tableSnapshot" in backup
    ),
    'Settings exposes user-owned data portability and integrity controls': all(
        label in settings
        for label in [
            'Backup terenkripsi',
            'Restore backup',
            'Export CSV',
            'Import CSV',
            'Buat titik pemulihan lokal',
            'Pulihkan titik lokal terbaru',
            'Periksa integritas data',
        ]
    ),
}

failed = [name for name, ok in checks.items() if not ok]
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)

if failed:
    raise SystemExit(
        f'FAIL: V31 data-survival audit {len(checks)-len(failed)}/{len(checks)}'
    )
print(f'PASS: V31 data-survival audit {len(checks)}/{len(checks)}')
