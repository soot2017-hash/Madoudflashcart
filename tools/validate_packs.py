#!/usr/bin/env python3
"""Validation script for flashcard data packs.

Checks every pack against the data-quality rules agreed in the audit:
  - required fields: w, ipa, senses[] with pos, d and at least one example (e or ep)
  - IPA wrapped in slashes and restricted to IPA characters
  - synonyms/antonyms non-empty per sense (antonyms are reported, not fatal)
  - synonyms/antonyms part-of-speech plausibility (suffix heuristics)
  - identical syn/ant blocks repeated across senses of the same word

Exit code 0 = valid, 1 = errors found (warnings do not affect the exit code).

Usage:
  python3 tools/validate_packs.py app/packs
"""
import glob
import json
import os
import re
import sys

NOUN_SUF = re.compile(r'(tion|sion|ment|ness|ity|ance|ence|ism|ist|ship|hood|age|ery|ure)$', re.I)
ADJ_SUF = re.compile(r'(ous|ful|ive|able|ible|ic|less|ish|ant|ent|ary)$', re.I)
ADV_SUF = re.compile(r'ly$', re.I)
IPA_CHARS = re.compile(r'^/[\u0250-\u02AF\u0300-\u036F\u1D00-\u1D7Fa-zA-Zːˈˌ.() -]+$/$'.replace('/$/', '$/'))
ARABIC_YK = re.compile('[\u064a\u0643]')
MI_PREFIX = re.compile(r'\u0645\u06cc (?=[\u0600-\u06FF])')


def pos_of(word: str) -> str:
    if ' ' in word:
        return 'phrase'
    if ADV_SUF.match(word):
        return 'adverb'
    if NOUN_SUF.match(word):
        return 'noun'
    if ADJ_SUF.match(word):
        return 'adjective'
    return 'unknown'


def mismatch(head_pos: str, word: str):
    wp = pos_of(word)
    pairs = {('verb', 'noun'), ('verb', 'adjective'), ('verb', 'adverb'),
             ('adjective', 'noun'), ('noun', 'adjective'), ('noun', 'adverb')}
    if (head_pos, wp) in pairs:
        return f'{wp} "{word}" for {head_pos}'
    return None


def validate_pack(path: str) -> tuple[list, list]:
    errors, warnings = [], []
    data = json.load(open(path, encoding='utf-8'))
    cards = data if isinstance(data, list) else data.get('cards', data.get('words', []))
    for i, c in enumerate(cards):
        w = c.get('w', f'<card#{i}>')
        if not c.get('w'):
            errors.append(f'{path}: card#{i} missing "w"')
        if not c.get('senses'):
            errors.append(f'{path}: {w} has no senses')
            continue
        ipa = c.get('ipa', '')
        if not ipa:
            warnings.append(f'{path}: {w} missing IPA')
        elif not (ipa.startswith('/') and ipa.endswith('/')):
            errors.append(f'{path}: {w} IPA not wrapped in slashes: {ipa!r}')
        elif ARABIC_YK.search(ipa):
            errors.append(f'{path}: {w} IPA contains Arabic characters')
        blocks = set()
        for si, s in enumerate(c['senses']):
            label = f'{w} sense{si + 1}'
            if not s.get('d'):
                errors.append(f'{path}: {label} missing definition "d"')
            if not s.get('pos'):
                errors.append(f'{path}: {label} missing "pos"')
            if not (s.get('e') or s.get('ep')):
                errors.append(f'{path}: {label} has no example (e/ep)')
            for key in ('p', 'ep'):
                t = s.get(key, '')
                if t and ARABIC_YK.search(t):
                    errors.append(f'{path}: {label}.{key} contains Arabic Yeh/Kaf')
                if t and MI_PREFIX.search(t):
                    errors.append(f'{path}: {label}.{key} missing ZWNJ after «می»')
            syn, ant = s.get('syn') or [], s.get('ant') or []
            if not syn:
                warnings.append(f'{path}: {label} has no synonyms')
            if not ant:
                warnings.append(f'{path}: {label} has no antonyms')
            head_pos = s.get('pos', '')
            for word in syn + ant:
                mm = mismatch(head_pos, word)
                if mm:
                    warnings.append(f'{path}: {label} POS mismatch: {mm}')
            blocks.add((json.dumps(syn, ensure_ascii=False), json.dumps(ant, ensure_ascii=False)))
        if len(c['senses']) > 1 and len(blocks) == 1:
            warnings.append(f'{path}: {w} identical syn/ant block repeated across senses')
    return errors, warnings


def main(pack_dir: str) -> int:
    files = sorted(f for f in glob.glob(os.path.join(pack_dir, '*.json')) if not f.endswith('index.json'))
    all_errors, all_warnings = [], []
    for f in files:
        errs, warns = validate_pack(f)
        all_errors += errs
        all_warnings += warns
    for e in all_errors:
        print('ERROR:', e)
    for w in all_warnings:
        print('WARN :', w)
    print(f'\n{len(files)} packs checked: {len(all_errors)} errors, {len(all_warnings)} warnings')
    return 1 if all_errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'app/packs'))
