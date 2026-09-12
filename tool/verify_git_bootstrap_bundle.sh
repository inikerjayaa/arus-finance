#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <bundle> <manifest.json> <tracked_files.sha256>" >&2
  exit 2
fi
bundle="$1"
manifest="$2"
files_manifest="$3"
for f in "$bundle" "$manifest" "$files_manifest"; do
  [ -f "$f" ] || { echo "FAIL: missing bootstrap artifact: $f" >&2; exit 1; }
done
command -v git >/dev/null || { echo 'FAIL: git not found.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'FAIL: python3 not found.' >&2; exit 1; }
command -v sha256sum >/dev/null || { echo 'FAIL: sha256sum not found.' >&2; exit 1; }

verify_repo="$(mktemp -d)"
trap 'rm -rf "$verify_repo"' EXIT
git -C "$verify_repo" init -q -b main
git -C "$verify_repo" bundle verify "$bundle" >/dev/null

readarray -t expected < <(python3 - "$manifest" <<'PY'
import json, sys
from pathlib import Path
m=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if m.get('format') != 'arus-git-bootstrap-v1' or m.get('milestone') != 'V27':
    raise SystemExit('FAIL: unsupported Git bootstrap manifest')
for key in ('commit_sha1','tree_sha1','bundle_sha256','tracked_files_manifest_sha256','tracked_file_count'):
    if key not in m:
        raise SystemExit(f'FAIL: missing manifest key: {key}')
print(m['commit_sha1'])
print(m['tree_sha1'])
print(m['bundle_sha256'])
print(m['tracked_files_manifest_sha256'])
print(m['tracked_file_count'])
PY
)
commit_sha="${expected[0]}"
tree_sha="${expected[1]}"
expected_bundle_sha="${expected[2]}"
expected_files_sha="${expected[3]}"
expected_count="${expected[4]}"

actual_bundle_sha="$(sha256sum "$bundle" | awk '{print $1}')"
actual_files_sha="$(sha256sum "$files_manifest" | awk '{print $1}')"
[ "$actual_bundle_sha" = "$expected_bundle_sha" ] || { echo 'FAIL: Git bundle SHA-256 mismatch.' >&2; exit 1; }
[ "$actual_files_sha" = "$expected_files_sha" ] || { echo 'FAIL: tracked-files manifest SHA-256 mismatch.' >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$verify_repo" "$tmp"' EXIT
git clone -q -b main "$bundle" "$tmp/repo"
cd "$tmp/repo"
[ "$(git rev-parse HEAD)" = "$commit_sha" ] || { echo 'FAIL: cloned commit differs from manifest.' >&2; exit 1; }
[ "$(git rev-parse HEAD^{tree})" = "$tree_sha" ] || { echo 'FAIL: cloned tree differs from manifest.' >&2; exit 1; }
[ "$(git rev-parse refs/tags/arus-v27-bootstrap)" = "$commit_sha" ] || { echo 'FAIL: V27 tag mismatch.' >&2; exit 1; }
[ -z "$(git status --porcelain=v1)" ] || { echo 'FAIL: cloned bootstrap checkout is dirty.' >&2; exit 1; }
actual_count="$(git ls-files | wc -l | tr -d ' ')"
[ "$actual_count" = "$expected_count" ] || { echo "FAIL: tracked file count mismatch: $actual_count != $expected_count" >&2; exit 1; }
sha256sum -c "$files_manifest" >/dev/null

git fsck --full --no-dangling >/dev/null
echo "PASS: Git bootstrap bundle verified ($commit_sha, $actual_count tracked files)"
