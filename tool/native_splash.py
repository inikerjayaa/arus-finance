"""Wire approved original SAKU artwork into generated native launch screens."""
from __future__ import annotations
import json
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
from saku_artwork import STACKED, verify_originals

ROOT = Path(__file__).resolve().parents[1]
NOTURNO = "#001621"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

ANDROID_LOGO = f'''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="{ANDROID_NS}">
    <item android:width="240dp" android:height="240dp" android:gravity="center">
        <bitmap android:src="@drawable/saku_approved_logo" android:gravity="fill" android:filter="true"/>
    </item>
</layer-list>
'''
ANDROID_MARK = f'''<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="{ANDROID_NS}" android:inset="14%">
    <bitmap android:src="@drawable/saku_approved_logo" android:gravity="fill" android:filter="true"/>
</inset>
'''
ANDROID_LAUNCH_BACKGROUND = f'''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="{ANDROID_NS}">
    <item><shape android:shape="rectangle"><solid android:color="{NOTURNO}"/></shape></item>
    <item android:gravity="center" android:drawable="@drawable/saku_splash_logo"/>
</layer-list>
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


def patch_android():
    res = ROOT / "android/app/src/main/res"
    if not res.exists():
        return
    verify_originals(ROOT)
    original = res / "drawable-nodpi/saku_approved_logo.png"
    original.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / STACKED, original)
    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "saku_splash_mark.xml").write_text(ANDROID_MARK)
    (drawable / "saku_splash_logo.xml").write_text(ANDROID_LOGO)
    # Replace density-qualified template backgrounds too, avoiding stale launch art.
    for path in res.glob("drawable*/launch_background.xml"):
        path.write_text(ANDROID_LAUNCH_BACKGROUND)
    (drawable / "launch_background.xml").write_text(ANDROID_LAUNCH_BACKGROUND)
    base = {
        "android:windowBackground": "@drawable/launch_background",
        "android:statusBarColor": NOTURNO,
        "android:navigationBarColor": NOTURNO,
        "android:windowLightStatusBar": "false",
    }
    for styles in res.glob("values*/styles.xml"):
        _ensure_launch_style(styles, base)
    for qualifier in ("values-v31", "values-night-v31"):
        _ensure_launch_style(res / qualifier / "styles.xml", {
            **base,
            "android:windowSplashScreenBackground": NOTURNO,
            "android:windowSplashScreenAnimatedIcon": "@drawable/saku_splash_mark",
            "android:windowSplashScreenIconBackgroundColor": NOTURNO,
            "android:windowLightNavigationBar": "false",
        })


def patch_ios():
    runner = ROOT / "ios/Runner"
    if not runner.exists():
        return
    verify_originals(ROOT)
    imageset = runner / "Assets.xcassets/SakuSplashLogo.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    stale = imageset / "SakuSplashLogo.svg"
    if stale.exists():
        stale.unlink()
    shutil.copyfile(ROOT / STACKED, imageset / "SakuSplashLogo.png")
    (imageset / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "SakuSplashLogo.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")
    (runner / "Base.lproj").mkdir(parents=True, exist_ok=True)
    (runner / "Base.lproj/LaunchScreen.storyboard").write_text(IOS_STORYBOARD)


def main():
    patch_android()
    patch_ios()
    print("Native SAKU splash uses the approved original stacked PNG.")


if __name__ == "__main__":
    main()
