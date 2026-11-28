#!/usr/bin/env python3
"""Fetch a word from a learner dictionary and emit SOURCE TEXT for
card_pipeline.py.

Sources:
  longman   ldoceonline.com HTML parser (tools/ldoce_fetch.py logic)
  cambridge dictionary-crawler.CambridgeCrawler
  oxford    dictionary-crawler.OxfordLearnersCrawler

Usage:
  python3 tools/dict_fetch.py -s oxford -d sources load
  python3 tools/dict_fetch.py -s cambridge -d sources load trigger
"""
import argparse
import asyncio
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))

from ldoce_fetch import extract as ldoce_extract, fetch as ldoce_fetch_html  # noqa: E402


def _s(v) -> str:
    if v is None:
        return ''
    text = str(v).strip()
    return re.sub(r'^CEFRLevel\.', '', text)


def fmt_entry(headword, pos, pronunciations, lines):
    out = [f'HEADWORD: {_s(headword) or "?"}',
           f'PART OF SPEECH: {_s(pos) or "?"}']
    prons = [p for p in pronunciations if _s(p)]
    if prons:
        out.append('PRONUNCIATION: ' + ' | '.join(prons))
    out += lines
    out.append('')
    return out


def cambridge_text(page, word: str) -> str:
    out = [f'WORD: {word}',
           'SOURCE: Cambridge Dictionary (dictionary-crawler)', '']
    for section in (page.sections or []):
        for entry in (section.entries or []):
            lines = []
            prons = [f"[{p.region}] {p.pronunciation}"
                     for p in (entry.pronunciations or [])
                     if _s(getattr(p, 'pronunciation', None))]
            for sense in (entry.senses or []):
                for defn in (sense.definitions or []):
                    if not defn or not _s(getattr(defn, 'definition', None)):
                        continue
                    head = f"SENSE — {_s(defn.definition)}"
                    if getattr(defn, 'cefr_level', None):
                        head += f" [cefr: {_s(defn.cefr_level)}]"
                    lines.append(head)
                    for ex in (defn.examples or [])[:3]:
                        en = _s(getattr(ex, 'example', None))
                        if en:
                            lines.append(f"example: {en}")
            if lines:
                out += fmt_entry(entry.headword, entry.part_of_speech,
                                 prons, lines)
    return '\n'.join(out).strip() + '\n'


def oxford_text(page, word: str) -> str:
    out = [f'WORD: {word}',
           "SOURCE: Oxford Learner's Dictionary (dictionary-crawler)", '']
    for entry in (page.definitions or []):
        lines = []
        prons = [p.phonetic for p in (entry.pronunciations or [])
                 if _s(getattr(p, 'phonetic', None))]
        for sense in (entry.senses or []):
            if not _s(getattr(sense, 'definition', None)):
                continue
            head = f"SENSE — {_s(sense.definition)}"
            if getattr(sense, 'cefr_level', None):
                head += f" [cefr: {_s(sense.cefr_level)}]"
            for lb in (sense.grammar_labels or []):
                head += f" [grammar: {lb}]"
            for lb in (sense.labels or []):
                head += f" [label: {lb}]"
            lines.append(head)
            for syn in (sense.synonyms or [])[:6]:
                lines.append(f"synonym: {_s(syn)}")
            for col in (sense.collocations or []):
                rule = _s(getattr(col, 'rule', None))
                items = ', '.join(_s(x) for x in (col.collocations_list or [])[:4])
                if items:
                    lines.append(f"collocation: {rule} — {items}" if rule
                                 else f"collocation: {items}")
            for ex in (sense.examples or [])[:3]:
                en = _s(getattr(ex, 'example', None))
                if en:
                    lines.append(f"example: {en}")
        if getattr(entry, 'cefr_level', None):
            lines.append(f"CEFR (entry): {_s(entry.cefr_level)}")
        for pv in (entry.phrasal_verbs or []):
            out.append(f"PHRASAL VERB: {_s(getattr(pv, 'phrasal_verb', pv))}")
        for idm in (entry.idioms or []):
            out.append(f"IDIOM: {_s(getattr(idm, 'idiom', idm))}")
        if lines:
            out += fmt_entry(entry.headword, entry.part_of_speech,
                             prons, lines)
    return '\n'.join(out).strip() + '\n'


async def _crawl(cls_name: str, word: str):
    from dictionary_crawler import CambridgeCrawler, OxfordLearnersCrawler
    cls = {'CambridgeCrawler': CambridgeCrawler,
           'OxfordLearnersCrawler': OxfordLearnersCrawler}[cls_name]
    async with cls() as crawler:
        return await crawler.crawl(word)


def fetch_longman(word: str) -> str:
    return ldoce_extract(ldoce_fetch_html(word), word)


def fetch_cambridge(word: str) -> str:
    return cambridge_text(asyncio.run(_crawl('CambridgeCrawler', word)), word)


def fetch_oxford(word: str) -> str:
    return oxford_text(asyncio.run(_crawl('OxfordLearnersCrawler', word)), word)


SOURCES = {
    'longman': fetch_longman,
    'cambridge': fetch_cambridge,
    'oxford': fetch_oxford,
}


def main() -> int:
    ap = argparse.ArgumentParser(description='Multi-dictionary SOURCE TEXT fetcher')
    ap.add_argument('words', nargs='+')
    ap.add_argument('-s', '--source', choices=sorted(SOURCES), default='longman')
    ap.add_argument('-d', '--dir', default='.')
    args = ap.parse_args()
    outdir = Path(args.dir)
    outdir.mkdir(parents=True, exist_ok=True)
    failures = []
    for word in args.words:
        try:
            text = SOURCES[args.source](word)
            path = outdir / f'{word.replace(" ", "_")}.{args.source}.txt'
            path.write_text(text, encoding='utf-8')
            print(f'OK   {word} ({args.source}) -> {path} ({len(text)} chars)')
        except Exception as exc:
            failures.append(word)
            print(f'FAIL {word}: {type(exc).__name__}: {str(exc)[:120]}')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
