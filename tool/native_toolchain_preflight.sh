#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-all}"
case "$mode" in
  bootstrap|android|ios|all) ;;
  *) echo "Usage: $0 [bootstrap|android|ios|all]" >&2; exit 2 ;;
esac

fail() { echo "FAIL: $*" >&2; exit 1; }
info() { echo "CHECK: $*"; }

PIN_FILE="toolchain/flutter_version.txt"
DART_PIN_FILE="toolchain/dart_version.txt"
[[ -f "$PIN_FILE" ]] || fail "Flutter version pin hilang: $PIN_FILE"
[[ -f "$DART_PIN_FILE" ]] || fail "Dart version pin hilang: $DART_PIN_FILE"
PINNED_FLUTTER="$(tr -d '[:space:]' < "$PIN_FILE")"
PINNED_DART="$(tr -d '[:space:]' < "$DART_PIN_FILE")"
[[ "$PINNED_FLUTTER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Flutter version pin rusak: '$PINNED_FLUTTER'"
[[ "$PINNED_DART" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Dart version pin rusak: '$PINNED_DART'"

command -v flutter >/dev/null 2>&1 || fail "Flutter SDK tidak ditemukan di PATH. Required: $PINNED_FLUTTER."
command -v dart >/dev/null 2>&1 || fail "Dart SDK tidak ditemukan di PATH (harus berasal dari Flutter SDK yang aktif)."

FLUTTER_RAW="$(flutter --version)"
printf '%s\n' "$FLUTTER_RAW"
FLUTTER_VERSION="$(printf '%s\n' "$FLUTTER_RAW" | sed -nE 's/^Flutter ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | head -1)"
[[ -n "$FLUTTER_VERSION" ]] || fail "Versi Flutter tidak dapat diparse."
[[ "$FLUTTER_VERSION" == "$PINNED_FLUTTER" ]] || fail "Flutter harus tepat $PINNED_FLUTTER untuk reproducible Arus native validation; ditemukan $FLUTTER_VERSION."

DART_RAW="$(dart --version 2>&1)"
echo "$DART_RAW"
DART_VERSION="$(printf '%s\n' "$DART_RAW" | sed -E 's/.*version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
[[ "$DART_VERSION" == "$PINNED_DART" ]] || fail "Dart harus tepat $PINNED_DART dari Flutter $PINNED_FLUTTER; ditemukan $DART_VERSION."
echo "PASS: Dart $DART_VERSION cocok dengan pinned Flutter toolchain."

grep -q 'enable-swift-package-manager:[[:space:]]*false' pubspec.yaml && fail "Swift Package Manager sengaja dinonaktifkan di pubspec; V17 baseline mewajibkan SwiftPM enabled/default."

if [[ "$mode" == "bootstrap" ]]; then
  echo "PASS: pinned Flutter/Dart bootstrap preflight ($PINNED_FLUTTER)."
  exit 0
fi

if [[ "$mode" == "android" || "$mode" == "all" ]]; then
  command -v java >/dev/null 2>&1 || fail "JDK 17 diperlukan untuk Android."
  JAVA_MAJOR="$(java -version 2>&1 | head -1 | sed -E 's/.*version "([0-9]+).*/\1/')"
  [[ "$JAVA_MAJOR" == "17" ]] || fail "Arus Android gate dikunci ke JDK 17; ditemukan JDK $JAVA_MAJOR."

  SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  [[ -n "$SDK_ROOT" ]] || fail "ANDROID_SDK_ROOT/ANDROID_HOME belum diset."
  [[ -d "$SDK_ROOT/platforms/android-36" ]] || fail "Android SDK Platform 36 belum terpasang di $SDK_ROOT."
  [[ -d "$SDK_ROOT/build-tools" ]] || fail "Android build-tools belum tersedia di $SDK_ROOT."
  info "Android SDK: $SDK_ROOT"
  echo "PASS: Android toolchain preflight (Flutter $PINNED_FLUTTER + JDK 17 + API 36)."
fi

if [[ "$mode" == "ios" || "$mode" == "all" ]]; then
  [[ "$(uname -s)" == "Darwin" ]] || fail "iOS gate memerlukan macOS."
  command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild tidak ditemukan."
  XCODE_RAW="$(xcodebuild -version)"
  echo "$XCODE_RAW"
  XCODE_MAJOR="$(printf '%s\n' "$XCODE_RAW" | sed -nE 's/^Xcode ([0-9]+).*/\1/p' | head -1)"
  [[ -n "$XCODE_MAJOR" && "$XCODE_MAJOR" -ge 26 ]] || fail "Xcode 26+ diperlukan untuk baseline submission saat ini."

  # Flutter 3.44+ uses SwiftPM by default. CocoaPods is required only when this
  # generated project/dependency graph actually falls back to a Podfile.
  if [[ -f ios/Podfile ]]; then
    command -v pod >/dev/null 2>&1 || fail "Project memakai ios/Podfile fallback tetapi CocoaPods (pod) tidak ditemukan."
    POD_VERSION="$(pod --version)"
    info "CocoaPods fallback detected: $POD_VERSION"
  else
    info "Swift Package Manager path: no ios/Podfile fallback detected."
  fi
  echo "PASS: iOS toolchain preflight (Flutter $PINNED_FLUTTER + macOS + Xcode 26+; SwiftPM-first)."
fi

if [[ "$mode" == "all" ]]; then
  echo "PASS: Android + iOS toolchain preflight."
fi
