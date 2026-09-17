#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND = (ROOT / 'lib/shared/saku_brand.dart').read_text()
THEME = (ROOT / 'lib/shared/app_theme.dart').read_text()
SPLASH = (ROOT / 'lib/shared/saku_splash.dart').read_text()
PUBSPEC = (ROOT / 'pubspec.yaml').read_text()
LICENSE = ROOT / 'third_party/plus_jakarta_sans/OFL.txt'
SOURCE = ROOT / 'third_party/plus_jakarta_sans/SOURCE.md'
FONT_DIR = ROOT / 'assets/fonts'
FONT_SPECS = {
    'PlusJakartaSans-Regular.ttf': (400, 128972),
    'PlusJakartaSans-Medium.ttf': (500, 129180),
    'PlusJakartaSans-SemiBold.ttf': (600, 129288),
    'PlusJakartaSans-Bold.ttf': (700, 128988),
}
LIB_TEXT = '\n'.join(
    path.read_text(errors='ignore')
    for path in (ROOT / 'lib').rglob('*.dart')
)

checks = {
    'SAKU reserves Plus Jakarta Sans family': "fontFamily = 'PlusJakartaSans'" in BRAND,
    'theme consumes canonical SAKU font family': 'fontFamily: SakuBrand.fontFamily' in THEME,
    'SAKU splash uses bundled bold weight 700': 'fontWeight: FontWeight.w700' in SPLASH,
    'SAKU splash does not request unbundled weight 800': 'FontWeight.w800' not in SPLASH,
    'official OFL is committed': LICENSE.exists() and 'SIL OPEN FONT LICENSE Version 1.1' in LICENSE.read_text(),
    'upstream source policy is committed': SOURCE.exists() and 'tokotype/PlusJakartaSans' in SOURCE.read_text(),
    'pubspec registers Plus Jakarta Sans family': 'family: PlusJakartaSans' in PUBSPEC,
    'no Google Fonts runtime dependency': 'google_fonts:' not in PUBSPEC.lower() and 'GoogleFonts.' not in LIB_TEXT,
    'no Google Fonts CDN references': 'fonts.googleapis.com' not in LIB_TEXT and 'fonts.gstatic.com' not in LIB_TEXT,
}

for filename, (weight, expected_size) in FONT_SPECS.items():
    path = FONT_DIR / filename
    checks[f'{filename} is bundled with expected upstream size'] = (
        path.exists() and path.is_file() and path.stat().st_size == expected_size
    )
    checks[f'{filename} is registered at weight {weight}'] = (
        f'asset: assets/fonts/{filename}' in PUBSPEC
        and f'weight: {weight}' in PUBSPEC
    )

failed = [name for name, ok in checks.items() if not ok]
if failed:
    for name in failed:
        print(f'FAIL: {name}')
    raise SystemExit(f'V37 font policy audit failed: {len(failed)} check(s)')
print(f'PASS: V37 font policy audit {len(checks)}/{len(checks)}')
