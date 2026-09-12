# Arus Finance V27 — Immutable Git Bootstrap Handoff

## Purpose

V26 made native CI fail-closed, but the current ChatGPT GitHub connection exposes zero repositories and this host cannot install Flutter 3.47.2. V27 therefore closes the remaining *repository transport* gap without inventing compiler PASS: it turns the audited source tree into one deterministic Git commit and an offline-portable Git bundle.

## Guarantees

- Runtime `lib/` remains unchanged from V26.
- `.gitattributes` normalizes text to LF so Windows/macOS/Linux imports do not silently produce different blobs.
- Canonical Git creation occurs in a temporary copy; the audited source folder is never converted into a mutable working repository.
- Fixed author, committer, date, message, branch and lightweight tag make the Git commit reproducible for the same V27 source bytes.
- Git commit/tree identity and tracked-file manifest are reproducible. Git bundle container bytes are not assumed reproducible; each emitted bundle is bound to its own SHA-256 and independently verified.
- Known signing/private configuration (`.env`, `key.properties`, `.jks`, `.keystore`, `.p12`, `.mobileprovision`, `.pem`, `.key`) is rejected before Git history is created.
- Build/cache/VCS residue is rejected before Git history is created.
- `git fsck --full`, `git bundle verify`, clone verification, tree verification and per-tracked-file SHA-256 verification are mandatory.
- Git bootstrap evidence does **not** claim Flutter analyze/test, Android compile, iOS compile, device or store PASS.

## Create bundle

From the V27 source root:

```bash
bash tool/create_git_bootstrap_bundle.sh /path/to/output
```

Expected external artifacts:

- `arus_finance_v27_canonical.bundle`
- `arus_finance_v27_git_manifest.json`
- `arus_finance_v27_tracked_files.sha256`

## Verify bundle before import

```bash
bash tool/verify_git_bootstrap_bundle.sh \
  arus_finance_v27_canonical.bundle \
  arus_finance_v27_git_manifest.json \
  arus_finance_v27_tracked_files.sha256
```

## Import when a GitHub repository is available

Do not copy files through a browser one-by-one. Import the verified bundle:

```bash
git clone arus_finance_v27_canonical.bundle arus-finance
git -C arus-finance remote rename origin bootstrap
git -C arus-finance remote add origin <YOUR_GITHUB_REPOSITORY_URL>
git -C arus-finance push -u origin main
git -C arus-finance push origin arus-v27-bootstrap
```

Then run **Arus Dependency Lock Bootstrap**, review the generated `pubspec.lock`, commit it, and run **Arus Native Verification**.

## Current external blocker

The connected GitHub integration returned **zero accessible repositories** during V27. V27 does not create or guess a repository owner/name. The next native stage begins only after a real repository is available or a Flutter 3.47.2 host is supplied.
