"""Focused original-artwork and generated native-resource regression tests."""
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET
from unittest.mock import patch

import native_app_icon
import native_splash
from saku_artwork import ROOT, STACKED, verify_originals, read_rgb, launcher_pixels

EXPECTED = {
    'assets/saku/stacked.png': 'efcb4ef382f7f2d584aa2b581858d934289b82ac5b20146c4123e0cbace3e301',
    'assets/saku/horizontal.png': '91b253e1475da3dca808970127acf388fbc14b75e494ec369b6fd905e19d12e0',
    'native_artwork/saku/splash-reference.png': '45182e6f0407c6a8ef5ed463ae1c783992c99e4695b94785ea9fa68339bfa00f',
}

class ApprovedArtworkTest(unittest.TestCase):
    def test_originals_are_exact_approved_bytes(self):
        verify_originals()
        for path, digest in EXPECTED.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)

    def test_launcher_rendition_samples_source_pixels(self):
        # A known 2x2 image catches invented geometry/palette or broken filtering.
        pixels = bytearray([0, 0, 0, 100, 0, 0, 0, 100, 0, 100, 100, 100])
        self.assertEqual(launcher_pixels((2, 2, pixels), 2), pixels)
        self.assertEqual(launcher_pixels((2, 2, pixels), 1), bytearray([50, 50, 25]))

    def test_native_shells_use_originals_and_valid_icon_slots(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path in [*EXPECTED, 'native_artwork/saku/provenance.json']:
                dest = root / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / path, dest)
            res = root / 'android/app/src/main/res'
            (res / 'values').mkdir(parents=True)
            (res / 'values/styles.xml').write_text('<resources><style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar"/></resources>')
            appicon = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
            appicon.mkdir(parents=True)
            with patch.object(native_splash, 'ROOT', root), patch.object(native_app_icon, 'ROOT', root):
                native_splash.patch_android()
                native_splash.patch_ios()
                native_app_icon.patch_android()
                native_app_icon.patch_ios()
            original = (root / STACKED).read_bytes()
            for path in [res / 'drawable-nodpi/saku_approved_logo.png', res / 'drawable-nodpi/saku_approved_launcher.png', root / 'ios/Runner/Assets.xcassets/SakuSplashLogo.imageset/SakuSplashLogo.png']:
                self.assertEqual(path.read_bytes(), original)
            for path in res.rglob('*.xml'):
                ET.parse(path)
                self.assertNotIn('android:pathData', path.read_text())
            for density, size in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.items():
                self.assertEqual(read_rgb(res / f'mipmap-{density}/ic_launcher.png')[:2], (size, size))
            contents = json.loads((appicon / 'Contents.json').read_text())
            self.assertEqual(len(contents['images']), 19)
            for slot in contents['images']:
                size = round(float(slot['size'].split('x')[0]) * int(slot['scale'][0]))
                self.assertEqual(read_rgb(appicon / slot['filename'])[:2], (size, size))
            storyboard = root / 'ios/Runner/Base.lproj/LaunchScreen.storyboard'
            ET.parse(storyboard)
            self.assertNotIn('statusBar', storyboard.read_text())
            verify_originals(root)

if __name__ == '__main__':
    unittest.main()
