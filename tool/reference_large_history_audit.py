"""Large-history SQLite reference audit for timeline and FTS search query plans."""
import sqlite3,time

N=100_000
db=sqlite3.connect(':memory:')
db.executescript('''
CREATE TABLE transactions(
 id TEXT PRIMARY KEY,
 group_primary INTEGER NOT NULL,
 type TEXT NOT NULL,
 status TEXT NOT NULL,
 primary_amount_minor INTEGER NOT NULL,
 occurred_at_utc TEXT NOT NULL,
 local_date TEXT NOT NULL,
 created_at TEXT NOT NULL,
 deleted_at TEXT
);
CREATE INDEX idx_tx_timeline ON transactions(group_primary, deleted_at, occurred_at_utc DESC, created_at DESC);
CREATE INDEX idx_tx_type_amount_date ON transactions(type, primary_amount_minor, local_date);
CREATE VIRTUAL TABLE transaction_search USING fts5(transaction_id UNINDEXED,note,type,amount,account,category,tokenize='unicode61 remove_diacritics 2');
''')
rows=[]
fts=[]
for i in range(N):
    day=(i%28)+1
    note='makan siang' if i%10==0 else 'transaksi biasa'
    amount=(i%500_000)+1
    occurred=f'2026-09-{day:02d}T12:00:{i%60:02d}Z'
    rows.append((f't{i}',1,'EXPENSE','POSTED',amount,occurred,f'2026-09-{day:02d}',occurred,None))
    fts.append((f't{i}',note,'EXPENSE',str(amount),'Bank Utama','Makanan' if i%10==0 else 'Belanja'))
db.executemany('INSERT INTO transactions VALUES (?,?,?,?,?,?,?,?,?)',rows)
db.executemany('INSERT INTO transaction_search(transaction_id,note,type,amount,account,category) VALUES (?,?,?,?,?,?)',fts)
db.commit()

plan=' '.join(str(r) for r in db.execute("EXPLAIN QUERY PLAN SELECT id FROM transactions WHERE deleted_at IS NULL AND group_primary=1 ORDER BY occurred_at_utc DESC,created_at DESC LIMIT 250").fetchall())
assert 'idx_tx_timeline' in plan, plan
start=time.perf_counter()
result=db.execute("SELECT id FROM transactions WHERE deleted_at IS NULL AND group_primary=1 ORDER BY occurred_at_utc DESC,created_at DESC LIMIT 250").fetchall()
timeline_ms=(time.perf_counter()-start)*1000
assert len(result)==250
assert timeline_ms < 100, timeline_ms

fts_plan=' '.join(str(r) for r in db.execute("EXPLAIN QUERY PLAN SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ? LIMIT 250",('"makan"*',)).fetchall())
assert 'VIRTUAL TABLE INDEX' in fts_plan.upper(), fts_plan
start=time.perf_counter()
search=db.execute("SELECT transaction_id FROM transaction_search WHERE transaction_search MATCH ? LIMIT 250",('"makan"*',)).fetchall()
search_ms=(time.perf_counter()-start)*1000
assert len(search)==250
assert search_ms < 100, search_ms

print(f'PASS: 100k timeline index ({timeline_ms:.2f} ms) + FTS5 search ({search_ms:.2f} ms) reference')
