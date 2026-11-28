#!/usr/bin/env python3
"""Persian text normalizer for flashcard data packs.

Fixes the recurring Persian typography issues found during the v1.38 audit:
  - Arabic Yeh (U+064A) and Kaf (U+0643) instead of Persian Yeh/Kaf
  - missing ZWNJ (نیم‌فاصله) after the verbal prefix «می»
  - IPA transcriptions not wrapped in slashes

Usage:
  python3 tools/normalize_fa.py app/packs/*.json app/index.html

Run tools/validate_packs.py afterwards to confirm the result.
"""
import re
import sys

ARABIC_TO_PERSIAN = {'\u064a': '\u06cc', '\u0643': '\u06a9'}
MI_PREFIX = re.compile(r'\u0645\u06cc (?=[\u0600-\u06FF])')  # «می» + space + Persian letter
IPA_FIELD = re.compile(r'("ipa":\s*)"([^"]*)"')


def normalize_text(text: str) -> tuple[str, int, int]:
    yk = sum(text.count(c) for c in ARABIC_TO_PERSIAN)
    mi = len(MI_PREFIX.findall(text))
    for src, dst in ARABIC_TO_PERSIAN.items():
        text = text.replace(src, dst)
    text = MI_PREFIX.sub('\u0645\u06cc\u200c', text)
    return text, yk, mi


def wrap_bare_ipa(text: str) -> tuple[str, int]:
    count = 0

    def _wrap(m):
        nonlocal count
        value = m.group(2)
        if not value or value.startswith('/'):
            return m.group(0)
        count += 1
        return m.group(1) + '"/' + value + '/"'

    return IPA_FIELD.sub(_wrap, text), count


def main(paths: list[str]) -> int:
    total_yk = total_mi = total_ipa = 0
    for path in paths:
        with open(path, encoding='utf-8') as f:
            text = f.read()
        text, yk, mi = normalize_text(text)
        if path.endswith('.json') or '__PACKS' in text:
            text, ipa = wrap_bare_ipa(text)
        else:
            ipa = 0
        if text != open(path, encoding='utf-8').read():
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
        total_yk += yk
        total_mi += mi
        total_ipa += ipa
        print(f'{path}: arabic_yk={yk} missing_zwnj={mi} bare_ipa={ipa}')
    print(f'TOTAL: arabic_yk={total_yk} missing_zwnj={total_mi} bare_ipa={total_ipa}')
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1:]))
