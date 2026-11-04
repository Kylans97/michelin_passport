#!/usr/bin/env python3
"""Write progress.csv: per country klaar / niet begonnen, with filled / needed counts.
  python3 progress.py <export.json> <dir>"""
import csv, json, os, sys
from collections import Counter
EXP, D = sys.argv[1:3]
rows = json.load(open(EXP))['gaps']
n = Counter(r['country'] for r in rows)
out = []
for cc in sorted(n, key=lambda c: (-n[c], c)):
    f = os.path.join(D, cc.lower() + '_contact_fill.csv')
    rec = dict(country=cc, rows=n[cc])
    if cc == 'GR':
        rec.update(status='overgeslagen', note='voorbereid in ../michelin_gr (QA-431), wacht op akkoord')
    elif not os.path.exists(f):
        rec.update(status='niet begonnen')
    else:
        R = list(csv.DictReader(open(f)))
        for k in ('place', 'phone', 'website'):
            need = [x for x in R if x[k + '_status'] != 'not needed']
            rec[k + '_filled'] = sum(x[k + '_status'] == 'confirmed' for x in need)
            rec[k + '_needed'] = len(need)
        rec['closed'] = sum(x['status'] == 'rejected' for x in R)
        rec['status'] = 'klaar'
        rec['note'] = 'alle rijen beoordeeld; achtergehouden waarden met reden in de CSV'
    out.append(rec)
cols = ['country', 'rows', 'status', 'place_filled', 'place_needed', 'phone_filled', 'phone_needed', 'website_filled', 'website_needed', 'closed', 'note']
with open(os.path.join(D, 'progress.csv'), 'w', newline='') as fh:
    w = csv.DictWriter(fh, cols)
    w.writeheader()
    w.writerows(out)
