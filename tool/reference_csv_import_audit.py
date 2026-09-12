"""Reference audit for Arus CSV import identity, idempotency and atomic rollback."""
import sqlite3

db=sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
db.executescript('''
CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT,currency TEXT,account_class TEXT);
CREATE TABLE categories(id TEXT PRIMARY KEY,name TEXT,type TEXT);
CREATE TABLE transactions(id TEXT PRIMARY KEY,type TEXT,status TEXT,amount INTEGER,currency TEXT,occurred TEXT,note TEXT);
CREATE TABLE legs(tx TEXT REFERENCES transactions(id) ON DELETE CASCADE,account TEXT REFERENCES accounts(id),delta INTEGER);
CREATE TABLE splits(tx TEXT REFERENCES transactions(id) ON DELETE CASCADE,category TEXT REFERENCES categories(id),amount INTEGER);
CREATE TABLE import_fingerprints(fingerprint TEXT PRIMARY KEY,transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE);
''')
db.execute("INSERT INTO accounts VALUES ('a','Bank','IDR','ASSET')")
db.execute("INSERT INTO categories VALUES ('c','Makanan','EXPENSE')")

def import_rows(rows):
    imported=skipped=0
    with db:
        for r in rows:
            existing=db.execute("SELECT type,status,amount,currency,occurred,note FROM transactions WHERE id=?",(r['id'],)).fetchone()
            if existing:
                expected=(r['type'],'POSTED',r['amount'],'IDR',r['occurred'],r.get('note'))
                if existing != expected:
                    raise ValueError('ID conflict')
                skipped+=1
                continue
            if db.execute("SELECT 1 FROM import_fingerprints WHERE fingerprint=?",(r['fp'],)).fetchone():
                skipped+=1
                continue
            db.execute("INSERT INTO transactions VALUES (?,?,?,?,?,?,?)",(r['id'],r['type'],'POSTED',r['amount'],'IDR',r['occurred'],r.get('note')))
            delta=r['amount'] if r['type']=='INCOME' else -r['amount']
            db.execute("INSERT INTO legs VALUES (?,?,?)",(r['id'],'a',delta))
            db.execute("INSERT INTO splits VALUES (?,?,?)",(r['id'],'c',r['amount']))
            db.execute("INSERT INTO import_fingerprints VALUES (?,?)",(r['fp'],r['id']))
            imported+=1
    return imported,skipped

row={'id':'t1','fp':'fp1','type':'EXPENSE','amount':1000,'occurred':'2026-09-09T10:00:00Z','note':None}
assert import_rows([row])==(1,0)
assert import_rows([row])==(0,1)
before=db.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
try:
    import_rows([
        {'id':'t2','fp':'fp2','type':'EXPENSE','amount':2000,'occurred':'2026-09-09T11:00:00Z','note':None},
        {'id':'t1','fp':'fp3','type':'EXPENSE','amount':9999,'occurred':'2026-09-09T10:00:00Z','note':None},
    ])
    raise AssertionError('expected conflict')
except ValueError:
    pass
after=db.execute("SELECT COUNT(*) FROM transactions").fetchone()[0]
assert before==after==1
assert db.execute("SELECT COUNT(*) FROM transactions WHERE id='t2'").fetchone()[0]==0
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
print('PASS: CSV import idempotency + conflict atomic rollback')
