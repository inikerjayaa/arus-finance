#!/usr/bin/env python3
from pathlib import Path
from saku_artwork import verify_originals, STACKED

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = (ROOT / "bootstrap.sh").read_text()
SPLASH = (ROOT / "tool/native_splash.py").read_text()
FLUTTER_SPLASH = (ROOT / "lib/shared/saku_splash.dart").read_text()

hardening_pos = BOOTSTRAP.find("python3 tool/native_hardening.py")
branding_pos = BOOTSTRAP.find("python3 tool/native_branding.py")
splash_pos = BOOTSTRAP.find("python3 tool/native_splash.py")
audit_pos = BOOTSTRAP.find("bash tool/run_all_audits.sh")

checks = {
    "native splash uses canonical Noturno": 'NOTURNO = "#001621"' in SPLASH,
    "native splash copies approved original without redrawing": "shutil.copyfile(ROOT / STACKED" in SPLASH and "android:pathData" not in SPLASH,
    "Android pre-12 launch background is generated": 'launch_background.xml' in SPLASH and '@drawable/saku_splash_logo' in SPLASH,
    "Android 12 system splash API is configured": 'android:windowSplashScreenBackground' in SPLASH and 'android:windowSplashScreenAnimatedIcon' in SPLASH,
    "Android 12 icon safe-area uses compact SAKU mark": '@drawable/saku_splash_mark' in SPLASH,
    "iOS LaunchScreen storyboard is generated": 'Base.lproj/LaunchScreen.storyboard' in SPLASH and 'SakuSplashLogo' in SPLASH,
    "iOS original launch PNG is local": 'SakuSplashLogo.png' in SPLASH,
    "native splash has no artificial delay": 'sleep(' not in SPLASH and 'Timer(' not in SPLASH and 'Future.delayed' not in SPLASH,
    "Flutter first frame remains Noturno": 'backgroundColor: SakuBrand.noturno' in FLUTTER_SPLASH,
    "Flutter first frame uses approved SAKU asset": "SakuBrand.stackedLogoAsset" in FLUTTER_SPLASH,
    "bootstrap order is hardening then branding then splash then audits": -1 not in (hardening_pos, branding_pos, splash_pos, audit_pos) and hardening_pos < branding_pos < splash_pos < audit_pos,
}

android = ROOT / "android/app/src/main/res"
if android.exists():
    generated = {
        "generated Android full logo exists": android / "drawable/saku_splash_logo.xml",
        "generated Android compact mark exists": android / "drawable/saku_splash_mark.xml",
        "generated Android launch background exists": android / "drawable/launch_background.xml",
        "generated Android 12 launch style exists": android / "values-v31/styles.xml",
    }
    checks.update({name: path.exists() for name, path in generated.items()})
    v31 = android / "values-v31/styles.xml"
    if v31.exists():
        text = v31.read_text()
        checks["generated Android 12 background is Noturno"] = "#001621" in text
        checks["generated Android 12 uses SAKU mark"] = "@drawable/saku_splash_mark" in text

ios = ROOT / "ios/Runner"
if ios.exists():
    storyboard = ios / "Base.lproj/LaunchScreen.storyboard"
    png = ios / "Assets.xcassets/SakuSplashLogo.imageset/SakuSplashLogo.png"
    contents = ios / "Assets.xcassets/SakuSplashLogo.imageset/Contents.json"
    checks["generated iOS LaunchScreen exists"] = storyboard.exists()
    checks["generated iOS launch original exists"] = png.exists()
    checks["generated iOS launch asset catalog exists"] = contents.exists()
    if storyboard.exists():
        text = storyboard.read_text()
        checks["generated iOS LaunchScreen references SAKU logo"] = 'image="SakuSplashLogo"' in text
        checks["generated iOS LaunchScreen has no fake status bar"] = "statusBar" not in text
    if png.exists():
        checks["generated iOS splash preserves original bytes"] = png.read_bytes() == (ROOT / STACKED).read_bytes()

verify_originals(ROOT)

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(f"V39 native splash audit failed: {len(failed)} check(s)")
print(f"PASS: V39 native splash audit {len(checks)}/{len(checks)}")
