#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$ROOT/../arus_git_bootstrap_out}"
VERSION="V27"
FIXED_AUTHOR_NAME="Arus Finance Canonical Builder"
FIXED_AUTHOR_EMAIL="arus-finance@local.invalid"
FIXED_GIT_DATE="2026-09-12T00:00:00Z"
COMMIT_MESSAGE="Arus Finance V27 canonical Git bootstrap"
TAG_NAME="arus-v27-bootstrap"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: required command not found: $1" >&2
    exit 1
  }
}
need git
need python3
need sha256sum
need tar

# Never package known secret/signing/runtime-output files into canonical Git history.
# Search untracked workspace content too, but prune Git/build/cache directories that
# are normal in an active development checkout.
forbidden_names=(
  '.env' 'key.properties' 'ExportOptions.plist'
)
for name in "${forbidden_names[@]}"; do
  if find "$ROOT" \
      -type d \( -name '.git' -o -name '.dart_tool' -o -name 'build' -o -name '__pycache__' \) -prune -o \
      -type f -name "$name" -print -quit | grep -q .; then
    echo "FAIL: forbidden secret/config file present in canonical source: $name" >&2
    exit 1
  fi
done
if find "$ROOT" \
    -type d \( -name '.git' -o -name '.dart_tool' -o -name 'build' -o -name '__pycache__' \) -prune -o \
    -type f \( -name '*.jks' -o -name '*.keystore' -o -name '*.p12' -o -name '*.mobileprovision' -o -name '*.pem' -o -name '*.key' \) -print -quit | grep -q .; then
  echo 'FAIL: private signing/key material present in canonical source.' >&2
  exit 1
fi

is_git=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_git=1
  # A canonical bootstrap from a live repository is defined by tracked HEAD bytes,
  # not by runner metadata/cache. Refuse tracked transient or secret material.
  tracked_bad="$(git -C "$ROOT" ls-files | grep -E '(^|/)(__pycache__|\.dart_tool|build)(/|$)|(^|/)\.git(/|$)|\.pyc$|\.tmp$|\.bak$|\.orig$|(^|/)\.env$|(^|/)key\.properties$|(^|/)ExportOptions\.plist$|\.(jks|keystore|p12|mobileprovision|pem|key)$' || true)"
  if [ -n "$tracked_bad" ]; then
    echo 'FAIL: forbidden transient/secret material is tracked in canonical Git source:' >&2
    printf '%s\n' "$tracked_bad" >&2
    exit 1
  fi
  if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
    echo 'FAIL: tracked working tree differs from HEAD; commit/revert changes before canonical bootstrap.' >&2
    exit 1
  fi
else
  # Legacy/non-Git source folders must still be physically clean because no tracked
  # source-of-truth exists to separate canonical bytes from transient workspace data.
  if find "$ROOT" -type d \( -name '.git' -o -name '__pycache__' -o -name '.dart_tool' -o -name 'build' \) -print -quit | grep -q .; then
    echo 'FAIL: transient VCS/build/cache directory present in canonical source.' >&2
    exit 1
  fi
  if find "$ROOT" -type f \( -name '*.pyc' -o -name '*.tmp' -o -name '*.bak' -o -name '*.orig' \) -print -quit | grep -q .; then
    echo 'FAIL: transient/cache file present in canonical source.' >&2
    exit 1
  fi
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stage="$tmp/repo"
mkdir -p "$stage" "$OUT_DIR"

# Copy only canonical bytes. In a real Git checkout, HEAD is authoritative and
# automatically excludes .git, .dart_tool, build outputs and other untracked CI files.
if [ "$is_git" -eq 1 ]; then
  git -C "$ROOT" archive --format=tar HEAD | tar -C "$stage" -xf -
else
  tar -C "$ROOT" -cf - . | tar -C "$stage" -xf -
fi

cd "$stage"
git init -q -b main
git config core.autocrlf false
git config core.safecrlf true
git config user.name "$FIXED_AUTHOR_NAME"
git config user.email "$FIXED_AUTHOR_EMAIL"

git add -A
# Fail if .gitignore/gitattributes unexpectedly exclude canonical source files other
# than the deliberately absent runtime/build/secret paths above.
tracked_count="$(git ls-files | wc -l | tr -d ' ')"
if [ "$tracked_count" -lt 100 ]; then
  echo "FAIL: suspiciously small canonical Git tree: $tracked_count files" >&2
  exit 1
fi

GIT_AUTHOR_NAME="$FIXED_AUTHOR_NAME" \
GIT_AUTHOR_EMAIL="$FIXED_AUTHOR_EMAIL" \
GIT_AUTHOR_DATE="$FIXED_GIT_DATE" \
GIT_COMMITTER_NAME="$FIXED_AUTHOR_NAME" \
GIT_COMMITTER_EMAIL="$FIXED_AUTHOR_EMAIL" \
GIT_COMMITTER_DATE="$FIXED_GIT_DATE" \
  git commit -q --no-gpg-sign -m "$COMMIT_MESSAGE"
git tag "$TAG_NAME"

if [ -n "$(git status --porcelain=v1)" ]; then
  echo 'FAIL: deterministic staging repository is dirty after commit.' >&2
  git status --short >&2
  exit 1
fi

git fsck --full --no-dangling >/dev/null

commit_sha="$(git rev-parse HEAD)"
tree_sha="$(git rev-parse HEAD^{tree})"
branch_sha="$(git rev-parse refs/heads/main)"
tag_sha="$(git rev-parse "refs/tags/$TAG_NAME")"
[ "$commit_sha" = "$branch_sha" ] || { echo 'FAIL: main does not point at canonical commit.' >&2; exit 1; }
[ "$commit_sha" = "$tag_sha" ] || { echo 'FAIL: lightweight V27 tag does not point at canonical commit.' >&2; exit 1; }

bundle="$OUT_DIR/arus_finance_v27_canonical.bundle"
manifest="$OUT_DIR/arus_finance_v27_git_manifest.json"
files_manifest="$OUT_DIR/arus_finance_v27_tracked_files.sha256"
rm -f "$bundle" "$manifest" "$files_manifest"

git bundle create "$bundle" refs/heads/main "refs/tags/$TAG_NAME"
git bundle verify "$bundle" >/dev/null

# Hash the checked-in bytes as Git sees them, not filesystem mtimes.
git ls-files -z | while IFS= read -r -d '' path; do
  printf '%s  %s\n' "$(git show "HEAD:$path" | sha256sum | awk '{print $1}')" "$path"
done > "$files_manifest"

bundle_sha="$(sha256sum "$bundle" | awk '{print $1}')"
files_manifest_sha="$(sha256sum "$files_manifest" | awk '{print $1}')"

python3 - "$manifest" "$commit_sha" "$tree_sha" "$bundle_sha" "$files_manifest_sha" "$tracked_count" <<'PY'
import json, sys
from pathlib import Path
manifest, commit_sha, tree_sha, bundle_sha, files_manifest_sha, tracked = sys.argv[1:]
data = {
    'format': 'arus-git-bootstrap-v1',
    'milestone': 'V27',
    'branch': 'main',
    'tag': 'arus-v27-bootstrap',
    'commit_sha1': commit_sha,
    'tree_sha1': tree_sha,
    'bundle_sha256': bundle_sha,
    'tracked_files_manifest_sha256': files_manifest_sha,
    'tracked_file_count': int(tracked),
    'fixed_commit_metadata': {
        'author_name': 'Arus Finance Canonical Builder',
        'author_email': 'arus-finance@local.invalid',
        'author_and_committer_date': '2026-09-12T00:00:00Z',
        'message': 'Arus Finance V27 canonical Git bootstrap',
    },
    'runtime_claim': 'No native/compiler/device PASS is implied by this Git bootstrap.',
}
Path(manifest).write_text(json.dumps(data, indent=2, sort_keys=True) + '\n', encoding='utf-8')
PY

echo "PASS: deterministic Git bootstrap created"
echo "COMMIT_SHA=$commit_sha"
echo "TREE_SHA=$tree_sha"
echo "TRACKED_FILES=$tracked_count"
echo "BUNDLE_SHA256=$bundle_sha"
echo "BUNDLE=$bundle"
echo "MANIFEST=$manifest"
