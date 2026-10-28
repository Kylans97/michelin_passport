import json, re, math, unicodedata, sys
from collections import Counter
S = sys.argv[1]
def key(u):
    if not u: return None
    m = re.search(r'([a-z0-9-]+/[^/]+/(?:restaurant|hotels-stays)/[^/?#\s]+)', u.split(' + ')[0])
    return m.group(1) if m else u
art = [r for r in json.load(open(f'{S}/fr_2026_article_u.json')) if not r['city_dept'].startswith('Monaco')]
lst = json.load(open(f'{S}/fr_listing.json')); prod = json.load(open(f'{S}/prod/fr_prod.json'))['rows']
det = json.load(open(f'{S}/details.json'))
A = {key(r['url']): r for r in art}; L = {key(r['url']): r for r in lst}
def canon(k):
    """follow redirect of a MICHELIN key to its current key"""
    d = det.get(k)
    if d and d.get('url'): return key(d['url'])
    if d and d.get('final'): return key(d['final'])
    return k
def dist(a, b, c, d):
    if None in (a, b, c, d): return None
    a, b, c, d = map(float, (a, b, c, d)); R = 6371000
    p = math.radians; x = (p(d) - p(b)) * math.cos((p(a) + p(c)) / 2); y = p(c) - p(a)
    return round(R * math.hypot(x, y))
def nm(s): return re.sub(r'[^a-z0-9]', '', unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower())
# canonical keys for article & listing (article uses /fr/fr/ url, may redirect)
Acan = {}
for k, r in A.items(): Acan[canon(k)] = dict(r, art_key=k)
Lcan = {canon(k): dict(r, list_key=k) for k, r in L.items()}
STAR = {'One Star: High quality cooking': 1, 'Two Stars: Excellent cooking': 2, 'Three Stars: Exceptional cuisine': 3}
LD = {'1 star': 1, '2 star': 2, '3 star': 3}
rows = []; used = set()
for p in prod:
    k = key(p['michelin_url']); ck = canon(k) if k else None
    rec = dict(code=p['code'], name=p['name'], city=p['city'], prod_stars=p['michelin_stars'], prod_url=p['michelin_url'], pk=k, ck=ck)
    a = Acan.get(ck) if ck else None; how = 'url' if a else None
    if not a:  # coordinate fallback, flagged
        cands = [(dist(p['lat'], p['lng'], (det.get(c) or {}).get('lat') or (Lcan.get(c) or {}).get('lat'), (det.get(c) or {}).get('lng') or (Lcan.get(c) or {}).get('lng')), c) for c in Acan]
        cands = sorted([x for x in cands if x[0] is not None and x[0] < 300])
        rec['coord_cands'] = [(dd, c, Acan[c]['name']) for dd, c in cands[:3]]
        if len(cands) >= 1 and nm(Acan[cands[0][1]]['name'])[:6] in nm(p['name']) or (cands and nm(p['name'])[:6] in nm(Acan[cands[0][1]]['name'])):
            a = Acan[cands[0][1]]; ck = cands[0][1]; how = f'coords {cands[0][0]}m + name'
    if a:
        used.add(ck); d = det.get(ck) or det.get(a['art_key']) or {}
        rec.update(match=how, mkey=ck, art_tier=a['tier'], art_new=a['new'], live_tier=LD.get((Lcan.get(ck) or {}).get('dist')), page_tier=STAR.get(d.get('star')), mname=a['name'])
    else:
        d = det.get(k) or {}
        rec.update(match=None, page_status=d.get('status'), page_tier=STAR.get(d.get('star')), live_tier=LD.get((Lcan.get(ck) or {}).get('dist')) if ck else None)
    rows.append(rec)
new = [dict(Acan[c], mkey=c) for c in Acan if c not in used]
live_only = [dict(Lcan[c], mkey=c) for c in Lcan if c not in Acan]
json.dump(dict(prod=rows, new=new, live_only=live_only), open(f'{S}/reconcile.json', 'w'), ensure_ascii=False, indent=1)
print('prod matched', Counter(r['match'] is not None for r in rows), Counter(str(r['match'])[:6] for r in rows))
print('new', len(new), Counter(r['tier'] for r in new), 'live_only', len(live_only))
