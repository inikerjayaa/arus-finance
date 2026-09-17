#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND = (ROOT / 'lib/shared/saku_brand.dart').read_text()
THEME = (ROOT / 'lib/shared/app_theme.dart').read_text()
PUBSPEC = (ROOT / 'pubspec.yaml').read_text()
LICENSE = ROOT / 'third_party/plus_jakarta_sans/OFL.txt'
SOURCE = ROOT / 'third_party/plus_jakarta_sans/SOURCE.md'
LIB_TEXT = '\n'.join(
    path.read_text(errors='ignore')
    for path in (ROOT / 'lib').rglob('*.dart')
)

checks = {
    'SAKU reserves Plus Jakarta Sans family': "fontFamily = 'PlusJakartaSans'" in BRAND,
    'theme consumes canonical SAKU font family': 'fontFamily: SakuBrand.fontFamily' in THEME,
    'official OFL is committed': LICENSE.exists() and 'SIL OPEN FONT LICENSE Version 1.1' in LICENSE.read_text(),
    'upstream source policy is committed': SOURCE.exists() and 'tokotype/PlusJakartaSans' in SOURCE.read_text(),
    'no Google Fonts runtime dependency': 'google_fonts:' not in PUBSPEC.lower() and 'GoogleFonts.' not in LIB_TEXT,
    'no Google Fonts CDN references': 'fonts.googleapis.com' not in LIB_TEXT and 'fonts.gstatic.com' not in LIB_TEXT,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(f'V37 font policy audit failed: {len(failed)} check(s)')
print(f'PASS: V37 font policy audit {len(checks)}/{len(checks)}')
