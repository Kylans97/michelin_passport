import re, html, json, sys
from collections import Counter
t = open(sys.argv[1]).read()
body = t[t.find('detail-page__content'):]
parts = re.split(r'<h2[^>]*>(.*?)</h2>', body, flags=re.S)
clean = lambda s: re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', s)).replace('\xa0', ' ')).strip()
rows, seen_heads = [], set()
for i in range(1, len(parts), 2):
    head = clean(parts[i])
    tier = 3 if '3-Étoiles' in head else 2 if '2-Étoiles' in head else 1 if head.startswith('Une Étoile') else None
    if tier is None or tier in seen_heads: continue
    seen_heads.add(tier)
    sec = parts[i + 1]
    for a in re.finditer(r'<a href="([^"]+/restaurant/[^"]+)"[^>]*>(.*?)</a>', sec, re.S):
        before = sec[:a.start()]
        seg = re.split(r'<br\s*/?>|</a>', before)[-1]
        after = sec[a.end():a.end() + 200]
        nxt = re.split(r'<br\s*/?>|<a ', after)[0]
        city = clean(seg).rstrip(':').strip()
        city = re.sub(r'^(Recherche par région\s*)?', '', city)
        rows.append(dict(tier=tier, city_dept=city, name=clean(a.group(2)), url=a.group(1), new='Nouveau' in nxt))
print(Counter(r['tier'] for r in rows), Counter((r['tier'], r['new']) for r in rows if r['new']), len(rows), len({r['url'] for r in rows}), file=sys.stderr)
for r in rows:
    if not re.search(r'\(\d\w\)|Paris|Monaco|Lyon|Marseille', r['city_dept']): print('ODD', r, file=sys.stderr)
json.dump(rows, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
