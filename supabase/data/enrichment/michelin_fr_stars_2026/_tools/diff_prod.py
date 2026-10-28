import json, re
from collections import Counter
def key(u):
    if not u: return None
    m = re.search(r'([a-z0-9-]+/[^/]+/(?:restaurant|hotels-stays)/[^/?#\s]+)', u.split(' + ')[0])
    return m.group(1) if m else u
det = json.load(open('details.json')); R = json.load(open('reconcile.json'))
res = json.load(open('article_resolved.json')); prod = {p['code']: p for p in json.load(open('prod/fr_prod.json'))['rows']}
by_live = {r['live_key']: r for r in res if r['live_key']}; by_art = {r['art_key']: r for r in res}
# production -> resolved entry
pm = {}
for r in R['prod']:
    p = prod[r['code']]; k = key(p['michelin_url'])
    d = det.get(k) or {}
    ck = key(d['url']) if d.get('status') == 200 and d.get('url') else k
    e = by_live.get(ck) or by_art.get(k)
    how = 'url'
    if not e and r.get('mkey'):  # coordinate+name fallback from reconcile (rows with no/hotel URL)
        e = by_live.get(r['mkey']); how = r['match']
    if not e and p['code'] == 'rest_0900': e = by_art['normandie/dieppe/restaurant/les-voiles-d-or']; how = 'name+city (no URL stored; MICHELIN page gone)'
    pm[p['code']] = (e, how)
unm = [c for c, (e, h) in pm.items() if not e]; print('unmatched prod', [(c, prod[c]['name'], prod[c]['michelin_stars']) for c in unm])
dup = Counter(id(e) for e, h in pm.values() if e); print('entries matched twice', [ (c,pm[c][0]['name']) for c,(e,h) in pm.items() if e and dup[id(e)]>1])
star_fix = [(c, prod[c]['name'], prod[c]['michelin_stars'], e['tier_2026']) for c, (e, h) in pm.items() if e and prod[c]['michelin_stars'] != e['tier_2026']]
url_fix = []
for c, (e, h) in pm.items():
    if e and e['live_key']:
        new = 'https://guide.michelin.com/en/' + e['live_key']
        if prod[c]['michelin_url'] != new: url_fix.append((c, prod[c]['name'], prod[c]['michelin_url'], new, h))
matched_ids = {id(e) for e, h in pm.values() if e}
new = [r for r in res if id(r) not in matched_ids]
print('star fixes', len(star_fix)); [print('  ', x) for x in star_fix]
print('url fixes', len(url_fix), Counter('none' if not x[2] else 'locale/en' if key(x[2]) == key(x[3]) else 'moved' for x in url_fix))
print('new', len(new), Counter((r['tier_2026'], bool(r['live_key'])) for r in new))
json.dump(dict(pm={c: (e['art_key'] if e else None, h) for c, (e, h) in pm.items()}, star_fix=star_fix, url_fix=url_fix, new=new), open('diff.json', 'w'), ensure_ascii=False, indent=1)
