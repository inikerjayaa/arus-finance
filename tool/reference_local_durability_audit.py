"""SQLite durability reference tests for the Arus local-only storage contract.
These tests validate WAL/transaction semantics independently of Flutter bindings.
"""
from __future__ import annotations
import os, sqlite3, subprocess, sys, tempfile
from pathlib import Path


def connect(path: Path):
    db = sqlite3.connect(path)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('PRAGMA synchronous=FULL')
    db.execute('PRAGMA foreign_keys=ON')
    return db


def test_crash_before_commit(tmp: Path):
    path = tmp/'crash.db'
    db=connect(path)
    db.execute('CREATE TABLE ledger(id INTEGER PRIMARY KEY, amount INTEGER NOT NULL)')
    db.execute('INSERT INTO ledger(amount) VALUES (100)')
    db.commit(); db.close()
    code=f'''import os, sqlite3\np={str(path)!r}\ndb=sqlite3.connect(p)\ndb.execute("PRAGMA journal_mode=WAL")\ndb.execute("PRAGMA synchronous=FULL")\ndb.execute("BEGIN IMMEDIATE")\ndb.execute("INSERT INTO ledger(amount) VALUES (999)")\nos._exit(77)\n'''
    subprocess.run([sys.executable,'-c',code], check=False)
    db=connect(path)
    vals=[r[0] for r in db.execute('SELECT amount FROM ledger ORDER BY id')]
    db.close()
    assert vals==[100], vals


def test_commit_survives_reopen(tmp: Path):
    path=tmp/'commit.db'; db=connect(path)
    db.execute('CREATE TABLE ledger(id INTEGER PRIMARY KEY, amount INTEGER NOT NULL)')
    db.execute('BEGIN IMMEDIATE'); db.execute('INSERT INTO ledger(amount) VALUES (321)'); db.commit(); db.close()
    db=connect(path); vals=[r[0] for r in db.execute('SELECT amount FROM ledger')]; db.close()
    assert vals==[321], vals


def test_database_full_rolls_back_group(tmp: Path):
    path=tmp/'full.db'; db=connect(path)
    db.execute('PRAGMA page_size=1024')
    db.execute('CREATE TABLE tx(id INTEGER PRIMARY KEY, note TEXT NOT NULL)')
    db.execute('INSERT INTO tx(note) VALUES (?)',('baseline',)); db.commit()
    current=db.execute('PRAGMA page_count').fetchone()[0]
    db.execute(f'PRAGMA max_page_count={current+2}')
    try:
        db.execute('BEGIN IMMEDIATE')
        # Enough data to exceed the deliberately tiny remaining database capacity.
        for i in range(50): db.execute('INSERT INTO tx(note) VALUES (?)',('X'*800,))
        db.commit()
        raise AssertionError('Expected SQLITE_FULL did not occur')
    except sqlite3.DatabaseError as exc:
        try: db.rollback()
        except sqlite3.DatabaseError: pass
        assert 'full' in str(exc).lower() or 'disk' in str(exc).lower(), exc
    vals=[r[0] for r in db.execute('SELECT note FROM tx ORDER BY id')]
    db.close()
    assert vals==['baseline'], len(vals)


def main():
    with tempfile.TemporaryDirectory(prefix='arus_durability_') as d:
        tmp=Path(d)
        test_crash_before_commit(tmp)
        test_commit_survives_reopen(tmp)
        test_database_full_rolls_back_group(tmp)
    print('PASS: local SQLite durability / crash / SQLITE_FULL contract')

if __name__=='__main__': main()
