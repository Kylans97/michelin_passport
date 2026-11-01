"""Catalogue restaurants (NL/BE/LU) with no proposed or existing G&M row:
logged so a reviewer can see who is missing and why (never filled by name)."""
import csv,collections
live=list(csv.DictReader(open('benelux_live.csv')))
st=list(csv.DictReader(open('out/gault_millau_benelux_2026_staging.csv')))
covered={r['restaurant_code'] for r in st if r['decision'] in ('PROPOSE','ALREADY_IN_PROD')}
held=collections.defaultdict(list)
for r in st:
    if r['decision']=='HOLD' and r['match_class']!='REVIEW_NAME_CONFLICT': held[r['restaurant_code']].append(r['gm_name']+' ('+r['match_class']+')')
out=[]
for r in live:
    if r['restaurant_code'] in covered: continue
    why='held for review: '+'; '.join(held[r['restaurant_code']]) if r['restaurant_code'] in held else ('in production already, not on site now' if r['gm_current'] not in ('','NULL') else 'no G&M profile matched on address, website or phone')
    out.append(dict(restaurant_code=r['restaurant_code'],country_code=r['country_code'],name=r['name'],address=r['address'],michelin_stars=r['michelin_stars'],status=r['status'],production_gm=r['gm_current'] if r['gm_current']!='NULL' else '',reason=why))
with open('out/catalogue_without_gm_match.csv','w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out),collections.Counter(o['country_code'] for o in out),collections.Counter(o['reason'][:20] for o in out))
