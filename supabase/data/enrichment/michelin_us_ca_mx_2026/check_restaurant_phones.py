#!/usr/bin/env python3
"""Automated phone check (2026-10-29): is MICHELIN's number printed on the venue's own site?

Usage:
  python3 fetch_restaurant_sites.py <pages.jsonl> <sites_dir>     # fetch home + contact-like pages
  python3 check_restaurant_phones.py <pages.jsonl> <work_dir> <out.json>

<work_dir>/sites holds the fetched pages (not committed: third-party HTML).
A number counts as found when its digits (international or national form,
+1 / +52; copied from ../michelin_gb_ie_2026) occur in the digits of the fetched pages. Rows it misses were
checked by hand (_source/*_restaurant_phone_confirmations.csv).
"""
import json, sys, os, re, hashlib, collections
pages = [json.loads(l) for l in open(sys.argv[1])]
S = sys.argv[2]
def digits(s): return re.sub(r'\D', '', s or '')
def national(ph):  # +1 212-554-1515 -> 2125541515; +52 55 5280 1660 -> 5552801660
    d = digits(ph)
    return d[1:] if d.startswith('1') and len(d) == 11 else (d[2:] if d.startswith('52') else d)
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
