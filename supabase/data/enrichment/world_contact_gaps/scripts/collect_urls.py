#!/usr/bin/env python3
"""List every candidate site URL not yet fetched: MICHELIN's link (identity-checked
pages), the Google record's link (stored Place ID, or search candidates), and
production's existing website_url (as the own site for phone checks).
  python3 collect_urls.py <export.json> <places_details.json> <places_search.json> <michelin_parsed.json> <sites_raw_dir> <out.txt>"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from common import clean_url, blocked
EXP, PD, PS, MP, SR, OUT = sys.argv[1:7]
idx = json.load(open(os.path.join(SR, 'index.json'))) if os.path.exists(os.path.join(SR, 'index.json')) else {}
det, srch, mp = json.load(open(PD)), json.load(open(PS)), json.load(open(MP))
u = set()
for r in json.load(open(EXP))['gaps']:
    if r['country'] == 'GR':
        continue
    c = r['code']
    u.add(r['website_url'])
    if c in mp and mp[c].get('identity_ok'):
        u.add(mp[c].get('website'))
    if c in det:
        u.add(det[c]['en'].get('websiteUri'))
    for p in srch.get(c, {}).get('results', []) + srch.get(c, {}).get('lodging_results', []):
        u.add(p.get('websiteUri'))
u = {clean_url(x) for x in u if x}
u = sorted(x for x in u if not blocked(x) and x not in idx)
open(OUT, 'w').write('\n'.join(u))
print(len(u))
