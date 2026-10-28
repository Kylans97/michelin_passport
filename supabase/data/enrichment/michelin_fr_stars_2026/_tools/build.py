import json, re, csv, math, unicodedata, sys, os
from urllib.parse import urlparse
from collections import Counter, OrderedDict
S, OUT = sys.argv[1], sys.argv[2]; os.makedirs(OUT + '/_source', exist_ok=True)
J = lambda f: json.load(open(f'{S}/{f}'))
det, res, phones, D = J('details.json'), J('article_resolved.json'), J('phones.json'), J('diff.json')
prod = {p['code']: p for p in J('prod/fr_prod.json')['rows']}
links = {l['code']: l for l in J('prod/fr_links.json')['rows']}; hotels = J('prod/fr_hotels.json')['rows']
cities = {c['name'] for c in J('prod/fr_cities.json')['rows']}
def key(u):
    m = re.search(r'([a-z0-9-]+/[^/]+/(?:restaurant|hotels-stays)/[^/?#\s]+)', (u or '').split(' + ')[0]); return m.group(1) if m else u
lst = {key(r['url']): r for r in J('fr_listing.json')}
LD = {'1 star': 1, '2 star': 2, '3 star': 3}
murl = lambda k: 'https://guide.michelin.com/en/' + k
def dist(a, b, c, d):
    a, b, c, d = map(float, (a, b, c, d)); p = math.radians
    return round(6371000 * math.hypot((p(d) - p(b)) * math.cos((p(a) + p(c)) / 2), p(c) - p(a)))
def human(e):  # +33473830036 -> +33 4 73 83 00 36
    d = e[3:]; return '+33 ' + d[0] + ' ' + ' '.join(d[i:i+2] for i in range(1, 9, 2))
BRAND = re.compile(r'oetker|fourseasons|dorchester|chevalblanc|peninsula|ritzparis|lenegresco|airelles|barriere|mandarinoriental|shangri|hyatt|marriott|sources-hotels|hotel|hôtel|lareserve|relaischateaux', re.I)
CITY_FIX = {'Saint-Emilion': 'Saint-Émilion', 'Bretignolles-sur-Mer': 'Brétignolles-sur-Mer'}
by_art = {r['art_key']: r for r in res}
pm = D['pm']  # code -> (art_key, how)
# ---------- phone decision ----------
def phone_decision(k, hotel_venue):
    v = phones.get(k)
    if not v: return None, 'no MICHELIN page'
    st = v['state']
    if st == 'match':
        ctx = ' '.join(v['site_phones'].get(v['e164'], [])).lower()
        rest = re.search(r'restaurant|réserv|reserv|table|booking', ctx); hot = re.search(r'hôtel|hotel|réception|reception|standard', ctx)
        if hotel_venue and hot and not rest:
            return None, 'possible hotel switchboard: number on the site is labelled for the hotel/reception'
        return v['e164'], 'confirmed'
    return None, {'site_other_number': 'site shows a different number from MICHELIN', 'site_no_number': 'MICHELIN only: site shows no number to a plain download',
                  'site_error': 'MICHELIN only: site refused a plain download', 'no_website': 'MICHELIN only: no official website listed',
                  'no_michelin_phone': 'MICHELIN lists no phone'}[st]
def hotel_venue_of(k, code=None, lat=None, lng=None):
    if code and (prod[code].get('property_name') or code in links): return True
    w = (phones.get(k) or {}).get('website') or ''
    if BRAND.search(urlparse(w).netloc): return True
    if lat is not None and any(h['lat'] and dist(lat, lng, h['lat'], h['lng']) < 150 for h in hotels): return True
    return False
# ---------- 1. live listing capture ----------
with open(f'{OUT}/michelin_fr_starred.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['name', 'city', 'stars', 'michelin_url', 'is_new_2026', 'source_page'])
    newflag = {r['live_key']: r['new_2026'] for r in res if r['live_key']}
    for k, r in lst.items():
        w.writerow([r['name'], r['city'], LD[r['dist']], murl(k), 'yes' if newflag.get(k) else 'no',
                    'https://guide.michelin.com/en/fr/restaurants/all-starred' + ('' if r['page'] == 'list_01.html' else '/page/' + str(int(r['page'][5:7])))])
# ---------- 2. article parse ----------
json.dump(J('fr_2026_article_u.json'), open(f'{OUT}/_source/michelin_full_list_2026_parsed.json', 'w'), ensure_ascii=False, indent=1)
# ---------- 3. production reconciliation ----------
star_fix = {c: (o, t) for c, n, o, t in D['star_fix']}
url_fix = {c: new for c, n, old, new, h in D['url_fix']}
recon = []
for code in sorted(prod):
    p = prod[code]; ak, how = pm.get(code) or (None, None); r = by_art.get(ak)
    acts = []
    if code in star_fix: acts.append(f'stars {star_fix[code][0]} -> {star_fix[code][1]} (2026 row corrected)')
    if code in url_fix: acts.append('michelin_url ' + ('set' if not p['michelin_url'] else 'corrected'))
    if r and not r['live_key']: acts.append('none: MICHELIN page withdrawn since March 2026 (QA)')
    if not r: acts.append('none: not in the 2026 France list (not starred in production)')
    recon.append(OrderedDict(code=code, name=p['name'], city=p['city'], prod_stars=p['michelin_stars'], michelin_2026=r['tier_2026'] if r else '',
        new_in_2026='yes' if r and r['new_2026'] else '', match=how or '', michelin_name=r['name'] if r else '',
        michelin_url_now=murl(r['live_key']) if r and r['live_key'] else '', action='; '.join(acts) or 'none'))
with open(f'{OUT}/fr_reconciliation.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(recon[0])); w.writeheader(); w.writerows(recon)
# ---------- 4. new restaurants ----------
new = [r for r in D['new'] if r['live_key']]
new.sort(key=lambda r: (-r['tier_2026'], lst[r['live_key']]['city'], r['name']))
rows = []
for i, r in enumerate(new):
    k = r['live_key']; d = det[k]; l = lst[k]; city = CITY_FIX.get(l['city'], l['city'])
    lat, lng = float(d['lat']), float(d['lng'])
    assert 41 < lat < 51.2 and -5.3 < lng < 9.7, (r['name'], lat, lng)
    hv = hotel_venue_of(k, lat=lat, lng=lng); e, why = phone_decision(k, hv)
    near = [h for h in hotels if h['lat'] and dist(lat, lng, h['lat'], h['lng']) < 150]
    notes = []
    if r['note']: notes.append(r['note'])
    if l['city'] != city: notes.append(f"MICHELIN writes the city '{l['city']}'; production city '{city}' (accent only)")
    if d.get('locality') and d['locality'] != l['city']: notes.append(f"postal locality {d['locality']}")
    if near: notes.append('HOTEL-LINK CANDIDATE: within 150 m of ' + ', '.join(f"{h['name']} ({h['hotel_code']})" for h in near) + ' -- verify before linking')
    if why != 'confirmed': notes.append('phone left empty: ' + why)
    if (d.get('name') or r['name']) != r['name']: notes.append(f"MICHELIN page name '{d['name']}' vs article '{r['name']}'")
    rows.append(OrderedDict(code=f'rest_{1405 + i}', name=d.get('name') or r['name'], city=city, city_in_production='yes' if city in cities else 'no',
        stars=r['tier_2026'], new_in_2026='yes' if r['new_2026'] else 'no',
        address=f"{d['street']}, {d['postcode']} {d['locality']}".strip(', '), latitude=lat, longitude=lng, cuisine=d.get('cuisine') or '',
        michelin_url=murl(k), website_url=d.get('website') or '', phone_e164=e or '', phone=human(e) if e else '',
        phone_certainty='confirmed' if e else 'unclear', phone_source=' | '.join(((phones.get(k) or {}).get('site_phones') or {}).get(e, [])[:1]) if e else '',
        source_urls=murl(k) + (' | ' + d['website'] if d.get('website') else ''), notes='; '.join(notes)))
with open(f'{OUT}/new_restaurants.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
json.dump(rows, open(f'{S}/new_rows.json', 'w'), ensure_ascii=False)
# ---------- 5. withdrawn ----------
with open(f'{OUT}/withdrawn_since_march.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['name', 'city_dept', 'stars_2026', 'article_michelin_url', 'in_production', 'notes'])
    inprod = {ak: c for c, (ak, h) in pm.items() if ak}
    for r in res:
        if not r['live_key']:
            w.writerow([r['name'], r['city_dept'], r['tier_2026'], 'https://guide.michelin.com/fr/fr/' + r['art_key'], inprod.get(r['art_key'], 'no'),
                        'In MICHELIN France 2026 (16 Mar 2026); restaurant page now 404 and absent from the live listing. Reason not established -- check status (closure, chef departure) before changing anything.'])
# ---------- 6. phone backfill for existing rows ----------
prow = []
for code in sorted(prod):
    p = prod[code]; ak, how = pm.get(code) or (None, None); r = by_art.get(ak)
    if not r or not r['live_key'] or p['phone']: continue
    k = r['live_key']; e, why = phone_decision(k, hotel_venue_of(k, code=code))
    v = phones.get(k) or {}
    prow.append(OrderedDict(code=code, name=p['name'], city=p['city'], phone_e164=e or '', phone=human(e) if e else '',
        michelin_phone=v.get('michelin_phone') or '', official_website=v.get('website') or '',
        source_url=(v.get('site_phones') or {}).get(e, [''])[0].split(' @ ')[-1] if e else murl(k),
        certainty='confirmed' if e else ('not_found' if why.startswith('MICHELIN lists') else 'unclear'), notes='' if e else why))
with open(f'{OUT}/fr_phones_existing.csv', 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(prow[0])); w.writeheader(); w.writerows(prow)
json.dump(prow, open(f'{S}/phone_rows.json', 'w'), ensure_ascii=False)
missing = sorted({r['city'] for r in rows if r['city_in_production'] == 'no'})
json.dump(missing, open(f'{S}/missing_cities.json', 'w'), ensure_ascii=False)
print('recon', len(recon), Counter(x['action'][:12] for x in recon))
print('new', len(rows), Counter(r['stars'] for r in rows), 'phones', Counter(r['phone_certainty'] for r in rows), 'missing cities', len(missing))
print('existing phones', Counter(x['certainty'] for x in prow), 'hotel-link candidates', sum('HOTEL-LINK' in r['notes'] for r in rows))
