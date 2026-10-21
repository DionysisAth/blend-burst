"""Checks the translations in lib/l10n/app_*.arb against app_en.arb:
every key present, no extra keys, and the same {placeholders}.

    python3 tool/l10n/check.py            # all languages
    python3 tool/l10n/check.py el de      # some
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, 'lib/l10n')


def placeholders(text):
    """Names in {braces}, ignoring ICU plural/select branches' contents."""
    names, depth, i = set(), 0, 0
    for m in re.finditer(r'\{\s*([A-Za-z_]\w*)\s*(,|\})', text):
        names.add(m.group(1))
    return names


def main(langs):
    en = json.load(open(os.path.join(DIR, 'app_en.arb'), encoding='utf-8'))
    keys = {k for k in en if not k.startswith('@')}
    files = sorted(glob.glob(os.path.join(DIR, 'app_*.arb')))
    bad = 0
    for p in files:
        code = os.path.basename(p)[4:-4]
        if code == 'en' or (langs and code not in langs):
            continue
        try:
            t = json.load(open(p, encoding='utf-8'))
        except Exception as e:
            print(f'{code}: invalid JSON: {e}')
            bad += 1
            continue
        tk = {k for k in t if not k.startswith('@')}
        problems = []
        for k in sorted(keys - tk):
            problems.append(f'missing {k}')
        for k in sorted(tk - keys):
            problems.append(f'extra {k}')
        for k in sorted(keys & tk):
            if not isinstance(t[k], str) or not t[k].strip():
                problems.append(f'empty {k}')
                continue
            want, got = placeholders(en[k]), placeholders(t[k])
            meta = en.get('@' + k, {}).get('placeholders', {})
            want = {w for w in want if w in meta}
            got = {g for g in got if g in meta or g not in want}
            # ICU keywords (plural, select, other...) are not placeholders.
            if want - got:
                problems.append(f'{k}: lost {sorted(want - got)}')
            extra = {g for g in got - want if g not in ('plural', 'select')}
            extra = {g for g in extra if not re.search(r'\{\s*%s\s*,' % g, en[k])}
            if extra and meta:
                problems.append(f'{k}: unknown {sorted(extra)}')
        if t.get('@@locale') != code:
            problems.append(f'@@locale should be "{code}"')
        print(f'{code}: ' + ('ok' if not problems else f'{len(problems)} problems'))
        for pr in problems[:40]:
            print('   ', pr)
        bad += bool(problems)
    return bad


if __name__ == '__main__':
    sys.exit(1 if main(set(sys.argv[1:])) else 0)
