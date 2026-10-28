import json, re
from collections import Counter
def key(u):
    if not u: return None
    m = re.search(r'([a-z0-9-]+/[^/]+/(?:restaurant|hotels-stays)/[^/?#\s]+)', u.split(' + ')[0])
    return m.group(1) if m else u
det = json.load(open('details.json')); R = json.load(open('reconcile.json'))
art = [r for r in json.load(open('fr_2026_article_u.json')) if not r['city_dept'].startswith('Monaco')]
lst = {key(r['url']): r for r in json.load(open('fr_listing.json'))}
STAR = {'One Star: High quality cooking': 1, 'Two Stars: Excellent cooking': 2, 'Three Stars: Exceptional cuisine': 3}
LD = {'1 star': 1, '2 star': 2, '3 star': 3}
PAIR = {  # article link 404s -> same restaurant on the live listing (name + city + MICHELIN page checked by hand)
 'provence-alpes-cote-dazur/bandol/restaurant/les-oliviers': ('provence-alpes-cote-dazur/bandol/restaurant/les-oliviers122360', None),
 'centre-val-de-loire/ardon/restaurant/la-table-d-a-cote': ('centre-val-de-loire/ardon/restaurant/la-table-christophe-hay', None),
 'grand-est/colroy-la-roche/restaurant/la-cheneaudiere-la-table-des-chefs': ('grand-est/colroy-la-roche/restaurant/la-cheneaudiere-le-feuillage', None),
 'provence-alpes-cote-dazur/mane/restaurant/le-cloitre': ('provence-alpes-cote-dazur/mane/restaurant/le-feuillee-le-couvent-des-minimes', None),
 'occitanie/cret/restaurant/fario': ('occitanie/cret/restaurant/fario-1215907', None),
 'pays-de-la-loire/les-sorinieres/restaurant/l%E2%80%99epicurien-a-l%E2%80%99abbaye-de-villeneuve': ('pays-de-la-loire/les-sorinieres/restaurant/le-1201-abbaye-de-villeneuve', None),
 'auvergne-rhone-alpes/courchevel/restaurant/baumaniere-1850': ('auvergne-rhone-alpes/courchevel/restaurant/slalom-1850', 'RENAME: now Slalom 1850, same hotel (Le Strato) and chef (Thomas Prod\'homme) per MICHELIN page'),
 'ile-de-france/paris/restaurant/jean-imbert-au-plaza-athenee': ('ile-de-france/paris/restaurant/la-grande-du-plaza-athenee', 'RENAME: now La Grande Table du Plaza Athénée, same address (25 av. Montaigne) per MICHELIN page'),
}
out = []
for a in art:
    ak = key(a['url']); d = det.get(ak) or {}
    if d.get('status') == 200 and d.get('url'): lk, note = key(d['url']), None
    elif ak in PAIR: lk, note = PAIR[ak]
    else: lk, note = None, None
    ld = det.get(lk) or {} if lk else {}
    out.append(dict(art_key=ak, name=a['name'], city_dept=a['city_dept'], tier_2026=a['tier'], new_2026=a['new'], live_key=lk,
                    page_tier=STAR.get(ld.get('star')), live_list_tier=LD.get((lst.get(lk) or {}).get('dist')), on_live_list=lk in lst,
                    page_name=ld.get('name'), note=note))
c = Counter(('live' if r['on_live_list'] else 'page_only' if r['live_key'] else 'withdrawn') for r in out); print(c)
for r in out:
    if r['live_key'] and r['page_tier'] != r['tier_2026']: print('TIER DIFF', r['name'], r['tier_2026'], r['page_tier'], r['live_list_tier'])
    if r['live_key'] and not r['on_live_list']: print('PAGE ONLY', r['name'], r['live_key'], r['page_tier'])
print('withdrawn:'); [print('  ', r['name'], '|', r['city_dept'], r['tier_2026'], r['art_key']) for r in out if not r['live_key']]
json.dump(out, open('article_resolved.json', 'w'), ensure_ascii=False, indent=1)
