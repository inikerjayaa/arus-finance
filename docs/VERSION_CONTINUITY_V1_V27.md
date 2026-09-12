# Arus Finance — Version Continuity V1 → V27

V27 continues the same canonical local-first application. It does not introduce a new financial runtime or database schema.

V27 adds repository-transport guarantees on top of V26:

1. canonical `.gitattributes` with LF normalization and binary exemptions;
2. deterministic temporary Git repository generation;
3. secret/signing/build/cache residue rejection before commit creation;
4. fixed canonical Git commit metadata and `main` branch;
5. lightweight `arus-v27-bootstrap` tag bound to the same commit;
6. portable Git bundle generation and `git bundle verify`;
7. Git commit/tree/bundle/tracked-file manifest evidence;
8. fresh-clone verification and `git fsck --full`;
9. runtime `lib/` unchanged from V26;
10. Git bootstrap evidence explicitly does not imply native compiler/device/store PASS.
