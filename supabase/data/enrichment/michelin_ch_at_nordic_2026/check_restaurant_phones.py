#!/usr/bin/env python3
"""Automated phone check (2026-10-30): is MICHELIN's number printed on the venue's own site?

Usage:
  python3 fetch_restaurant_sites.py <pages.jsonl> <sites_dir>     # fetch home + contact-like pages
  python3 check_restaurant_phones.py <pages.jsonl> <sites_dir> <out.json>

Copied from ../michelin_gb_ie_2026/check_restaurant_phones.py, with the national
forms for this pass's countries: +41 / +43 / +358 keep a trunk 0 nationally;
+45 / +46 (trunk 0) / +47 / +354 / +298 as printed. <sites_dir> holds the
fetched pages (not committed: third-party HTML). A number counts as found when
its digits (international or national form) occur in the digits of the
fetched pages. Rows it misses are checked by hand.
"""
import json, sys, os, re, hashlib, collections
TRUNK0 = ('41', '43', '46', '358')   # national form adds a leading 0
NOTRUNK = ('45', '47', '354', '298')  # national form is the bare subscriber number
pages = [json.loads(l) for l in open(sys.argv[1])]
S = sys.argv[2]
def digits(s): return re.sub(r'\D', '', s or '')
def forms(ph):
    d = digits(ph)
    out = {d}
    for cc in sorted(TRUNK0 + NOTRUNK, key=len, reverse=True):
        if d.startswith(cc):
            rest = d[len(cc):]
            if rest.startswith('0'):          # "+43 (0)662 ..." printed with the trunk 0
                out.add(cc + rest[1:]); rest = rest[1:]
            out.add(('0' + rest) if cc in TRUNK0 else rest)
            break
    return {f for f in out if len(f) >= 7}
res = {}
for p in pages:
    fn = os.path.join(S, hashlib.md5(p['url'].encode()).hexdigest() + '.json')
    f = json.load(open(fn)) if os.path.exists(fn) else {'res': None}
    ph = (p.get('ld') or {}).get('telephone')
    txt = ' '.join(v[2] for v in (f['res'] or {}).values())
    alld = digits(txt)
    hit = 'on official site' if ph and any(x in alld for x in forms(ph)) else None
    res[p['url']] = dict(phone=ph, hit=hit, home_status=(f['res'] or {}).get('home', [None, None])[1], bytes=len(txt))
c = collections.Counter((('phone' if v['phone'] else 'nophone'), v['hit'] or ('site unreachable' if not v['bytes'] else 'not found on site')) for v in res.values())
print(c)
json.dump(res, open(sys.argv[3], 'w'), indent=0)
