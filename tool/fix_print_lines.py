#!/usr/bin/env python3
"""Put the line breaks of 18 surah openings back where the Madinah print has them.

The King Fahd 1421 Madinah print (the one ShiaNur's DigitalKhatt text follows)
puts the banner of these 18 surahs on the LAST line of the previous page, which
then has 14 lines of text; the surah's own page opens with the basmala and 14
lines of text:

    4, 10, 22, 23, 24, 26, 27, 32, 33, 37, 38, 45, 47, 53, 60, 64, 65, 80

The upstream data moved those banners to the new page instead: the previous
page was stretched to 15 lines and the new one squeezed into 13 (its lines were
too long, so the whole page was drawn smaller).

Input: tool/print_lines_1421.json — for every verse on those 36 pages, the
print line of each word (Quran.com word field line_v2) and its glyph codes
(code_v2). Each page keeps exactly the same verses; only line breaks move.

Fields rewritten, for those verses only:
  quran_data.dart: aya_text, aya_text_othmanic, qcfData, line_start, line_end
  dk_data.dart:    dkAyahText
A break is the one character between two words turned into a newline (or back
into a space), so no character offset moves and every tajwid colour run in
dk_data.dart stays on its letters. Word and glyph counts are asserted per verse.

    python3 tool/fix_print_lines.py           # rewrite the data files
    python3 tool/fix_print_lines.py --check   # exit 1 if a file would change
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QDATA = os.path.join(ROOT, 'lib/src/data/quran_data.dart')
DKDATA = os.path.join(ROOT, 'lib/src/data/dk_data.dart')
PRINT = json.load(open(os.path.join(ROOT, 'tool/print_lines_1421.json'), encoding='utf8'))
VERSES = PRINT['verses']

BANNER_ON_PREVIOUS_PAGE = [4, 10, 22, 23, 24, 26, 27, 32, 33, 37, 38, 45, 47, 53, 60, 64, 65, 80]

SEP = re.compile(r'([  \n])')
DIGITS = re.compile(r'^(?:۝)?[٠-٩]+$')


def word_owner(tokens):
    """For each token, the index of the real word it belongs to.

    ۞ belongs to the word after it; the verse-end number (or ۝N) and a lone
    ۩ belong to the word before it.
    """
    owners, real = [], -1
    pending_hizb = False
    for tok in tokens:
        if tok == '۞':
            owners.append(None)
            pending_hizb = True
            continue
        if DIGITS.match(tok) or tok == '۩':
            owners.append(real)
            continue
        real += 1
        owners.append(real)
        if pending_hizb:
            owners[-2] = real
            pending_hizb = False
    return owners, real + 1


def tokens_of(text):
    body = text[:-1] if text.endswith('\n') else text
    parts = SEP.split(body)
    return parts[0::2], parts[1::2]


def recut(text, lines, key, field, trailing, like=None):
    """Re-break [text] (real newlines) so a new line starts where [lines] changes.

    [like]: another field of the same verse whose tokens match this one's one
    for one (the othmanic glyph text writes the verse number as a glyph, so its
    words are told apart through aya_text).
    """
    tokens, seps = tokens_of(text)
    if like is None:
        owners, words = word_owner(tokens)
    else:
        like_tokens, _ = tokens_of(like)
        if len(like_tokens) != len(tokens):
            raise SystemExit(f'{field} {key}: {len(tokens)} tokens, aya_text has {len(like_tokens)}')
        owners, words = word_owner(like_tokens)
    if words != len(lines):
        raise SystemExit(f'{field} {key}: {words} words, print has {len(lines)}')
    out = []
    for j, tok in enumerate(tokens):
        out.append(tok)
        if j < len(seps):
            a, b = owners[j], owners[j + 1]
            brk = a != b and lines[a] != lines[b]
            sep = seps[j]
            out.append('\n' if brk else (' ' if sep == '\n' else sep))
    new = ''.join(out)
    if trailing:
        new += '\n'
    return new


ALIGNED = []  # verses whose QCF glyphs differ from the print's (aligned, not equal)


def recut_glyphs(text, glyphs, lines, key, trailing):
    """Re-break the QCF glyph string at the print's word lines.

    Our glyph string can differ from the print table by a sign glyph here and
    there, so the two are aligned glyph by glyph; a glyph with no partner goes
    with the glyph before it.
    """
    import difflib
    flat = text.replace('\n', '')
    ours = [c for c in flat if c != ' ']
    seq, owner, w = [], [], 0
    word_line = []
    for g, kind in glyphs:
        if kind == 'word':
            ln = lines[w]
            w += 1
        else:
            ln = word_line[-1] if word_line else lines[0]
        word_line.append(ln)
        for c in g:
            seq.append(c)
            owner.append(ln)
    line_of = [None] * len(ours)
    sm = difflib.SequenceMatcher(None, ours, seq, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            for d in range(i2 - i1):
                line_of[i1 + d] = owner[j1 + d]
    if ours != seq:
        ALIGNED.append(key)
    if line_of and line_of[0] is None:
        line_of[0] = next(x for x in line_of if x is not None)
    for i in range(1, len(line_of)):
        if line_of[i] is None:
            line_of[i] = line_of[i - 1]
    out, gi, prev = [], 0, None
    for ch in flat:
        if ch == ' ':
            out.append(' ')
            continue
        ln = line_of[gi]
        gi += 1
        if prev is not None and ln != prev:
            if out and out[-1] == ' ':
                out[-1] = '\n'
            else:
                out.append('\n')
        out.append(ch)
        prev = ln
    new = ''.join(out)
    if trailing:
        new = new.rstrip(' ') + '\n'
    return new


def dart_dq(s):
    """The source form of a value in quran_data.dart (a JSON string)."""
    return json.dumps(s, ensure_ascii=False)


def main(check):
    qsrc = open(QDATA, encoding='utf8').read()
    dksrc = open(DKDATA, encoding='utf8').read()
    body = qsrc[qsrc.index('['):qsrc.rindex(']') + 1]
    quran = json.loads(re.sub(r',(\s*[}\]])', r'\1', body))
    keys = [f"{v['sora']}:{v['aya_no']}" for v in quran]

    dk_start = dksrc.index('const List<String> dkAyahText = [')
    dk_end = dksrc.index('];', dk_start)
    dk_matches = list(re.finditer(r"^  '((?:[^'\\]|\\.)*)',$", dksrc[dk_start:dk_end], re.M))
    assert len(dk_matches) == len(quran), 'dkAyahText length'

    def last_on_line(i):
        if i + 1 >= len(quran) or quran[i + 1]['page'] != quran[i]['page']:
            return True
        k, n = keys[i], keys[i + 1]
        return VERSES[n]['word_lines'][0] != VERSES[k]['word_lines'][-1]

    q_out, dk_out = qsrc, dksrc
    dk_shift = 0
    changed = []
    for i, k in enumerate(keys):
        if k not in VERSES:
            continue
        v, pv = quran[i], VERSES[k]
        assert v['page'] == pv['page'], f'{k} page {v["page"]} vs print {pv["page"]}'
        lines = pv['word_lines']
        trail = last_on_line(i)

        new_at = recut(v['aya_text'], lines, k, 'aya_text', trail)
        new_ot = recut(v['aya_text_othmanic'], lines, k, 'aya_text_othmanic', trail, like=v['aya_text'])
        new_qcf = recut_glyphs(v['qcfData'], pv['glyphs'], lines, k, trail)
        assert new_at.count('\n') == new_ot.count('\n') == new_qcf.count('\n'), k
        assert len(new_at) == len(v['aya_text']) + (1 if trail and not v['aya_text'].endswith('\n') else 0) - (1 if not trail and v['aya_text'].endswith('\n') else 0), k
        ls, le = lines[0], lines[-1]

        # quran_data.dart: edit inside this verse's own entry only.
        anchor = f'"id": {v["id"]},'
        a = q_out.index(anchor)
        b = q_out.index('\n  },', a)
        block = q_out[a:b]
        nb = block
        for field, old, new in (('aya_text', v['aya_text'], new_at),
                                ('aya_text_othmanic', v['aya_text_othmanic'], new_ot),
                                ('qcfData', v['qcfData'], new_qcf)):
            pat = re.compile(rf'("{field}":\s+){re.escape(dart_dq(old))},')
            hits = pat.findall(nb)
            assert len(hits) == 1, f'{k} {field} not found once'
            nb = pat.sub(lambda m: m.group(1) + dart_dq(new) + ',', nb)
        for field, val in (('line_start', ls), ('line_end', le)):
            nb, cnt = re.subn(rf'"{field}": \d+,', f'"{field}": {val},', nb)
            assert cnt == 1, f'{k} {field}'
        if nb != block:
            changed.append(k)
            q_out = q_out[:a] + nb + q_out[b:]

        # dk_data.dart: same breaks, internal only (DK text never ends in \n).
        m = dk_matches[i]
        dk_src_text = m.group(1)
        dk_text = dk_src_text.replace('\\n', '\n')
        new_dk = recut(dk_text, lines, k, 'dkAyahText', False)
        assert len(new_dk) == len(dk_text), f'{k} dk length'
        new_dk_src = new_dk.replace('\n', '\\n')
        if new_dk_src != dk_src_text:
            s = dk_start + m.start(1) + dk_shift
            e = dk_start + m.end(1) + dk_shift
            assert dk_out[s:e] == dk_src_text
            dk_out = dk_out[:s] + new_dk_src + dk_out[e:]
            dk_shift += len(new_dk_src) - len(dk_src_text)
            if k not in changed:
                changed.append(k)

    pages = sorted({VERSES[k]['page'] for k in changed})
    if ALIGNED:
        print(f'QCF glyphs aligned (not equal to the print) in {len(ALIGNED)} verses: {ALIGNED}')
    if check:
        if q_out != qsrc or dk_out != dksrc:
            print(f'{len(changed)} verses on {len(pages)} pages differ from the print')
            sys.exit(1)
        print('data matches the 1421 print on the 36 pages')
        return
    open(QDATA, 'w', encoding='utf8').write(q_out)
    open(DKDATA, 'w', encoding='utf8').write(dk_out)
    print(f'rewrote {len(changed)} verses on {len(pages)} pages: {pages}')


if __name__ == '__main__':
    main('--check' in sys.argv)
