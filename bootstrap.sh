#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

bash tool/native_toolchain_preflight.sh bootstrap

if [[ -d android || -d ios ]]; then
  if [[ "${ARUS_REGENERATE_NATIVE:-0}" != "1" ]]; then
    echo "FAIL: android/ atau ios/ sudah ada. Bootstrap sengaja fail-closed agar tidak menimpa signing/native edits." >&2
    echo "Gunakan tool/native_hardening.py + native gates untuk shell yang sudah ada." >&2
    echo "Jika memang ingin regenerate dari nol, set ARUS_REGENERATE_NATIVE=1 secara eksplisit." >&2
    exit 1
  fi
fi

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

# Generate native shells OUTSIDE the canonical source tree so flutter create
# cannot rewrite pubspec/lib/docs/tool files. Only android/ and ios/ are copied in.
flutter create \
  --platforms=android,ios \
  --org com.arus \
  --project-name arus_finance \
  "$TMP_ROOT/arus_native_shell"

rm -rf android ios
cp -a "$TMP_ROOT/arus_native_shell/android" ./android
cp -a "$TMP_ROOT/arus_native_shell/ios" ./ios

python3 tool/native_hardening.py
python3 tool/native_branding.py
python3 tool/native_splash.py
bash tool/run_all_audits.sh
if [[ -f pubspec.lock ]]; then
  flutter pub get --enforce-lockfile
else
  flutter pub get
fi
[[ -f pubspec.lock ]] || { echo "FAIL: flutter pub get tidak menghasilkan pubspec.lock." >&2; exit 1; }
flutter analyze
flutter test

printf '\nBootstrap complete. Native shells were staged safely outside the source tree.\n'
printf 'Next compile proof: bash tool/native_compile_gate.sh android\n'
printf 'Store release requires explicit signing: see docs/NATIVE_SETUP.md\n'
