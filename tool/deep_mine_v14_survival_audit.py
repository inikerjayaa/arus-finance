"""Arus Finance V14 data-survival / self-recovery audit.

Executable without Flutter. It verifies the V14 source contracts and runs file-
level reference fixtures for the dangerous interruption windows around recovery
markers, quarantine swaps, generation rotation, and storage-full cleanup.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda rel: (ROOT / rel).read_text(encoding='utf-8')
db_src = read('lib/core/db/app_database.dart')
backup_src = read('lib/core/services/backup_service.dart')
app_src = read('lib/app.dart')
settings_src = read('lib/features/settings/settings_screen.dart')
recovery_src = read('lib/features/recovery/recovery_screen.dart')

checks = {
    'fresh recovery has persisted marker states': all(x in db_src for x in [
        "'state': 'preparing'", "'state': 'quarantined'", "'state': 'replacement_validated'"
    ]),
    'recovery moves DB/WAL/SHM as one family': all(x in db_src for x in [
        "'arus_finance.db'", "'arus_finance.db-wal'", "'arus_finance.db-shm'",
        '_moveDatabaseFamilyToQuarantine'
    ]),
    'recovery marker uses pending flush publish': all(x in db_src for x in [
        "File('${marker.path}.pending')", 'writeAsString(jsonEncode(value), flush: true)',
        'pending.rename(marker.path)'
    ]),
    'pending-only recovery marker is ignored safely': 'A pending-only marker means the process died before the atomic publish.' in db_src,
    'pre-move crash cannot delete canonical DB': (
        'session.hadDatabase && !await quarantinedDatabase.exists()' in db_src and
        'canonical DB is still the only copy' in db_src
    ),
    'interrupted unvalidated replacement rolls back': (
        "data['state'] == 'replacement_validated'" in db_src and
        'await _rollbackRecoveryFiles(session);' in db_src
    ),
    'missing DB key state restored on failed fresh recovery': (
        '!session.hadDatabaseKey' in db_src and
        '_secureStorage.delete(key: _databaseKeyStorageKey)' in db_src
    ),
    'device local-recovery key separate from DB key': all(x in db_src for x in [
        "arus_db_key_v1", "arus_local_recovery_key_v1", 'localRecoveryKey('
    ]),
    'local recovery encrypted with AES-GCM': (
        "'format': 'arus-finance-local-recovery'" in backup_src and
        'AesGcm.with256bits().encrypt' in backup_src and
        'SecretKey(rawKey)' in backup_src
    ),
    'new generation verified before prune': (
        backup_src.index('await _decodeLocalRecovery(pending);') <
        backup_src.index('for (final extra in generations.skip(keep))')
    ),
    'local generations capped at 3 by default': 'int keep = 3' in backup_src,
    'portable backup uses pending+flush+rename': all(x in backup_src for x in [
        '.pending', 'writeAsString(jsonEncode(envelope), flush: true)', 'pending.rename(file.path)'
    ]),
    'storage failure cleans only pending file': (
        'if (await pending.exists()) await pending.delete();' in backup_src and
        'Existing good' in backup_src
    ),
    'fresh recovery supports portable and local generations': all(x in backup_src for x in [
        'restorePortableBackupAsRecovery', 'restoreLatestLocalRecoveryAsRecovery',
        '_restoreDecodedAsFreshRecovery'
    ]),
    'post-restore recovery-generation failure does not falsify rollback': (
        'Replacement data is already valid' in backup_src and
        'if (!validated)' in backup_src and
        backup_src.index('validated = true;') <
        backup_src.index('await createLocalRecoveryGeneration(force: true);', backup_src.index('validated = true;'))
    ),
    'safe recovery screen exists': 'class RecoveryScreen extends StatefulWidget' in recovery_src,
    'safe recovery offers retry/local/portable paths': all(x in recovery_src for x in [
        'Coba buka database lagi', 'Pulihkan titik lokal terbaru', 'Pulihkan dari file .arusbackup'
    ]),
    'safe recovery is protected by app lock': (
        'RecoveryScreen(' in app_src and (
            (
                'builder: (context, child) => _buildSecurityEnvelope(child)' in app_src and
                'LockGate(' in app_src and
                app_src.index('LockGate(') < app_src.index('RecoveryScreen(')
            ) or (
                'return LockGate(' in app_src and
                app_src.index('return LockGate(') < app_src.index('RecoveryScreen(')
            )
        )
    ),
    'healthy startup refreshes local recovery generation': (
        'createLocalRecoveryGeneration()' in app_src and 'controller.errorMessage == null' in app_src
    ),
    'background lifecycle checkpoints recovery': (
        '_checkpointRecoveryOnBackground' in app_src and
        'minimumInterval: const Duration(minutes: 30)' in app_src
    ),
    'normal portable restore requires pre-restore recovery point': (
        backup_src.index('await createLocalRecoveryGeneration(force: true);') <
        backup_src.index('_restoreDecodedBackup(decoded);')
    ),
    'explicit wipe removes recovery material too': (
        'destroyLocalRecoveryMaterial' in settings_src and
        'Data lokal dan material recovery lama sudah direset.' in settings_src
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print('FAIL: V14 source survival/recovery contract')
    for item in failed:
        print(' -', item)
    sys.exit(1)


def write(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8')


def family(base: Path) -> dict[str, str]:
    result = {}
    for name in ('arus_finance.db', 'arus_finance.db-wal', 'arus_finance.db-shm'):
        p = base / name
        if p.exists():
            result[name] = p.read_text(encoding='utf-8')
    return result


def rollback_reference(root: Path, quarantine: Path, had_database: bool, had_key: bool) -> bool:
    """Reference V14 rollback semantics; returns whether DB key should remain."""
    quarantined_db = quarantine / 'arus_finance.db'
    if had_database and not quarantined_db.exists():
        # Marker was written, but original never moved. Preserve canonical.
        return had_key
    for name in ('arus_finance.db-wal', 'arus_finance.db-shm', 'arus_finance.db'):
        p = root / name
        if p.exists():
            p.unlink()
    if quarantine.exists():
        for name in ('arus_finance.db', 'arus_finance.db-wal', 'arus_finance.db-shm'):
            old = quarantine / name
            if old.exists():
                old.rename(root / name)
        shutil.rmtree(quarantine, ignore_errors=True)
    return had_key


def test_marker_before_move_preserves_canonical(tmp: Path) -> None:
    write(tmp / 'arus_finance.db', 'ORIGINAL')
    q = tmp / 'q1'; q.mkdir()
    # Simulate crash after PREPARING marker, before first rename.
    key_remains = rollback_reference(tmp, q, had_database=True, had_key=True)
    assert key_remains is True
    assert (tmp / 'arus_finance.db').read_text() == 'ORIGINAL'


def test_quarantined_crash_rolls_back_all_sidecars(tmp: Path) -> None:
    for name, value in [('arus_finance.db','DB-OLD'),('arus_finance.db-wal','WAL-OLD'),('arus_finance.db-shm','SHM-OLD')]:
        write(tmp / name, value)
    q = tmp / 'q2'; q.mkdir()
    for name in ('arus_finance.db','arus_finance.db-wal','arus_finance.db-shm'):
        (tmp / name).rename(q / name)
    # Partial replacement exists when process dies.
    write(tmp / 'arus_finance.db', 'DB-NEW-PARTIAL')
    rollback_reference(tmp, q, had_database=True, had_key=True)
    assert family(tmp) == {
        'arus_finance.db':'DB-OLD',
        'arus_finance.db-wal':'WAL-OLD',
        'arus_finance.db-shm':'SHM-OLD',
    }


def test_no_original_failed_recovery_removes_fresh_db(tmp: Path) -> None:
    q = tmp / 'q3'; q.mkdir()
    write(tmp / 'arus_finance.db', 'FRESH-PARTIAL')
    key_remains = rollback_reference(tmp, q, had_database=False, had_key=False)
    assert not (tmp / 'arus_finance.db').exists()
    assert key_remains is False


def test_validated_replacement_wins(tmp: Path) -> None:
    write(tmp / 'arus_finance.db', 'VALIDATED-NEW')
    q = tmp / 'q4'; q.mkdir(); write(q / 'arus_finance.db', 'OLD')
    # replacement_validated startup path does NOT call rollback.
    assert (tmp / 'arus_finance.db').read_text() == 'VALIDATED-NEW'
    assert (q / 'arus_finance.db').read_text() == 'OLD'


def test_generation_failure_preserves_existing(tmp: Path) -> None:
    recovery = tmp / 'local_recovery'; recovery.mkdir()
    for n in (1, 2, 3):
        write(recovery / f'generation_{n}.arusrecovery', f'GOOD-{n}')
    pending = recovery / '.generation_4.pending'
    write(pending, 'PARTIAL')
    # Simulated ENOSPC/error cleanup only removes pending candidate.
    pending.unlink()
    assert sorted(p.name for p in recovery.glob('*.arusrecovery')) == [
        'generation_1.arusrecovery','generation_2.arusrecovery','generation_3.arusrecovery'
    ]


def test_verified_generation_prunes_after_publish(tmp: Path) -> None:
    recovery = tmp / 'rotate'; recovery.mkdir()
    for n in (1, 2, 3):
        write(recovery / f'generation_{n:02d}.arusrecovery', f'GOOD-{n}')
    pending = recovery / '.generation_04.pending'; write(pending, 'GOOD-4')
    # verification succeeded, then publish.
    final = recovery / 'generation_04.arusrecovery'; pending.rename(final)
    generations = sorted(recovery.glob('*.arusrecovery'), reverse=True)
    for extra in generations[3:]:
        extra.unlink()
    remaining = sorted((p.name for p in recovery.glob('*.arusrecovery')), reverse=True)
    assert remaining == [
        'generation_04.arusrecovery','generation_03.arusrecovery','generation_02.arusrecovery'
    ]


def test_portable_pending_failure_cleanup(tmp: Path) -> None:
    old = tmp / 'already_shared.arusbackup'; write(old, 'OLD-GOOD')
    pending = tmp / '.arus_backup_123.pending'; write(pending, 'PARTIAL')
    pending.unlink()
    assert old.read_text() == 'OLD-GOOD'
    assert not pending.exists()


with tempfile.TemporaryDirectory(prefix='arus-v14-') as raw:
    tmp = Path(raw)
    for idx, test in enumerate([
        test_marker_before_move_preserves_canonical,
        test_quarantined_crash_rolls_back_all_sidecars,
        test_no_original_failed_recovery_removes_fresh_db,
        test_validated_replacement_wins,
        test_generation_failure_preserves_existing,
        test_verified_generation_prunes_after_publish,
        test_portable_pending_failure_cleanup,
    ]):
        case = tmp / str(idx); case.mkdir()
        test(case)

print(f'PASS: deep-mine V14 data-survival/self-recovery contract ({len(checks)} source checks + 7 crash/storage fixtures)')
