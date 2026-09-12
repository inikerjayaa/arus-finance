"""Reference scale audit for 5k-row import semantics and batched preflight."""
import sqlite3,time

N=5000
db=sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
db.executescript('''
CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT,currency TEXT,account_class TEXT);
CREATE TABLE categories(id TEXT PRIMARY KEY,name TEXT,type TEXT);
CREATE TABLE transactions(id TEXT PRIMARY KEY,type TEXT,status TEXT,amount INTEGER,currency TEXT,occurred TEXT,note TEXT);
CREATE TABLE legs(tx TEXT REFERENCES transactions(id) ON DELETE CASCADE,account TEXT REFERENCES accounts(id),delta INTEGER);
CREATE TABLE splits(tx TEXT REFERENCES transactions(id) ON DELETE CASCADE,category TEXT REFERENCES categories(id),amount INTEGER);
CREATE TABLE import_fingerprints(fingerprint TEXT PRIMARY KEY,transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE);
CREATE INDEX idx_import_fp ON import_fingerprints(fingerprint);
''')
db.execute("INSERT INTO accounts VALUES ('a','Bank','IDR','ASSET')")
db.execute("INSERT INTO categories VALUES ('c','Makanan','EXPENSE')")
rows=[(f't{i}',f'fp{i}',(i%100000)+1) for i in range(N)]
start=time.perf_counter()
with db:
    for tx,fp,amount in rows:
        db.execute("INSERT INTO transactions VALUES (?,?,?,?,?,?,?)",(tx,'EXPENSE','POSTED',amount,'IDR','2026-09-09T10:00:00Z',None))
        db.execute("INSERT INTO legs VALUES (?,?,?)",(tx,'a',-amount))
        db.execute("INSERT INTO splits VALUES (?,?,?)",(tx,'c',amount))
        db.execute("INSERT INTO import_fingerprints VALUES (?,?)",(fp,tx))
elapsed=(time.perf_counter()-start)*1000
assert db.execute('SELECT COUNT(*) FROM transactions').fetchone()[0]==N
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
# Batched duplicate preflight must return every imported fingerprint without relying on a giant bind list.
found=set()
for start_i in range(0,N,400):
    chunk=[f'fp{i}' for i in range(start_i,min(start_i+400,N))]
    q=','.join('?' for _ in chunk)
    found.update(r[0] for r in db.execute(f'SELECT fingerprint FROM import_fingerprints WHERE fingerprint IN ({q})',chunk))
assert len(found)==N
print(f'PASS: 5k import atomic/reference scale + 400-bind preflight ({elapsed:.1f} ms reference)')
