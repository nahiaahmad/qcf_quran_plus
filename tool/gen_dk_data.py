"""Generate lib/src/data/dk_data.dart for the qcf_quran_plus fork.
Inputs: DigitalKhatt V2 ayah JSON (QUL 85), QPC Hafs Tajweed JSON (QUL 87), the
fork's quran_data.dart (current KFGQPC text with page line breaks)."""
import json,re,sys,difflib,unicodedata as U
dkp,tjp,qdp,outp=sys.argv[1:5]
dk=json.load(open(dkp,encoding='utf-8')); tj=json.load(open(tjp,encoding='utf-8'))
src=open(qdp,encoding='utf-8').read()
order=[]
for m in re.finditer(r'"sora":\s*(\d+),.*?"aya_no":\s*(\d+),\s*"aya_text":\s*"(.*?)",',src,flags=re.S):
    order.append((f'{m.group(1)}:{m.group(2)}',m.group(3)))
assert len(order)==6236
# palette index: 0 madd muttasil/munfasil, 1 madd aarid, 2 madd lazim, 3 natural madd (small letters),
# 4 qalqalah, 5 ghunnah family, 6 silent/assimilated
CI={'madda_obligatory_mottasel':0,'madda_obligatory_monfasel':0,'madda_permissible':1,'madda_necessary':2,
    'madda_normal':3,'qalaqah':4,'ghunnah':5,'ham_wasl':6,'laam_shamsiyah':6,'slnt':6}
PAIR={'ikhafa','ikhafa_shafawi','iqlab','idgham_ghunnah','idgham_wo_ghunnah','idgham_shafawi','idgham_mutajanisayn','idgham_mutaqaribayn'}
TAN=set('\u064B\u064C\u064D\u08F0\u08F1\u08F2')
GREEN,GREY=5,6
def skel(t):
    t=U.normalize('NFD',re.sub(r'<[^>]+>','',t))
    t=re.sub(r'[\u0660-\u0669]+','',t).replace('\u06DD','').replace('\u0671','\u0627')
    return ''.join(c for c in t if '\u0621'<=c<='\u064A').replace('\u0640','').replace('\u0649','\u064A')
def tajweed_chars(tagged):
    t=re.sub(r'\s*[\u0660-\u0669]+\s*$','',tagged).replace('\u200c','')
    chars=[];stacks=[];rules={};stack=[];rid=0;unknown=set()
    for m in re.finditer(r'<rule class=[\'"]?([a-z_]+)[\'"]?[^>]*>|</rule>|(.)',t,flags=re.S):
        if m.group(1):
            rid+=1;rules[rid]=m.group(1);stack.append(rid)
            if m.group(1) not in CI and m.group(1) not in PAIR: unknown.add(m.group(1))
        elif m.group(0)=='</rule>':
            if not stack: raise ValueError('unbalanced </rule>')
            stack.pop()
        else:
            chars.append(m.group(2));stacks.append(tuple(stack))
    if stack: raise ValueError('unclosed <rule>')
    plain=''.join(chars)
    colour={}   # (rid, char index) -> palette index or None
    for r,rule in rules.items():
        idx=[i for i,st in enumerate(stacks) if r in st]
        if not idx: continue
        seg=''.join(plain[i] for i in idx)
        start,end=idx[0],idx[-1]+1
        before=plain[start-1] if start>0 else ' ';after=plain[end] if end<len(plain) else ' '
        if rule in PAIR:
            cl=[];cur=[]
            for n,ch in enumerate(seg):
                if U.combining(ch) or ch in '\u0640': cur.append(n)
                else:
                    if cur: cl.append(cur)
                    cur=[n]
            if cur: cl.append(cur)
            cols=[None]*len(seg)
            for c in cl:
                cs=[seg[n] for n in c];base=cs[0]
                at_end=after in ' ';at_start=before==' '
                if at_end and not at_start: is_src=True
                elif at_start and not at_end: is_src=False
                else: is_src=base=='\u0646' or any(x in TAN or x=='\u06E2' for x in cs) or (rule.endswith('shafawi') and base=='\u0645')
                src_letter=base in ('\u0646','\u0645') and not any(x in TAN for x in cs)
                if rule in ('ikhafa','ikhafa_shafawi'): col=GREEN if (is_src and src_letter) else None
                elif rule=='iqlab': col=GREEN if '\u06E2' in cs else None
                elif rule=='idgham_ghunnah': col=(GREY if (base=='\u0646' and src_letter) else None) if is_src else GREEN
                elif rule=='idgham_shafawi': col=None if is_src else GREEN
                else: col=(GREY if src_letter else None) if is_src else None
                for n in c: cols[n]=col
        else:
            cols=[CI.get(rule)]*len(seg)
        for n,i in enumerate(idx): colour[(r,i)]=cols[n]
    P=plain;C=[];R=[]
    for i,st in enumerate(stacks):
        col=None;who=0
        for r in reversed(st):           # innermost rule first
            if colour.get((r,i)) is not None: col=colour[(r,i)];who=r;break
        C.append(col);R.append(who)
    # Pause marks are never coloured and differ between the 1421 and 1441 prints:
    # drop them before alignment so they cannot shift colours onto other words.
    keep=[i for i,ch in enumerate(P) if not ('\u06D6'<=ch<='\u06DB')]
    return ''.join(P[i] for i in keep),[C[i] for i in keep],[R[i] for i in keep],unknown
bad_word=[];bad_char=[]
texts=[];runs=[];problems=[];unknown_all=set();lost=0;total_rules=0
for k,qtext in order:
    d=re.sub(r'\s+',' ',dk[k]['text']).strip()
    if k in ('27:20','36:22'): d=d.replace('مَا لِيَ','مَالِيَ')
    dw=d.split(' ')
    parts=[p.strip() for p in qtext.split('\\n')]
    counts=[len([w for w in p.split() if not (k=='39:8' and w=='۞')]) for p in parts]
    counts=[c for c in counts if c>0]
    if sum(counts)!=len(dw): problems.append((k,'words',sum(counts),len(dw))); 
    # rebuild with \n at the same word boundaries
    out=[];i=0
    for n in counts:
        out.append(' '.join(dw[i:i+n])); i+=n
    D='\n'.join(out)
    if skel(D)!=skel(qtext.replace('\\n',' ')) and k!='2:72': problems.append((k,'letters'))
    # tajweed runs over D (\n counts as one char like the space it replaces)
    P,C,R,unk=tajweed_chars(tj[k]['text']); unknown_all|=unk
    Dflat=D.replace('\n',' ')
    body=re.sub(r'\s*\u06DD[\u0660-\u0669]+$','',Dflat)
    dc=[None]*len(Dflat);dr=[0]*len(Dflat)
    # Normalise both texts to the same character forms (decomposed hamza seats, one
    # sukun, one tanwin set, one yaa) and align those, so each letter and mark pairs
    # one-to-one. A character with no exact partner is never coloured here.
    NEQ={'\u06E1':'\u0652','\u06DF':'\u0652','\u08F0':'\u064B','\u08F1':'\u064C','\u08F2':'\u064D',
         '\u0649':'\u064A','\u066E':'\u064A','\u0671':'\u0627'}
    def normseq(txt):
        out=[];back=[]
        for i,ch in enumerate(txt):
            if ch in '\u0640\u034F\u200c': continue          # tatweel / joiners carry no letter
            for c in U.normalize('NFD',ch):
                out.append(NEQ.get(c,c)); back.append(i)
        return ''.join(out),back
    Pn,Pb=normseq(P); Bn,Bb=normseq(body)
    for tag,i1,i2,j1,j2 in difflib.SequenceMatcher(None,Pn,Bn,autojunk=False).get_opcodes():
        if tag=='equal':
            for x in range(i2-i1):
                pi=Pb[i1+x]; bj=Bb[j1+x]
                if C[pi] is not None and dc[bj] is None: dc[bj]=C[pi]; dr[bj]=R[pi]
    for j,ch in enumerate(body):
        if '\u06D6'<=ch<='\u06DB' or ch=='\u06DD': dc[j]=None; dr[j]=0
    want={r for r in R if r};got={r for r in dr if r}
    # Fallback for rules the aligner could not pair (e.g. a pause mark and the small
    # waw stored in the opposite order): same word index, same character.
    if want-got:
        pw=[];wi=0
        for ch in P:
            pw.append(wi)
            if ch==' ': wi+=1
        bw=[];wi=0
        for ch in body:
            bw.append(wi)
            if ch==' ': wi+=1
        for r in sorted(want-got):
            idx=[i for i in range(len(P)) if R[i]==r]
            w=pw[idx[0]]
            for i in idx:
                ch=P[i]
                if ch in ' \u200c' or '\u06D6'<=ch<='\u06DC': continue
                cand=[j for j in range(len(body)) if bw[j]==w and body[j]==ch and dc[j] is None]
                if cand: dc[cand[0]]=C[i]; dr[cand[0]]=r
        got={r for r in dr if r}
    total_rules+=len(want); lost+=len(want-got)
    if want-got: problems.append((k,'lost',[''.join(P[i] for i in range(len(P)) if R[i]==r) for r in sorted(want-got)]))
    # ---- independent validation: every coloured char must sit in the same word as
    # its rule in the King Fahd text, and be one of that rule's characters.
    def widx(txt):
        # word number per char; a token that is only the hizb sign does not count as a word
        out=[0]*len(txt);w=0;i=0
        for tok in txt.split(' '):
            real=tok.strip('\u06DE')!=''
            for x in range(len(tok)): out[i+x]=w
            i+=len(tok)
            if i<len(txt): out[i]=w; i+=1
            if real: w+=1
        return out
    EQ={'\u06E1':'\u0652','\u06DF':'\u0652','\u08F0':'\u064B','\u08F1':'\u064C','\u08F2':'\u064D','\u0649':'\u064A','\u066E':'\u064A','\u0623':'\u0627','\u0625':'\u0627','\u0622':'\u0627','\u0624':'\u0648','\u0626':'\u064A'}
    def norm(c): return EQ.get(c,c)
    pwi=widx(P);bwi=widx(body)
    rule_words={};rule_chars={}
    for i,r in enumerate(R):
        if r:
            rule_words.setdefault(r,set()).add(pwi[i])
            for c in U.normalize('NFD',P[i]): rule_chars.setdefault(r,set()).add(norm(c))
    for j,r in enumerate(dr):
        if r and dc[j] is not None:
            if bwi[j] not in rule_words.get(r,()):
                bad_word.append((k,body.split(' ')[bwi[j]],repr(body[j])))
            elif norm(body[j]) not in rule_chars.get(r,()) and body[j] not in '\u0654\u0655\u034F' and not (body[j] in '\u064A\u0649' and '\u0640' in rule_chars.get(r,())):
                bad_char.append((k,body.split(' ')[bwi[j]],hex(ord(body[j]))))
    rl=[];x=0
    while x<len(dc):
        if dc[x] is None: x+=1;continue
        y=x
        while y<len(dc) and dc[y]==dc[x]: y+=1
        rl+= [x,y,dc[x]]; x=y
    texts.append(D); runs.append(rl)
print('problems:',len(problems),problems[:12]); from collections import Counter as _C; print('colours on the wrong word:',len(bad_word),dict(_C(x[0] for x in bad_word))); print('colours on a char not in the rule:',len(bad_char),bad_char[:10]); print('unknown rules:',unknown_all or 'none')
print('tajweed rules placed: %d of %d (lost %d)'%(total_rules-lost,total_rules,lost))
def dq(s): return "'"+s.replace('\\','\\\\').replace("'","\\'").replace('\n','\\n').replace('$','\\$')+"'"
with open(outp,'w',encoding='utf-8') as f:
    f.write('// GENERATED by gen_dk_data.py from QUL "Digital Khatt V2 script" (ayah by ayah)\n')
    f.write('// and QUL "QPC Hafs Tajweed". Do not edit by hand.\n')
    f.write('// Line breaks (\\n) sit at exactly the same word positions as quran_data.dart,\n')
    f.write('// so every page keeps the same 15 lines and the same verses.\n\n')
    f.write('/// DigitalKhatt (Madinah) text of every verse, in Mushaf order (index = verse id - 1).\n')
    f.write('const List<String> dkAyahText = [\n')
    for t in texts: f.write('  '+dq(t)+',\n')
    f.write('];\n\n')
    f.write('/// Tajwid colour runs per verse: flat triples [start, end, colourIndex] over\n')
    f.write('/// [dkAyahText] (UTF-16 offsets). Colour indices: see DkTajweed.palette.\n')
    f.write('const List<List<int>> dkTajweedRuns = [\n')
    for r in runs: f.write('  ['+','.join(map(str,r))+'],\n')
    f.write('];\n')
print('written',outp)
