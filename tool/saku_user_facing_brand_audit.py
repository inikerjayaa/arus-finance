"""Fail if legacy `Arus` copy re-enters user-facing Dart string literals.

Internal identifiers such as ArusThemeId and lowercase compatibility/storage keys are
intentionally outside this audit. The release product name shown to people is SAKU.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

# Dart ordinary/raw single, double, and triple-quoted string literals.
_STRING = re.compile(
    r"(?s)(?:r)?(?:'''(.*?)'''|\"\"\"(.*?)\"\"\"|'((?:\\.|[^'\\])*)'|\"((?:\\.|[^\"\\])*)\")"
)
_LEGACY = re.compile(r"\bArus\b")


def main() -> int:
    failures: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        for match in _STRING.finditer(text):
            literal = next((part for part in match.groups() if part is not None), "")
            if not _LEGACY.search(literal):
                continue
            line = text.count("\n", 0, match.start()) + 1
            failures.append(f"{path.relative_to(ROOT)}:{line}: {literal.strip()}")

    if failures:
        print("FAIL: legacy Arus user-facing copy remains in Dart strings:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print("PASS: user-facing Dart strings contain no legacy Arus branding")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
