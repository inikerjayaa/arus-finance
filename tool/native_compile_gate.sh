#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-all}"
case "$mode" in android|ios|all) ;; *) echo "Usage: $0 [android|ios|all]" >&2; exit 2 ;; esac

if [[ ! -f pubspec.lock ]]; then
  echo "FAIL: pubspec.lock belum ada. Jalankan ./bootstrap.sh pada Flutter toolchain lebih dulu." >&2
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
python3 tool/v49_lifecycle_native_patch.py
flutter pub get --enforce-lockfile
bash tool/run_all_audits.sh
flutter analyze
flutter test

if [[ "$mode" == "android" || "$mode" == "all" ]]; then
  # Compile proof only. Store-readiness/signing is intentionally NOT claimed here.
  flutter build appbundle --release
  [[ -f build/app/outputs/bundle/release/app-release.aab ]] || { echo "FAIL: expected Android AAB artifact missing." >&2; exit 1; }
  python3 tool/capture_native_evidence.py --kind android-compile --artifact build/app/outputs/bundle/release/app-release.aab
  echo "PASS: Android release-mode compile artifact built (not a store-signing claim)."
fi
if [[ "$mode" == "ios" || "$mode" == "all" ]]; then
  flutter build ios --release --no-codesign
  python3 tool/verify_ios_modern_contract.py
  [[ -d build/ios/iphoneos/Runner.app ]] || { echo "FAIL: expected iOS Runner.app artifact missing." >&2; exit 1; }
  python3 tool/capture_native_evidence.py --kind ios-compile --artifact build/ios/iphoneos/Runner.app
  echo "PASS: iOS release-mode no-codesign compile."
fi

echo "PASS: requested native COMPILE gate completed."
