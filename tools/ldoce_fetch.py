#!/usr/bin/env python3
"""Fetch a word from Longman (ldoceonline.com) and emit clean SOURCE TEXT
for card_pipeline.py. Python port of the ldoce-mcp-server parser
(https://github.com/edgardamasceno-dev/ldoce-mcp-server).

Usage:
  python3 tools/ldoce_fetch.py load word2 ...        -> one <word>.txt per word (cwd)
  python3 tools/ldoce_fetch.py -d sources load ...   -> into a directory
"""
import argparse
import re
import sys
import urllib.request
from pathlib import Path

from bs4 import BeautifulSoup

BASE = "https://www.ldoceonline.com/dictionary/"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")


def clean(node) -> str:
    """Text of a node, dropping tag-name bubbles and scripts."""
    for bad in node.find_all(["script", "style", "span.fa-volume-up"]):
        bad.decompose()
    text = node.get_text(" ", strip=True)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s+([,.;:?!])", r"\1", text)
    return text.strip()


def fetch(word: str) -> str:
    url = BASE + urllib.request.quote(word)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        html = r.read().decode("utf-8", "replace")
    return html


def extract(html: str, word: str) -> str:
    soup = BeautifulSoup(html, "lxml")
    out = [f"WORD: {word}", "SOURCE: Longman Dictionary of Contemporary English (ldoceonline.com)", ""]

    for entry in soup.select(".Entry"):
        head = entry.select_one(".Head")
        lines = []
        if head:
            hwd = head.select_one(".HWD")
            if hwd:
                lines.append(f"HEADWORD: {clean(hwd)}")
            pron = head.select_one(".PRON")
            ame = head.select_one(".AMEVARPRON")
            if pron:
                br = clean(pron).replace("$", "").strip()
                am = clean(ame).replace("$", "").strip() if ame else ""
                lines.append(f"PRONUNCIATION BrE: /{br}/" + (f"  AmE: /{am}/" if am else ""))
            gram = head.select_one(".GRAM")
            if gram:
                lines.append(f"GRAMMAR (headword): {clean(gram)}")
            pos = head.select_one(".POS")
            if pos:
                lines.append(f"PART OF SPEECH: {clean(pos)}")
            signpost = entry.select_one(".SIGNPOST")
            if signpost:
                lines.append(f"SIGNPOST: {clean(signpost)}")
        if lines:
            out += lines + [""]

        for sense in entry.select(".Sense"):
            parts = []
            num = sense.select_one(".sensenum")
            if num:
                parts.append(clean(num).rstrip("."))
            defn = sense.select_one(".DEF")
            if defn:
                parts.append(clean(defn))
            gram = sense.select_one(".GRAM")
            if gram:
                parts.append(f"[grammar: {clean(gram)}]")
            for gx in sense.select(".GramExa"):
                g = gx.select_one(".GRAM")
                e = gx.select_one(".EXAMPLE")
                if g:
                    parts.append(f"[pattern: {clean(g)}]")
                if e:
                    parts.append(f"example: {clean(e)}")
            for col in sense.select(".Collos, .COLLO"):
                ex = col.select_one(".EXAMPLE")
                t = clean(col)
                if ex and ex.get_text(strip=True) in t:
                    t = t.replace(ex.get_text(strip=True), "").strip(" |,;")
                if t:
                    parts.append(f"collocation: {t}")
            for ex in sense.select(".EXAMPLE"):
                t = clean(ex)
                if t and f"example: {t}" not in " ".join(parts):
                    parts.append(f"example: {t}")
            if len(parts) > (1 if num else 0):
                out.append("SENSE " + " — ".join(parts))

        for box in entry.select(".USAGE, .Wordfinder, .Thes"):
            title = box.select_one(".title")
            t = clean(box)
            if t:
                label = f"{title.get_text(strip=True).upper()}" if title else "NOTE"
                out.append(f"{label}: {t}")
        origin = entry.select_one(".WordOrigin")
        if origin:
            out.append(f"ORIGIN: {clean(origin)}")
        out.append("")

    return "\n".join(out).strip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description="Fetch LDOCE source text for pipeline words")
    ap.add_argument("words", nargs="+")
    ap.add_argument("-d", "--dir", default=".", help="output directory (default: cwd)")
    args = ap.parse_args()
    outdir = Path(args.dir)
    outdir.mkdir(parents=True, exist_ok=True)
    failures = []
    for word in args.words:
        try:
            text = extract(fetch(word), word)
            path = outdir / f"{word.replace(' ', '_')}.txt"
            path.write_text(text, encoding="utf-8")
            print(f"OK   {word} -> {path} ({len(text)} chars)")
        except Exception as exc:
            failures.append(word)
            print(f"FAIL {word}: {type(exc).__name__}: {str(exc)[:120]}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
