# BUG HUNT — V27 Immutable Git Bootstrap

## Gaps found

### 1. Native CI existed, but no repository transport identity existed
V26 had immutable CI action pins and release truth states, but there was no canonical Git commit/bundle that could be imported without manual file-by-file upload. Manual upload can alter line endings, executable bits, omit dotfiles, or create an untraceable initial commit.

**Fix:** deterministic Git bootstrap creation with fixed metadata, LF normalization, Git bundle, commit/tree evidence and tracked-file SHA-256 manifest.

### 2. Canonical ZIP hash did not prove future Git checkout identity
A ZIP SHA proves the archive bytes but does not directly prove the Git object that CI will execute.

**Fix:** V27 records Git commit SHA-1, tree SHA-1, bundle SHA-256 and per-file SHA-256, then verifies a fresh clone from the bundle.

### 3. External repository remains unavailable
The active GitHub connector returned zero accessible repositories. No repository was invented or mutated.

**Status:** external blocker remains; V27 makes the handoff deterministic once a repository is available.

## Runtime impact

`lib/` is unchanged from V26. Database schema remains v9.

### 4. Bundle-byte determinism was too strong a test
Git can encode the same immutable object graph into different valid pack bytes. V27 therefore treats commit SHA, tree SHA and tracked-file manifest as reproducible identity, while binding each emitted bundle to its own SHA-256 and verifying it independently.
