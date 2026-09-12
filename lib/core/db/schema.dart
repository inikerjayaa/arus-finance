const int kSchemaVersion = 9;

const List<String> kSchemaStatements = [
  '''CREATE TABLE IF NOT EXISTS app_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    account_class TEXT NOT NULL CHECK(account_class IN ('ASSET','LIABILITY')),
    account_type TEXT NOT NULL,
    currency TEXT NOT NULL,
    include_available INTEGER NOT NULL DEFAULT 1,
    include_net_worth INTEGER NOT NULL DEFAULT 1,
    archived_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    parent_id TEXT REFERENCES categories(id),
    type TEXT NOT NULL CHECK(type IN ('EXPENSE','INCOME')),
    name TEXT NOT NULL,
    archived_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE IF NOT EXISTS transaction_groups (
    id TEXT PRIMARY KEY,
    group_type TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    transaction_group_id TEXT REFERENCES transaction_groups(id),
    group_primary INTEGER NOT NULL DEFAULT 1,
    type TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('POSTED','DRAFT','SCHEDULED','VOIDED')),
    primary_amount_minor INTEGER NOT NULL CHECK(primary_amount_minor >= 0),
    primary_currency TEXT NOT NULL,
    occurred_at_utc TEXT NOT NULL,
    local_date TEXT NOT NULL,
    note TEXT,
    original_transaction_id TEXT REFERENCES transactions(id),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    version INTEGER NOT NULL DEFAULT 1
  )''',
  '''CREATE TABLE IF NOT EXISTS transaction_legs (
    id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    account_id TEXT NOT NULL REFERENCES accounts(id),
    delta_minor INTEGER NOT NULL,
    currency TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS transaction_splits (
    id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    category_id TEXT NOT NULL REFERENCES categories(id),
    amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
    currency TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS budgets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    limit_minor INTEGER NOT NULL CHECK(limit_minor >= 0),
    currency TEXT NOT NULL,
    category_id TEXT REFERENCES categories(id),
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    archived_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS bills (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    expected_amount_minor INTEGER NOT NULL CHECK(expected_amount_minor >= 0),
    currency TEXT NOT NULL,
    due_date TEXT NOT NULL,
    status TEXT NOT NULL,
    paid_transaction_id TEXT REFERENCES transactions(id),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS recurring_rules (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    mode TEXT NOT NULL,
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    currency TEXT NOT NULL,
    account_id TEXT NOT NULL REFERENCES accounts(id),
    category_id TEXT NOT NULL REFERENCES categories(id),
    day_of_month INTEGER NOT NULL CHECK(day_of_month BETWEEN 1 AND 31),
    next_run TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS import_fingerprints (
    fingerprint TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS recurring_occurrences (
    id TEXT PRIMARY KEY,
    rule_id TEXT NOT NULL REFERENCES recurring_rules(id),
    occurrence_key TEXT NOT NULL,
    transaction_id TEXT REFERENCES transactions(id),
    scheduled_for TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE(rule_id, occurrence_key)
  )''',

  '''CREATE VIRTUAL TABLE IF NOT EXISTS transaction_search USING fts5(
    transaction_id UNINDEXED,
    note,
    type,
    amount,
    account,
    category,
    tokenize='unicode61 remove_diacritics 2'
  )''',
  "INSERT INTO transaction_search(transaction_search, rank) VALUES('secure-delete', 1)",
  '''CREATE TRIGGER IF NOT EXISTS trg_tx_search_insert AFTER INSERT ON transactions BEGIN
    INSERT INTO transaction_search(transaction_id,note,type,amount,account,category)
    VALUES (NEW.id,COALESCE(NEW.note,''),NEW.type,CAST(NEW.primary_amount_minor AS TEXT),'','');
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_tx_search_update AFTER UPDATE OF note,type,primary_amount_minor ON transactions BEGIN
    UPDATE transaction_search
       SET note=COALESCE(NEW.note,''), type=NEW.type, amount=CAST(NEW.primary_amount_minor AS TEXT)
     WHERE transaction_id=NEW.id;
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_tx_search_delete AFTER DELETE ON transactions BEGIN
    DELETE FROM transaction_search WHERE transaction_id=OLD.id;
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_leg_search_insert AFTER INSERT ON transaction_legs BEGIN
    UPDATE transaction_search
       SET account=COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=NEW.transaction_id),'')
     WHERE transaction_id=NEW.transaction_id;
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_leg_search_delete AFTER DELETE ON transaction_legs BEGIN
    UPDATE transaction_search
       SET account=COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=OLD.transaction_id),'')
     WHERE transaction_id=OLD.transaction_id;
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_split_search_insert AFTER INSERT ON transaction_splits BEGIN
    UPDATE transaction_search
       SET category=COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=NEW.transaction_id),'')
     WHERE transaction_id=NEW.transaction_id;
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_split_search_delete AFTER DELETE ON transaction_splits BEGIN
    UPDATE transaction_search
       SET category=COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=OLD.transaction_id),'')
     WHERE transaction_id=OLD.transaction_id;
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_account_search_rename AFTER UPDATE OF name ON accounts BEGIN
    UPDATE transaction_search
       SET account=COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=transaction_search.transaction_id),'')
     WHERE transaction_id IN (SELECT transaction_id FROM transaction_legs WHERE account_id=NEW.id);
  END''',
  '''CREATE TRIGGER IF NOT EXISTS trg_category_search_rename AFTER UPDATE OF name ON categories BEGIN
    UPDATE transaction_search
       SET category=COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=transaction_search.transaction_id),'')
     WHERE transaction_id IN (SELECT transaction_id FROM transaction_splits WHERE category_id=NEW.id);
  END''',
  '''CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(local_date)''',
  '''CREATE INDEX IF NOT EXISTS idx_tx_group ON transactions(transaction_group_id)''',
  '''CREATE INDEX IF NOT EXISTS idx_legs_account ON transaction_legs(account_id)''',
  '''CREATE INDEX IF NOT EXISTS idx_splits_category ON transaction_splits(category_id)''',
  '''CREATE INDEX IF NOT EXISTS idx_tx_status_date ON transactions(status, deleted_at, occurred_at_utc DESC)''',
  '''CREATE INDEX IF NOT EXISTS idx_tx_timeline ON transactions(group_primary, deleted_at, occurred_at_utc DESC, created_at DESC)''',
  '''CREATE INDEX IF NOT EXISTS idx_recurring_due ON recurring_rules(active, next_run)''',
  '''CREATE INDEX IF NOT EXISTS idx_tx_type_amount_date ON transactions(type, primary_amount_minor, local_date)''',
  '''CREATE UNIQUE INDEX IF NOT EXISTS idx_bills_paid_tx_unique ON bills(paid_transaction_id) WHERE paid_transaction_id IS NOT NULL''',
  '''CREATE INDEX IF NOT EXISTS idx_splits_transaction ON transaction_splits(transaction_id)''',
  '''CREATE INDEX IF NOT EXISTS idx_legs_transaction ON transaction_legs(transaction_id)''',
];

const Map<int, List<String>> kSchemaMigrations = {
  2: [
    'ALTER TABLE bills ADD COLUMN paid_transaction_id TEXT REFERENCES transactions(id)',
  ],
  3: [
    'DROP TABLE IF EXISTS sync_conflicts',
    'DROP TABLE IF EXISTS sync_operations',
  ],
  4: [
    // V3 keyed occurrences by rule version. If a rule was edited after a draft
    // was materialized, one calendar occurrence could exist more than once.
    // Keep one dedupe marker per rule/date before normalizing the key; do not
    // silently delete the extra DRAFT transaction itself.
    '''DELETE FROM recurring_occurrences
       WHERE rowid NOT IN (
         SELECT MIN(rowid) FROM recurring_occurrences
         GROUP BY rule_id, substr(scheduled_for,1,10)
       )''',
    // Normalize recurring occurrence identity so rule-version changes cannot duplicate one scheduled occurrence.
    "UPDATE recurring_occurrences SET occurrence_key = rule_id || ':' || substr(scheduled_for,1,10)",
    // Legacy recurring drafts did not persist the intended account leg. Backfill it from the rule.
    '''INSERT INTO transaction_legs(id, transaction_id, account_id, delta_minor, currency)
       SELECT lower(hex(randomblob(16))), t.id, rr.account_id,
              CASE WHEN a.account_class='ASSET' THEN -t.primary_amount_minor ELSE t.primary_amount_minor END,
              t.primary_currency
       FROM transactions t
       JOIN recurring_occurrences ro ON ro.transaction_id=t.id
       JOIN recurring_rules rr ON rr.id=ro.rule_id
       JOIN accounts a ON a.id=rr.account_id
       WHERE t.status='DRAFT' AND t.deleted_at IS NULL
         AND NOT EXISTS (SELECT 1 FROM transaction_legs l WHERE l.transaction_id=t.id)''',
  ],
  5: [
    // Recurring monthly schedule is a floating local calendar date, not an absolute UTC instant.
    "UPDATE recurring_rules SET next_run = substr(next_run,1,10) WHERE length(next_run) > 10",
  ],
  6: [
    '''CREATE TABLE IF NOT EXISTS import_fingerprints (
      fingerprint TEXT PRIMARY KEY,
      transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_legs_transaction ON transaction_legs(transaction_id)',
    'CREATE INDEX IF NOT EXISTS idx_splits_transaction ON transaction_splits(transaction_id)',
    'CREATE INDEX IF NOT EXISTS idx_tx_type_amount_date ON transactions(type, primary_amount_minor, local_date)',
    'CREATE INDEX IF NOT EXISTS idx_tx_timeline ON transactions(group_primary, deleted_at, occurred_at_utc DESC, created_at DESC)',
  ],
  7: [
    '''CREATE VIRTUAL TABLE IF NOT EXISTS transaction_search USING fts5(
      transaction_id UNINDEXED,
      note,
      type,
      amount,
      account,
      category,
      tokenize='unicode61 remove_diacritics 2'
    )''',
    "INSERT INTO transaction_search(transaction_search, rank) VALUES('secure-delete', 1)",
    '''CREATE TRIGGER IF NOT EXISTS trg_tx_search_insert AFTER INSERT ON transactions BEGIN
      INSERT INTO transaction_search(transaction_id,note,type,amount,account,category)
      VALUES (NEW.id,COALESCE(NEW.note,''),NEW.type,CAST(NEW.primary_amount_minor AS TEXT),'','');
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_tx_search_update AFTER UPDATE OF note,type,primary_amount_minor ON transactions BEGIN
      UPDATE transaction_search SET note=COALESCE(NEW.note,''),type=NEW.type,amount=CAST(NEW.primary_amount_minor AS TEXT) WHERE transaction_id=NEW.id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_tx_search_delete AFTER DELETE ON transactions BEGIN
      DELETE FROM transaction_search WHERE transaction_id=OLD.id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_leg_search_insert AFTER INSERT ON transaction_legs BEGIN
      UPDATE transaction_search SET account=COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=NEW.transaction_id),'') WHERE transaction_id=NEW.transaction_id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_leg_search_delete AFTER DELETE ON transaction_legs BEGIN
      UPDATE transaction_search SET account=COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=OLD.transaction_id),'') WHERE transaction_id=OLD.transaction_id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_split_search_insert AFTER INSERT ON transaction_splits BEGIN
      UPDATE transaction_search SET category=COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=NEW.transaction_id),'') WHERE transaction_id=NEW.transaction_id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_split_search_delete AFTER DELETE ON transaction_splits BEGIN
      UPDATE transaction_search SET category=COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=OLD.transaction_id),'') WHERE transaction_id=OLD.transaction_id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_account_search_rename AFTER UPDATE OF name ON accounts BEGIN
      UPDATE transaction_search SET account=COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=transaction_search.transaction_id),'') WHERE transaction_id IN (SELECT transaction_id FROM transaction_legs WHERE account_id=NEW.id);
    END''',
    '''CREATE TRIGGER IF NOT EXISTS trg_category_search_rename AFTER UPDATE OF name ON categories BEGIN
      UPDATE transaction_search SET category=COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=transaction_search.transaction_id),'') WHERE transaction_id IN (SELECT transaction_id FROM transaction_splits WHERE category_id=NEW.id);
    END''',
    '''INSERT INTO transaction_search(transaction_id,note,type,amount,account,category)
       SELECT t.id,COALESCE(t.note,''),t.type,CAST(t.primary_amount_minor AS TEXT),
              COALESCE((SELECT group_concat(a.name,' ') FROM transaction_legs l JOIN accounts a ON a.id=l.account_id WHERE l.transaction_id=t.id),''),
              COALESCE((SELECT group_concat(c.name,' ') FROM transaction_splits s JOIN categories c ON c.id=s.category_id WHERE s.transaction_id=t.id),'')
       FROM transactions t''',
  ],
  8: [
    "UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING' WHERE paid_transaction_id IS NOT NULL AND rowid NOT IN (SELECT MIN(rowid) FROM bills WHERE paid_transaction_id IS NOT NULL GROUP BY paid_transaction_id)",
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_bills_paid_tx_unique ON bills(paid_transaction_id) WHERE paid_transaction_id IS NOT NULL',
  ],
  9: [
    "UPDATE bills SET paid_transaction_id=NULL,status='UPCOMING' WHERE paid_transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)",
    "UPDATE recurring_occurrences SET transaction_id=NULL WHERE transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)",
    "UPDATE transactions SET status='VOIDED',original_transaction_id=NULL WHERE type='REFUND' AND original_transaction_id IN (SELECT id FROM transactions WHERE deleted_at IS NOT NULL)",
    "DELETE FROM transactions WHERE deleted_at IS NOT NULL",
    "DELETE FROM transaction_groups WHERE NOT EXISTS (SELECT 1 FROM transactions WHERE transaction_group_id=transaction_groups.id)",
  ],
};
