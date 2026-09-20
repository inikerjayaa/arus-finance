"""Fail if legacy `Arus` copy re-enters user-facing Dart string literals.

Internal identifiers such as ArusThemeId, comments, and lowercase compatibility/storage
keys are intentionally outside this audit. The release product name shown to people is SAKU.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
_LEGACY = re.compile(r"\bArus\b")
# Deliberately line-scoped: current user-facing copy is single-line Dart strings.
# This avoids a regex quote matcher swallowing comments/code between unrelated quotes.
_STRING = re.compile(r"(?:r)?'(?:\\.|[^'\\])*'|(?:r)?\"(?:\\.|[^\"\\])*\"")


def main() -> int:
    failures: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("//", 1)[0]
            for match in _STRING.finditer(code):
                literal = match.group(0)
                if _LEGACY.search(literal):
                    failures.append(f"{path.relative_to(ROOT)}:{line_no}: {literal}")

    if failures:
        print("FAIL: legacy Arus user-facing copy remains in Dart strings:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1

    print("PASS: user-facing Dart strings contain no legacy Arus branding")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
