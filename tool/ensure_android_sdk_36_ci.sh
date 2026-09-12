#!/usr/bin/env bash
set -euo pipefail
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK_ROOT" ]] || { echo "FAIL: ANDROID_SDK_ROOT/ANDROID_HOME not set." >&2; exit 1; }
if command -v sdkmanager >/dev/null 2>&1; then
  SDKMANAGER="$(command -v sdkmanager)"
elif [[ -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]]; then
  SDKMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
else
  echo "FAIL: sdkmanager not found in hosted runner." >&2
  exit 1
fi
# Hosted GitHub runners already carry accepted Android licenses in normal use,
# but accepting them here makes a fresh/self-hosted image deterministic.
yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
"$SDKMANAGER" "platform-tools" "platforms;android-36" "build-tools;36.0.0"
[[ -d "$SDK_ROOT/platforms/android-36" ]] || { echo "FAIL: Android API 36 missing after sdkmanager." >&2; exit 1; }
echo "PASS: Android SDK API 36 / build-tools 36.0.0 available."
