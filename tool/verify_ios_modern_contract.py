"""Post-build verifier for modern Flutter iOS runner contracts.

Run only after `flutter build ios` / `flutter build ipa`, because Flutter may
perform UIScene migration during the build. SwiftPM is the V17 default; a
Podfile is permitted only as Flutter/plugin fallback.
"""
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = ROOT / 'pubspec.yaml'
PLIST = ROOT / 'ios/Runner/Info.plist'
PROJECT = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'

if not PUBSPEC.exists():
    raise SystemExit('FAIL: pubspec.yaml tidak ditemukan.')
pubspec = PUBSPEC.read_text()
if re.search(r'enable-swift-package-manager\s*:\s*false', pubspec):
    raise SystemExit('FAIL: Swift Package Manager dinonaktifkan; V17 mewajibkan SwiftPM-first.')
if not PLIST.exists() or not PROJECT.exists():
    raise SystemExit('FAIL: iOS native shell belum lengkap.')

with PLIST.open('rb') as f:
    plist = plistlib.load(f)

if '_UIApplicationSceneManifest' in plist:
    raise SystemExit('FAIL: UIScene migration dinonaktifkan via _UIApplicationSceneManifest.')
scene = plist.get('UIApplicationSceneManifest')
if not isinstance(scene, dict) or not scene:
    raise SystemExit('FAIL: UIApplicationSceneManifest belum aktif. Jalankan Flutter 3.47 build/migration lalu ulangi verifier.')
if not plist.get('NSFaceIDUsageDescription'):
    raise SystemExit('FAIL: NSFaceIDUsageDescription hilang.')

project = PROJECT.read_text()
if 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' not in project:
    raise SystemExit('FAIL: iOS deployment target 15.0 contract hilang.')

pod = ROOT / 'ios/Podfile'
mode = 'SwiftPM-first'
if pod.exists():
    mode += ' + CocoaPods fallback present'
print(f'PASS: modern iOS contract verified ({mode}, UIScene active, iOS 15+, Face ID usage present).')
