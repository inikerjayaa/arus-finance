#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path)
    if not value.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return value.read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"FAIL: {label}: missing {needle!r}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise SystemExit(f"FAIL: {label}: forbidden {needle!r}")


brand = read("lib/shared/saku_brand.dart")
app = read("lib/app.dart")
theme = read("lib/shared/app_theme.dart")
pubspec = read("pubspec.yaml")
materializer = read("tool/materialize_brand_fonts.py")
catalog = read("lib/shared/icon_catalog.dart")
custom = read("lib/shared/custom_visual_icon.dart")
picker = read("lib/shared/icon_picker_sheet.dart")
visual_store = read("lib/core/services/visual_identity_store.dart")
roadmap = read("docs/SAKU_BRAND_FOUNDATION_V32.md")

for needle, label in [
    ("static const String appName = 'SAKU'", "public app name"),
    ("static const String fontFamily = 'PlusJakartaSans'", "font family"),
    ("Color(0xFF001621)", "NOTURNO token"),
    ("Color(0xFFFF4103)", "VULCANICO token"),
    ("Color(0xFFF0EDE4)", "SAND token"),
    ("class SakuLaunchSplash", "launch splash"),
    ("class SakuPocketMark", "logo mark"),
]:
    require(brand, needle, label)

require(app, "title: SakuBrand.appName", "Material app title")
require(app, "_launchSplashDone", "one-shot splash state")
require(app, "const SakuLaunchSplash()", "splash surface")
require(app, "minimumSplash", "minimum cold-launch presentation")
require(app, "if (state == AppLifecycleState.resumed)", "resume lifecycle")
forbid(app, "_launchSplashDone = false", "splash must not replay after construction")

require(theme, "fontFamily: SakuBrand.fontFamily", "global typography")
require(theme, "ArusThemeId.original => SakuBrand.vulcanico", "default accent")
require(theme, "ArusThemeId.original => SakuBrand.noturno", "default dark background")
require(theme, "ArusThemeId.original => SakuBrand.sand", "default light background")

for needle in [
    "family: PlusJakartaSans",
    "PlusJakartaSans-Regular.ttf",
    "PlusJakartaSans-Medium.ttf",
    "PlusJakartaSans-SemiBold.ttf",
    "PlusJakartaSans-Bold.ttf",
]:
    require(pubspec, needle, "bundled font declaration")
forbid(pubspec, "google_fonts", "runtime font dependency")

require(materializer, "18d1cd2f7ea10481919d2f05c1f7064b7307fc26", "pinned Plus Jakarta Sans source")
for blob in [
    "cb874458c3911fcb7a12da70f66e4154863c9841",
    "5d8dd8ab476e4bc9766af41d9ee0e183da2c15fe",
    "c12d4b0e72bde4d78af22aa73184024d2495bef3",
    "2d49642350842c27fc88ff90d6445eeda1766f7e",
]:
    require(materializer, blob, "font blob identity")

required_icon_keys = [
    # A
    "bank.bca", "bank.mandiri", "bank.bri", "bank.bni", "bank.btn",
    "bank.bsi", "bank.jago", "bank.seabank", "bank.blu", "bank.jenius",
    # B
    "wallet.dana", "wallet.ovo", "wallet.gopay", "wallet.shopeepay",
    # C
    "transport.gojek", "transport.grab", "transport.maxim", "transport.indrive",
    # D
    "marketplace.tokopedia", "marketplace.shopee", "marketplace.lazada",
    # E
    "subscription.youtube", "subscription.netflix", "subscription.spotify",
    # F
    "ai.chatgpt", "ai.gemini", "ai.claude", "ai.perplexity",
    # G
    "telco.telkomsel", "telco.im3", "telco.xl", "telco.indihome",
    # H
    "utility.pln", "utility.pdam", "utility.bpjs",
    # I
    "finance.cash", "finance.bank", "finance.wallet", "food.meal",
    "shopping.cart", "health.medical", "lifestyle.entertainment",
]
for key in required_icon_keys:
    require(catalog, f"key: '{key}'", f"icon catalog {key}")

for group in ["marketplace", "ai", "telco", "utility"]:
    require(catalog, f"  {group},", f"icon group {group}")
    require(picker, f"IconCatalogGroup.{group}", f"picker group {group}")
    require(visual_store, f"IconCatalogGroup.{group}", f"color mapping {group}")

require(custom, "static const String prefix = 'custom-data:'", "portable custom icon format")
require(custom, "base64Encode", "portable custom icon encoding")
require(custom, "base64Decode", "portable custom icon decoding")
require(picker, "FilePicker.platform.pickFiles", "custom picker")
require(picker, "withData: true", "custom picker bytes")
require(picker, "disimpan lokal dan ikut backup", "custom icon UX contract")
require(visual_store, "CustomVisualIconData.isValid", "custom icon persistence validation")

require(roadmap, "Public product name: **SAKU**", "brand doc")
require(roadmap, "must **not replay**", "splash doc")
require(roadmap, "must not modify the core rule", "local-first brand invariant")

print("PASS: V32 SAKU brand/font/icon foundation audit")
