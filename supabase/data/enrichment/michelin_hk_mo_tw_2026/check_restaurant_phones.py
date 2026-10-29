#!/usr/bin/env python3
"""Automated phone check (2026-10-29; copied from ../michelin_cn_2026, national forms for +852 / +853 / +886): is MICHELIN's number printed on the venue's own site?

Usage:
  python3 fetch_restaurant_sites.py <pages.jsonl> <sites_dir>     # fetch home + contact-like pages
  python3 check_restaurant_phones.py <pages.jsonl> <work_dir> <out.json>

<work_dir>/sites holds the fetched pages (not committed: third-party HTML).
A number counts as found when its digits (international or national form,
+852 / +853 / +886) occur in the digits of the fetched pages. Rows it misses were
checked by hand (_source/*_restaurant_phone_confirmations.csv).
"""
import json, sys, os, re, hashlib, collections
pages = [json.loads(l) for l in open(sys.argv[1])]
S = sys.argv[2]
def digits(s): return re.sub(r'\D', '', s or '')
def national(ph):  # +852 2555 2202 -> 25552202 (HK/MO: no trunk prefix); +886 2 2181 9950 -> 0221819950
    d = digits(ph)
    if d.startswith(('852', '853')):
        return d[3:]
    return '0' + d[3:] if d.startswith('886') else d
res = {}
for p in pages:
    f = json.load(open(os.path.join(S, 'sites', hashlib.md5(p['url'].encode()).hexdigest() + '.json')))
    ph = p['ld'].get('telephone')
    txt = ' '.join(v[2] for v in (f['res'] or {}).values())
    alld = digits(txt)
    ok_status = [v[1] for v in (f['res'] or {}).values()]
    hit = None
    if ph:
        n = national(ph); i = digits(ph)
        # digits of the page with separators removed; also check tel: links
        if n in alld or i in alld:
            hit = 'on official site'
    res[p['url']] = dict(phone=ph, hit=hit, home_status=(f['res'] or {}).get('home', [None, None])[1], bytes=len(txt))
c = collections.Counter((('phone' if v['phone'] else 'nophone'), v['hit'] or ('site unreachable' if not v['bytes'] else 'not found on site')) for v in res.values())
print(c)
json.dump(res, open(sys.argv[3], 'w'), indent=0)
for u, v in res.items():
    if v['phone'] and not v['hit']:
        print(v['home_status'], v['bytes'], v['phone'], u.split('/restaurant/')[1])
