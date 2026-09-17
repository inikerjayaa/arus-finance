"""Generate deterministic native SAKU launch visuals after native branding.

The canonical source tree intentionally does not commit android/ or ios/. This
script patches the generated shells during bootstrap so the OS launch surface
matches the first Flutter frame without adding a runtime/network dependency.
"""
from __future__ import annotations

import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NOTURNO = "#001621"
VULCANICO = "#FF4103"
VULCANICO_SHADE = "#E83A02"
SKIN = "#FFB48F"
ON_NOTURNO = "#FDFCF9"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

_MARK_PATHS = f'''    <path android:fillColor="{VULCANICO}" android:pathData="M50,78 Q120,55 190,78 L186,148 Q182,174 128,176 L91,176 Q50,172 48,140 Z"/>
    <path android:fillColor="{VULCANICO_SHADE}" android:pathData="M165,75 Q205,100 180,164 Q162,177 143,173 Q174,120 165,75 Z"/>
    <path android:fillColor="{SKIN}" android:pathData="M90,28 L150,50 L145,92 Q120,105 84,88 Z"/>
    <group android:rotation="-10" android:pivotX="105" android:pivotY="40">
        <path android:fillColor="{ON_NOTURNO}" android:pathData="M65,12 H145 Q155,12 155,22 V58 Q155,68 145,68 H65 Q55,68 55,58 V22 Q55,12 65,12 Z"/>
    </group>
    <path android:fillColor="@android:color/transparent" android:strokeColor="{NOTURNO}" android:strokeWidth="5.5" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M55,86 Q118,110 184,83"/>
    <path android:fillColor="@android:color/transparent" android:strokeColor="{NOTURNO}" android:strokeWidth="4.5" android:strokeLineCap="round" android:pathData="M70,125 H82 M91,124 H103 M112,123 H124 M133,122 H145 M154,121 H166"/>
    <path android:fillColor="{NOTURNO}" android:pathData="M174,96 A8,8 0,1 0,190 96 A8,8 0,1 0,174 96"/>
    <path android:fillColor="@android:color/transparent" android:strokeColor="{VULCANICO}" android:strokeWidth="7" android:strokeLineCap="round" android:pathData="M170,55 L176,40 M185,65 L202,52"/>'''

_WORD_PATHS = f'''    <path android:fillColor="@android:color/transparent" android:strokeColor="{ON_NOTURNO}" android:strokeWidth="9" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M32,196 C32,187 44,184 56,189 C67,194 66,204 56,207 L41,211 C31,214 31,224 41,228 C52,232 64,228 68,221"/>
    <path android:fillColor="@android:color/transparent" android:strokeColor="{ON_NOTURNO}" android:strokeWidth="9" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M83,229 L99,188 L115,229 M89,214 H109"/>
    <path android:fillColor="@android:color/transparent" android:strokeColor="{ON_NOTURNO}" android:strokeWidth="9" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M132,188 V229 M132,209 L157,188 M132,209 L160,229"/>
    <path android:fillColor="@android:color/transparent" android:strokeColor="{ON_NOTURNO}" android:strokeWidth="9" android:strokeLineCap="round" android:strokeLineJoin="round" android:pathData="M176,188 V214 C176,235 208,235 208,214 V188"/>'''

ANDROID_MARK = f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="{ANDROID_NS}"
    android:width="180dp"
    android:height="150dp"
    android:viewportWidth="240"
    android:viewportHeight="200">
{_MARK_PATHS}
</vector>
'''

ANDROID_LOGO = f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="{ANDROID_NS}"
    android:width="210dp"
    android:height="210dp"
    android:viewportWidth="240"
    android:viewportHeight="240">
{_MARK_PATHS}
{_WORD_PATHS}
</vector>
'''

ANDROID_LAUNCH_BACKGROUND = f'''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="{ANDROID_NS}">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="{NOTURNO}"/>
        </shape>
    </item>
    <item android:gravity="center" android:drawable="@drawable/saku_splash_logo"/>
</layer-list>
'''

IOS_LOGO_SVG = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240">
  <path fill="{VULCANICO}" d="M50 78 Q120 55 190 78 L186 148 Q182 174 128 176 L91 176 Q50 172 48 140 Z"/>
  <path fill="{VULCANICO_SHADE}" d="M165 75 Q205 100 180 164 Q162 177 143 173 Q174 120 165 75 Z"/>
  <path fill="{SKIN}" d="M90 28 L150 50 L145 92 Q120 105 84 88 Z"/>
  <path fill="{ON_NOTURNO}" d="M65 12 H145 Q155 12 155 22 V58 Q155 68 145 68 H65 Q55 68 55 58 V22 Q55 12 65 12 Z" transform="rotate(-10 105 40)"/>
  <path d="M55 86 Q118 110 184 83" fill="none" stroke="{NOTURNO}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M70 125 H82 M91 124 H103 M112 123 H124 M133 122 H145 M154 121 H166" fill="none" stroke="{NOTURNO}" stroke-width="4.5" stroke-linecap="round"/>
  <circle cx="182" cy="96" r="8" fill="{NOTURNO}"/>
  <path d="M170 55 L176 40 M185 65 L202 52" fill="none" stroke="{VULCANICO}" stroke-width="7" stroke-linecap="round"/>
  <g fill="none" stroke="{ON_NOTURNO}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
    <path d="M32 196 C32 187 44 184 56 189 C67 194 66 204 56 207 L41 211 C31 214 31 224 41 228 C52 232 64 228 68 221"/>
    <path d="M83 229 L99 188 L115 229 M89 214 H109"/>
    <path d="M132 188 V229 M132 209 L157 188 M132 209 L160 229"/>
    <path d="M176 188 V214 C176 235 208 235 208 214 V188"/>
  </g>
</svg>
'''

IOS_STORYBOARD = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21762" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21754"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="414" height="896"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView clipsSubviews="YES" userInteractionEnabled="NO" contentMode="scaleAspectFit" image="SakuSplashLogo" translatesAutoresizingMaskIntoConstraints="NO" id="saku-logo">
                                <rect key="frame" x="87" y="328" width="240" height="240"/>
                                <constraints>
                                    <constraint firstAttribute="width" constant="240" id="saku-width"/>
                                    <constraint firstAttribute="height" constant="240" id="saku-height"/>
                                </constraints>
                            </imageView>
                        </subviews>
                        <color key="backgroundColor" red="0.0" green="0.0862745098" blue="0.1294117647" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="saku-logo" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="saku-center-x"/>
                            <constraint firstItem="saku-logo" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="saku-center-y"/>
                        </constraints>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="SakuSplashLogo" width="240" height="240"/>
    </resources>
</document>
'''


def _ensure_launch_style(path: Path, items: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        tree = ET.parse(path)
        root = tree.getroot()
    else:
        root = ET.Element("resources")
        tree = ET.ElementTree(root)
    style = root.find("./style[@name='LaunchTheme']")
    if style is None:
        style = ET.SubElement(root, "style", {"name": "LaunchTheme", "parent": "Theme.AppCompat.DayNight"})
    for name, value in items.items():
        item = next((node for node in style.findall("item") if node.attrib.get("name") == name), None)
        if item is None:
            item = ET.SubElement(style, "item", {"name": name})
        item.text = value
    try:
        ET.indent(tree, space="    ")
    except AttributeError:
        pass
    tree.write(path, encoding="utf-8", xml_declaration=True)


def patch_android() -> None:
    res = ROOT / "android/app/src/main/res"
    if not res.exists():
        return
    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "saku_splash_mark.xml").write_text(ANDROID_MARK)
    (drawable / "saku_splash_logo.xml").write_text(ANDROID_LOGO)
    (drawable / "launch_background.xml").write_text(ANDROID_LAUNCH_BACKGROUND)

    base_items = {
        "android:windowBackground": "@drawable/launch_background",
        "android:statusBarColor": NOTURNO,
        "android:navigationBarColor": NOTURNO,
        "android:windowLightStatusBar": "false",
    }
    for styles in res.glob("values*/styles.xml"):
        if styles.parent.name == "values-v31":
            continue
        _ensure_launch_style(styles, base_items)

    # Android 12+ owns the first system splash frame. A compact pocket mark is
    # used inside the OS icon safe-area; Flutter immediately follows with the
    # full mark + SAKU wordmark, avoiding masked/cropped horizontal branding.
    _ensure_launch_style(
        res / "values-v31/styles.xml",
        {
            "android:windowSplashScreenBackground": NOTURNO,
            "android:windowSplashScreenAnimatedIcon": "@drawable/saku_splash_mark",
            "android:windowSplashScreenIconBackgroundColor": NOTURNO,
            "android:statusBarColor": NOTURNO,
            "android:navigationBarColor": NOTURNO,
            "android:windowLightStatusBar": "false",
            "android:windowLightNavigationBar": "false",
        },
    )


def patch_ios() -> None:
    runner = ROOT / "ios/Runner"
    if not runner.exists():
        return
    imageset = runner / "Assets.xcassets/SakuSplashLogo.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    (imageset / "SakuSplashLogo.svg").write_text(IOS_LOGO_SVG)
    (imageset / "Contents.json").write_text(
        json.dumps(
            {
                "images": [{"filename": "SakuSplashLogo.svg", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
                "properties": {"preserves-vector-representation": True},
            },
            indent=2,
        )
        + "\n"
    )
    (runner / "Base.lproj/LaunchScreen.storyboard").write_text(IOS_STORYBOARD)


def main() -> None:
    patch_android()
    patch_ios()
    print("Native SAKU splash applied (Noturno + deterministic local vector artwork).")


if __name__ == "__main__":
    main()
