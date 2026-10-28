import json, re
from collections import Counter
det=json.load(open('details.json')); sites=json.load(open('sites.json')); res=json.load(open('article_resolved.json'))
try: br=json.load(open('browser_phones.json'))
except FileNotFoundError: br={}
def e164(s):
    if not s: return None
    d=re.sub(r'\D','',s)
    if s.strip().startswith('+33') and len(d)==11: return '+'+d
    if d.startswith('0') and len(d)==10: return '+33'+d[1:]
    return None
out={}
for r in res:
    k=r['live_key']
    if not k: continue
    d=det[k]; m=e164(d.get('phone')); s=sites.get(k) or {}; b=br.get(k)
    phones=dict(s.get('phones') or {})
    if b: [phones.setdefault(p,[]).append('browser @ '+b['url']) for p in b['phones']]
    if not d.get('phone'): st='no_michelin_phone'
    elif not d.get('website'): st='no_website'
    elif m in phones: st='match'
    elif phones: st='site_other_number'
    elif s.get('error') and not b: st='site_error'
    else: st='site_no_number'
    out[k]=dict(state=st, michelin_phone=d.get('phone'), e164=m, website=d.get('website'), site_phones=phones, site_error=s.get('error'), browser=bool(b))
json.dump(out,open('phones.json','w'),ensure_ascii=False,indent=1)
print(Counter(v['state'] for v in out.values()))
