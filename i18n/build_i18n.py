#!/usr/bin/env python3
"""把 en.json / zh-Hant.json 词典写进 xiaoman.html（I18N_DICT），并列出界面里还没翻译的中文。
用法：python3 DailyReview/i18n/build_i18n.py [--missing]"""
import json,re,sys,os
H=os.path.dirname(os.path.abspath(__file__))
P=os.path.join(H,'..','iOS','App','Web','index.html')
s=open(P,encoding='utf8').read()
D={l:json.load(open(os.path.join(H,l+'.json'),encoding='utf8')) for l in ('en','zh-Hant')}
def check_placeholders(D):
    """译文占位符不对就报错：不能有 {}；序号不能超出原文的变量个数；繁体的每个变量都要用到；没有变量的词条不能有序号"""
    bad=[]
    for l,d in D.items():
        for k,v in d.items():
            if k.startswith('__') or not isinstance(v,str): continue
            n=k.count('{}')
            if '{}' in v: bad.append((l,k,v,'译文里有 {}，应该写 {0}{1}')); continue
            ids=[int(x) for x in re.findall(r'\{[MWs]?(\d)\}',v)]
            if any(i>=n for i in ids): bad.append((l,k,v,f'原文只有 {n} 个变量')); continue
            if l=='zh-Hant' and set(ids)!=set(range(n)): bad.append((l,k,v,f'原文有 {n} 个变量，译文没有全用上'))
    return bad
_bad=check_placeholders(D)
if _bad:
    for l,k,v,why in _bad: print(f'占位符错误 [{l}] {k!r} => {v!r}：{why}',file=sys.stderr)
    sys.exit(f'共 {len(_bad)} 条占位符错误，词典没有写入，请先改好')
blob='const I18N_DICT='+json.dumps(D,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')+';'
a=s.index('/*I18N_DICT_BEGIN*/')+len('/*I18N_DICT_BEGIN*/'); b=s.index('/*I18N_DICT_END*/')
s=s[:a]+blob+s[b:]
open(P,'w',encoding='utf8').write(s)
print('dict:',{k:len(v) for k,v in D.items()})
if '--missing' in sys.argv:
    t=re.sub(r'/\*I18N_DICT_BEGIN\*/.*?/\*I18N_DICT_END\*/','',s,flags=re.S)
    t=re.sub(r'<style.*?</style>','',t,flags=re.S); t=re.sub(r'<!--.*?-->','',t,flags=re.S)
    t=re.sub(r'(^|[\s;{}),])/\*.*?\*/',r'\1',t,flags=re.S); t=re.sub(r'(^|[\s;{}),])//[^\n]*',r'\1',t)
    HAN=re.compile(r'[㐀-鿿]'); out=set()
    def proc(x):
        res=[];i=0
        while i<len(x):
            if x[i]=='$' and i+1<len(x) and x[i+1]=='{':
                d=1;j=i+2
                while j<len(x) and d:
                    d+= {'{':1,'}':-1}.get(x[j],0); j+=1
                proc(x[i+2:j-1]); res.append('{}'); i=j; continue
            res.append(x[i]); i+=1
        for c in re.split(r'[<>\'"`\n]',''.join(res)):
            c=c.strip().replace('&nbsp;',' ')
            if HAN.search(c) and c not in D['en']: out.add(c)
    proc(t)
    for c in sorted(out): print('MISSING',c)
