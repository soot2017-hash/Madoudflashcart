#!/usr/bin/env python3
"""8-prompt lexicographer pipeline (Masoud's spec) -> Gemini -> app pack schema.

Pipeline per word:
  P1 main lexicographer (word + SOURCE TEXT -> full JSON, senses grouped by POS)
  P2 synonyms/antonyms per sense (substitution test, no blind copying)
  P3 preposition & grammar pattern extraction (source-only)
  P4 examples + natural Persian translation
  P5 IELTS level, priority & collocations
  P6 word family
  P7 phrasal verbs / phrases (when applicable)
  P8 quality & consistency audit (gate before saving)

Output: one JSON per word in the RICH schema, plus a converter to the app's
backward-compatible card schema:
  {w, ipa, senses:[{pos, d, e, ep, p, syn, ant, prep, sep?, gram?}]}

Usage:
  export GEMINI_KEY=...            # or /tmp/gemini_key.txt
  python3 tools/card_pipeline.py --words "load" "approach" --source-dir sources/
  python3 tools/card_pipeline.py --words load --source sources/load.txt --out out/
  python3 tools/card_pipeline.py --convert out/load.json   # rich -> app schema only

The script never invents content: if Gemini is unreachable it exits non-zero
and writes nothing.
"""
import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

API = ('https://generativelanguage.googleapis.com/v1beta/models/'
       'gemini-flash-latest:generateContent')
POLLINATIONS_API = 'https://text.pollinations.ai/openai'

P1A = """You are an expert lexicographer and IELTS vocabulary specialist building flashcards for a Persian-speaking IELTS learner.

STRICT RULES:
1. Rely ONLY on the provided SOURCE TEXT (primarily Longman / LDOCE, plus optional Cambridge, Oxford, or Collocations data). Never invent definitions, grammar patterns, prepositions, or IPA pronunciations. If a source field is missing, return null (or [] for arrays)-never guess.
2. Output ONE valid JSON object only.

STEP A - return ONLY the word-level skeleton:
{{
  "word": "...",
  "ipa_uk": "..." | null,
  "ipa_us": "..." | null,
  "cefr_level": "A1"|"A2"|"B1"|"B2"|"C1"|"C2"|"unknown",
  "ielts_useful": true|false,
  "academic_word_list": true|false|"unsure",
  "pos_groups": ["noun", "verb"]  // parts of speech present in the SOURCE, in the source's order (most frequent first)
}}

SOURCE TEXT:
{source}"""

P1B = """You are an expert lexicographer and IELTS vocabulary specialist building flashcards for a Persian-speaking IELTS learner.

STRICT RULES:
1. Rely ONLY on the provided SOURCE TEXT. Never invent definitions, grammar patterns, prepositions, or IPA pronunciations. If a source field is missing, return null (or [] for arrays)-never guess.
2. Output ONE valid JSON object only: the senses for the part of speech "{pos}" ONLY.

For each sense of "{word}" as "{pos}", tag it with:
"sense_id" (int, starting at 1 for this POS), "definition_en" (faithful to source, lightly simplified without altering meaning), "definition_fa" (concise, natural Persian - never literal), "ielts_priority" ("core"|"secondary"|"peripheral"), "ielts_skills" (subset of ["writing","speaking","reading","listening"]), "register" ("formal"|"informal"|"academic"|"neutral"|null), "grammar_pattern" (from source or null), "preposition" (or null), "usage_note" (or null), "examples" (array of {{"en","fa","source":"dictionary"|"generated"}} - source examples first; at most ONE generated B2 example if the source has none; [] if neither), "synonyms" (array of {{"word","nuance"}} - ONLY words matching THIS exact sense and part of speech; [] if none truly fit), "antonyms" (array of strings - only true antonyms of THIS sense/POS; [] if none).

Return valid JSON only:
{{ "pos": "{pos}", "senses": [ ... ] }}

SOURCE TEXT:
{source}"""



P2 = """Analyze the senses of "{word}" below. For EACH sense independently, provide accurate synonyms and antonyms suited for an IELTS learner aiming for Band 7+.

RULES:
- Match the exact part of speech of each sense.
- Mental substitution test: replacing the target word in the sense's example with a synonym must keep the sentence grammatical and natural.
- 0 to 4 synonyms and 0 to 3 antonyms per sense. Use [] rather than forcing an inaccurate word.
- Do not duplicate identical synonym lists across senses unless genuinely accurate for both.
- Note formality/connotation/context differences in "nuance" and "note".

Return valid JSON only:
[ {{"sense_id": 1, "pos": "...", "synonyms": [{{"word": "...", "nuance": "..."}}], "antonyms": ["..."], "note": "..."}} ]

SENSES:
{senses}"""

P3 = """For each sense of "{word}" in the SOURCE below, extract the grammar pattern and any following preposition.

RULES:
- Use ONLY patterns and prepositions present in or directly supported by the source. Never invent fixed patterns.
- If there is no fixed pattern or preposition for a sense, use null.
- Provide a short example showing the pattern when available in the source; otherwise null.

Return valid JSON only:
[ {{"sense_id": 1, "pos": "...", "pattern": "... or null", "preposition": "... or null", "example_with_pattern": "... or null"}} ]

SOURCE:
{source}"""

P4 = """For each sense of "{word}" with part of speech "{pos}" in the SOURCE below:
1. Keep every existing dictionary example unchanged in "en" and set "source": "dictionary".
2. If a sense has NO example in the source, write ONE natural B2-level example sentence and set "source": "generated".
3. Translate each definition and example into fluent, natural Persian that captures the exact meaning in context—never word-for-word. Avoid mixed RTL/LTR punctuation glitches.

Return valid JSON only:
[ {{"sense_id": 1, "definition_fa": "...", "examples": [{{"en": "...", "fa": "...", "source": "dictionary"}}]}} ]

SOURCE:
{source}"""

P5 = """Given "{word}" and its senses/source below, determine IELTS metadata without guessing:
- "cefr_level": dictionary/CEFR evidence if present, otherwise "unknown".
- "ielts_useful": true only if common/useful in IELTS; otherwise false.
- "academic_word_list": true only if confirmed in Coxhead's AWL, false if not, "unsure" if uncertain.
- "top_senses": the 1 to 2 sense_ids most worth studying first, with a brief reason in Persian.
- "collocations": up to 3 high-value collocations grounded in the source when available.

Return valid JSON only:
{{"word": "{word}", "cefr_level": "unknown", "ielts_useful": true, "academic_word_list": "unsure",
  "top_senses": [{{"sense_id": 1, "reason_fa": "..."}}],
  "collocations": [{{"phrase": "...", "fa": "...", "ielts_context": "writing"}}]}}

SOURCE:
{source}"""

P6 = """Provide the common, real-world word family of "{word}" (noun, verb, adjective, adverb, and common negative/prefixed forms if standard).

RULES:
- Include only real, usable words—avoid obscure or archaic forms.
- Keep each Persian gloss concise and natural.

Return valid JSON only:
{{ "word_family": [ {{"word": "...", "pos": "...", "fa": "..."}} ] }}"""

P7 = """"{word}" is a phrase or phrasal verb. Using ONLY the SOURCE below, return its details in a JSON structure compatible with the flashcard schema.

RULES:
- Include "type": "phrasal_verb"|"phrase", "word": "{word}", "ipa_uk", "ipa_us", "register", and "senses".
- For phrasal verbs, specify "separability": "separable"|"inseparable"|"always_separated"|"not_applicable"|"unknown" based on the source.
- Include grammar pattern, one example per sense with natural Persian translation ("source": "dictionary" or "generated" only if missing).
- Do not invent facts missing from the source; use null or [] when absent.

Return valid JSON only.

SOURCE:
{source}"""

P8 = """Audit the flashcard JSON below against the SOURCE text and all quality rules.

CHECKLIST:
1. Are synonym or antonym lists copied blindly across different senses?
2. Does every synonym and antonym match the exact sense meaning and part of speech?
3. Are all definitions, patterns, and "dictionary" examples faithful to the source, and are any non-source examples clearly marked "source": "generated"?
4. Are grammar patterns and prepositions accurately extracted where present in the source?
5. Is all Persian natural, accurate for the sense, and free of awkward literal phrasing or broken punctuation?
6. Are missing values properly set to null or [] rather than guessed or left as empty strings?
7. Are "cefr_level", "ielts_useful", and "academic_word_list" consistent and non-guessed?

Return valid JSON only:
{{"passed": true, "issues": [{{"path": "...", "problem": "...", "fix": "..."}}]}}
Do NOT return the full corrected JSON (keep the response short).

SOURCE TEXT:
{source}

FLASHCARD JSON:
{card}"""


def load_provider() -> str:
    return os.environ.get('LLM_PROVIDER', 'pollinations')


def load_key() -> str:
    return os.environ.get('GEMINI_KEY') or (
        open('/tmp/gemini_key.txt').read().strip() if os.path.exists('/tmp/gemini_key.txt') else '')


def load_pollinations_key() -> str:
    return os.environ.get('POLLINATIONS_KEY') or (
        open('/tmp/pollinations_key.txt').read().strip()
        if os.path.exists('/tmp/pollinations_key.txt') else '')


def call_pollinations(prompt: str, retries: int = 4) -> str:
    key = load_pollinations_key()
    headers = {'Content-Type': 'application/json'}
    if key:
        headers['Authorization'] = 'Bearer ' + key
    body = json.dumps({'model': 'openai',
                       'messages': [{'role': 'system',
                                     'content': 'You are an expert lexicographer. '
                                                'Return ONLY valid JSON, no commentary.'},
                                    {'role': 'user', 'content': prompt}],
                       'temperature': 0.2,
                       'max_tokens': 8000,
                       'response_format': {'type': 'json_object'}}).encode()
    req = urllib.request.Request(POLLINATIONS_API, data=body, headers=headers)
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                d = json.load(r)
            content = d['choices'][0]['message']['content']
            if isinstance(content, str) and content.lstrip().startswith('{"error"'):
                raise urllib.error.HTTPError(POLLINATIONS_API, 502,
                                             'provider error payload', None, None)
            return content
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
            code = getattr(e, 'code', None)
            if (code in (402, 429, 500, 502, 503) or code is None) and attempt < retries - 1:
                wait = 60 * (attempt + 1)
                print(f'  retry {attempt + 1} ({type(e).__name__} {code}) in {wait}s', flush=True)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError('unreachable')


def call_gemini(key: str, prompt: str, retries: int = 4) -> str:
    body = json.dumps({'contents': [{'parts': [{'text': prompt}]}],
                       'generationConfig': {'temperature': 0.2,
                                            'responseMimeType': 'application/json'}}).encode()
    req = urllib.request.Request(API + '?key=' + key, data=body,
                                 headers={'Content-Type': 'application/json'})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                d = json.load(r)
            return d['candidates'][0]['content']['parts'][0]['text']
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 503) and attempt < retries - 1:
                wait = 30 * (attempt + 1)
                print(f'  retry {attempt + 1} (HTTP {e.code}) in {wait}s', flush=True)
                time.sleep(wait)
                continue
            raise
    raise RuntimeError('unreachable')


def jparse(text: str):
    text = text.strip()
    if text.startswith('```'):
        text = '\n'.join(l for l in text.split('\n')
                         if not l.strip().startswith('```')).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start = text.find('{')
        if start >= 0:
            depth = 0
            for i in range(start, len(text)):
                if text[i] == '{':
                    depth += 1
                elif text[i] == '}':
                    depth -= 1
                    if depth == 0:
                        return json.loads(text[start:i + 1])
        with open('/tmp/jparse_fail.txt', 'w', encoding='utf-8') as f:
            f.write(text)
        raise


def make_llm():
    provider = load_provider()
    if provider == 'pollinations':
        return call_pollinations
    if provider == 'gemini':
        key = load_key()
        if not key:
            sys.exit('ERROR: provider=gemini but no key (set GEMINI_KEY)')
        return lambda prompt, retries=4: call_gemini(key, prompt, retries)
    sys.exit(f'ERROR: unknown LLM_PROVIDER {provider!r} (pollinations | gemini)')


def run_word(word: str, source: str, out_dir: str) -> dict:
    llm = make_llm()
    retries = 6
    ck_path = os.path.join(out_dir, '.' + word.strip().replace(' ', '_') + '.ckpt.json')
    st, done = {}, []
    if os.path.exists(ck_path):
        with open(ck_path, encoding='utf-8') as f:
            ck = json.load(f)
        done = ck.pop('_done', [])
        st = ck
        print(f'  resuming from checkpoint ({len(done)} steps done)', flush=True)

    def save():
        tmp = dict(st)
        tmp['_done'] = done
        with open(ck_path, 'w', encoding='utf-8') as f:
            json.dump(tmp, f, ensure_ascii=False, indent=1)

    def step(name, fn):
        if name in done:
            return st.get(name)
        val = fn()
        st[name] = val
        done.append(name)
        save()
        return val

    print(f'== {word} ==', flush=True)
    time.sleep(15)
    skeleton = step('p1a', lambda: jparse(llm(P1A.format(source=source), retries)))
    card = {k: v for k, v in skeleton.items() if k != 'pos_groups'}
    card['senses_by_pos'] = []
    print(f'  P1a ok ({len(skeleton.get("pos_groups", []))} POS groups)', flush=True)
    for pos in skeleton.get('pos_groups', []):
        group = step('p1b_' + pos, lambda pos=pos: jparse(
            llm(P1B.format(pos=pos, word=word, source=source), retries)))
        if not any(g.get('pos') == group.get('pos', pos) for g in card['senses_by_pos']):
            card['senses_by_pos'].append({'pos': group.get('pos', pos),
                                          'senses': group.get('senses', [])})
        print(f'  P1b ok ({pos}, {len(group.get("senses", []))} senses)', flush=True)
    card['synant_by_sense'] = []
    for group in card['senses_by_pos']:
        pos = group.get('pos')
        res = step('p2_' + pos, lambda pos=pos: jparse(llm(
            P2.format(word=word, senses=json.dumps(group, ensure_ascii=False)), retries)))
        if isinstance(res, dict):
            for k in ('results', 'senses', 'synant', 'data', 'items'):
                if isinstance(res.get(k), list):
                    res = res[k]
                    break
            else:
                lists = [v for v in res.values() if isinstance(v, list)]
                res = lists[0] if lists else []
        card['synant_by_sense'].extend(res)
        print(f'  P2 ok ({pos})', flush=True)
    card['patterns_by_sense'] = step('p3', lambda: jparse(
        llm(P3.format(word=word, source=source), retries)))
    print('  P3 ok', flush=True)
    card['fa_overrides'] = []
    for group in card['senses_by_pos']:
        pos = group.get('pos')
        res = step('p4_' + pos, lambda pos=pos: jparse(llm(
            P4.format(word=word, pos=pos, source=source), retries)))
        if isinstance(res, list):
            card['fa_overrides'].extend(res)
        else:
            card['fa_overrides'].append(res)
        print(f'  P4 ok ({pos})', flush=True)
    time.sleep(15)
    card['ielts_meta'] = step('p5', lambda: jparse(
        llm(P5.format(word=word, source=source), retries)))
    print('  P5 ok', flush=True)
    time.sleep(15)
    wf = step('p6', lambda: jparse(llm(P6.format(word=word), retries)))
    card['word_family'] = wf.get('word_family', wf) if isinstance(wf, dict) else wf
    print('  P6 ok', flush=True)
    if ' ' in word.strip():
        time.sleep(15)
        card['phrase_details'] = step('p7', lambda: jparse(
            llm(P7.format(word=word, source=source), retries)))
        print('  P7 ok', flush=True)
    time.sleep(15)
    issues = []
    for group in card['senses_by_pos']:
        pos = group.get('pos')
        res = step('p8_' + pos, lambda pos=pos: jparse(llm(P8.format(
            source=source, card=json.dumps(group, ensure_ascii=False)), retries)))
        if not res.get('passed', True):
            issues.extend(res.get('issues', []))
        print(f"  P8 ok ({pos}, issues={len(res.get('issues', []))})", flush=True)
    audit = {'passed': not issues, 'issues': issues}
    if issues:
        card['audit_issues'] = issues
    path = os.path.join(out_dir, word.strip().replace('/', '_').replace(' ', '_') + '.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(card, f, ensure_ascii=False, indent=1)
    os.remove(ck_path)
    print('  saved', path, flush=True)
    return card


POS_FA = {'noun': 'اسم', 'verb': 'فعل', 'adjective': 'صفت', 'adverb': 'قید',
          'phrasal verb': 'فعل عبارتی'}


def to_app_schema(card: dict) -> dict:
    """Convert the rich pipeline output to the app's backward-compatible schema."""
    senses = []
    for group in card.get('senses_by_pos', []):
        pos = group.get('pos', '')
        for s in group.get('senses', []):
            ex = (s.get('examples') or [{}])[0]
            if not isinstance(ex, dict):
                ex = {}
            syn = [x['word'] for x in (s.get('synonyms') or [])
                   if isinstance(x, dict) and x.get('word')]
            for extra in card.get('synant_by_sense', []):
                if not isinstance(extra, dict):
                    continue
                if (extra.get('sense_id') == s.get('sense_id')
                        and (extra.get('pos') or pos) == pos):
                    xs = extra.get('synonyms')
                    if isinstance(xs, list):
                        syn = [x['word'] if isinstance(x, dict) else x
                               for x in xs if (isinstance(x, dict) and x.get('word'))
                               or isinstance(x, str)]
            sense = {'pos': pos,
                     'd': s.get('definition_en') or '',
                     'e': ex.get('en') or '',
                     'ep': ex.get('fa') or '',
                     'p': s.get('definition_fa') or '',
                     'syn': syn,
                     'ant': (s.get('antonyms') or [])}
            pat = s.get('grammar_pattern')
            if pat:
                sense['gram'] = pat
            if s.get('preposition'):
                prep = s['preposition']
                if not isinstance(prep, list):
                    prep = [p.strip() for p in str(prep).split(',') if p.strip()]
                sense['prep'] = prep
            senses.append(sense)
    ipa = card.get('ipa_uk') or ''
    if ipa and not ipa.startswith('/'):
        ipa = '/' + ipa + '/'
    return {'w': card.get('word', ''), 'ipa': ipa, 'senses': senses}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--words', nargs='+', default=[])
    ap.add_argument('--source', help='single source text file for all --words')
    ap.add_argument('--source-dir', help='sources/<word>.txt per word')
    ap.add_argument('--out', default='/tmp/cards_out')
    ap.add_argument('--convert', help='convert a rich JSON card to app schema and print')
    args = ap.parse_args()

    if args.convert:
        card = json.load(open(args.convert, encoding='utf-8'))
        print(json.dumps(to_app_schema(card), ensure_ascii=False, indent=1))
        return

    if not args.words:
        ap.error('--words required (or --convert)')
    os.makedirs(args.out, exist_ok=True)
    make_llm()
    for word in args.words:
        src_path = args.source or (args.source_dir and os.path.join(args.source_dir, word.replace(' ', '_') + '.txt'))
        if not src_path or not os.path.exists(src_path):
            sys.exit(f'ERROR: source text for "{word}" not found ({src_path}) — '
                     'the pipeline never invents source content')
        source = open(src_path, encoding='utf-8').read()
        run_word(word, source, args.out)
    print('done')


if __name__ == '__main__':
    main()
