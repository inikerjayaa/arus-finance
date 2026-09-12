#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-all}"
case "$mode" in android|ios|all) ;; *) echo "Usage: $0 [android|ios|all]" >&2; exit 2 ;; esac

# Truthful semantics: `all` means BOTH. Never report PASS while silently skipping iOS.
if [[ "$mode" == "all" && "$(uname -s)" != "Darwin" ]]; then
  echo "FAIL: 'all' memerlukan macOS karena Android + iOS keduanya wajib dibuktikan. Gunakan 'android' untuk gate Android-only." >&2
  exit 1
fi
if [[ ! -f pubspec.lock ]]; then
  echo "FAIL: pubspec.lock is missing. Resolve/review dependencies first and commit the application lockfile." >&2
  exit 1
fi
if [[ "$mode" == "android" || "$mode" == "all" ]]; then
  [[ -d android ]] || { echo "FAIL: Android native shell belum ada. Jalankan ./bootstrap.sh lebih dulu." >&2; exit 1; }
fi
if [[ "$mode" == "ios" || "$mode" == "all" ]]; then
  [[ -d ios ]] || { echo "FAIL: iOS native shell belum ada. Jalankan ./bootstrap.sh lebih dulu." >&2; exit 1; }
fi

bash tool/native_toolchain_preflight.sh "$mode"
python3 tool/native_hardening.py
flutter pub get --enforce-lockfile
bash tool/run_all_audits.sh
flutter analyze
flutter test

if [[ "$mode" == "android" || "$mode" == "all" ]]; then
  python3 tool/verify_android_release_signing.py
  flutter build appbundle --release
  [[ -f build/app/outputs/bundle/release/app-release.aab ]] || { echo "FAIL: expected Android AAB artifact missing." >&2; exit 1; }
  python3 tool/capture_native_evidence.py --kind android-release --artifact build/app/outputs/bundle/release/app-release.aab
  echo "PASS: Android store-upload AAB build completed with explicit release signing contract."
fi

if [[ "$mode" == "ios" || "$mode" == "all" ]]; then
  # Store-ready gate: unlike compile gate, do NOT use --no-codesign.
  flutter build ipa --release
  python3 tool/verify_ios_modern_contract.py
  IPA_PATH="$(find build/ios/ipa -maxdepth 1 -type f -name '*.ipa' | sort | head -1)"
  [[ -n "$IPA_PATH" && -f "$IPA_PATH" ]] || { echo "FAIL: signed IPA artifact tidak ditemukan di build/ios/ipa." >&2; exit 1; }
  python3 tool/capture_native_evidence.py --kind ios-release --artifact "$IPA_PATH"
  echo "PASS: iOS signed IPA build completed."
fi

printf '\nPASS: requested STORE-RELEASE native gate completed.\n'
