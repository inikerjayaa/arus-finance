/// Conservative per-value envelope for the local integer-money engine.
///
/// SQLite INTEGER is signed 64-bit. Keeping every stored money value at or
/// below 9e12 IDR leaves enough aggregate headroom for roughly one million
/// maximum-sized same-sign rows before a SQLite SUM approaches int64 limits.
/// This is a technical safety boundary, not a financial/product limit target.
const int kMaxMoneyMinor = 9_000_000_000_000;
