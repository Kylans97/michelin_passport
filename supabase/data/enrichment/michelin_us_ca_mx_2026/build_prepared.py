#!/usr/bin/env python3
"""Build the United States / Canada / Mexico 2026 prepared SQL from production's export.

Usage:
  python3 build_prepared.py <export.json> <first_rest_code> <first_hotel_code> <migration_name>

  export.json      the JSON cell of export_us_ca_mx_query.sql (saved as a file)
  first_rest_code  first restaurant code number to use (above production's max
                   AND above every code claimed by unapplied files on any branch)
  first_hotel_code first hotel code number to use (same rule)
  migration_name   e.g. 20261023160000_add_us_ca_mx_2026_star_and_key_cities.sql

Copied from ../michelin_gb_ie_2026/build_prepared.py. Reads only committed
research in this folder:
  {us,ca,mx}_research_2026.csv      MICHELIN restaurant pages + phone evidence + guide/year
  {us,ca,mx}_key_hotels_2026.csv    Key hotels: MICHELIN page + website/phone research
Writes, into this folder: match_report.csv, prepared_us_ca_mx_stars_2026.sql, and
../../../migrations/<migration_name>.

What differs from the UK/Ireland pass (see README.md):
  * several MICHELIN guides, published at different times. Each row's guide
    year is its MICHELIN page's `dateAwarded`, and its announcement date that
    guide's (research CSV columns guide_year / announced_on). The Northeast
    Cities guide (New York, Chicago, Washington DC, Boston, Philadelphia) is
    still on its 2025 edition: its 2026 ceremony is 14 December 2026;
  * production's launch rows (guide_year 2026, announced_on NULL) for that
    guide hold MICHELIN's 2025 value; they are relabelled 2025 when the value
    agrees, as Germany's were (../michelin_de_it/build_prepared_de_it.py);
  * town names need the state where one name exists in two states
    (production already has Washington, District of Columbia and Washington,
    Virginia), so cities resolve on (name, region) and region is set only
    where a name is ambiguous;
  * hotel links: MICHELIN's "Stay at the hotel" link, or MICHELIN's own
    restaurant address naming a Key hotel whose MICHELIN pin is within 150 m
    (there is no "Inside the ...-Key" star article for these guides);
  * existing rows without a michelin_url get MICHELIN's (fill-only).
"""
import csv, json, math, os, re, sys, unicodedata, difflib, collections

HERE = os.path.dirname(os.path.abspath(__file__))
MIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), 'migrations')

ANNOUNCED_KEYS = '2026-09-18'    # MICHELIN Key global reveal 2026 (US, Canada and Mexico articles)
KEY_YEAR = 2026
COUNTRY_NAME = {'US': 'United States', 'CA': 'Canada', 'MX': 'Mexico'}
# MICHELIN's addressLocality for Mexico City restaurants is the alcaldía (borough);
# production files them under Mexico City, as Glasgow City -> Glasgow for the UK.
# "Miguel Hildalgo" is MICHELIN's own spelling. Chocholá is production's existing
# "Chocholá, Yucatán" row (Chablé Yucatán).
TOWN_FIX = {('MX', 'Cuauhtémoc'): 'Mexico City', ('MX', 'Miguel Hildalgo'): 'Mexico City', ('MX', 'Miguel Hidalgo'): 'Mexico City',
            ('MX', 'Álvaro Obregón'): 'Mexico City', ('MX', 'Benito Juárez'): 'Mexico City', ('MX', 'Coyoacán'): 'Mexico City',
            ('MX', 'Chocholá'): 'Chocholá, Yucatán',
            # MICHELIN's hotel pages write Washington, DC as "Washington D.C."; production's
            # row is Washington, region District of Columbia (as on the restaurant pages)
            ('US', 'Washington D.C.'): ('Washington', 'District of Columbia')}
# Production rows whose MICHELIN slug carries MICHELIN's numeric id suffix now
# ("sushi-sho" -> "sushi-sho-1213976"): matched on the slug without the suffix,
# same town segment, and only when exactly one MICHELIN page qualifies.


# Links verified by hand on the venue's own site after MICHELIN gave no "Stay at the hotel"
# link (product owner's go-ahead, 2026-10-30). restaurant michelin_url -> (hotel michelin_url, evidence)
VERIFIED_LINKS = {
    'https://guide.michelin.com/en/california/elk/restaurant/harbor-house': (
        'https://guide.michelin.com/en/hotels-stays/Elk/harbor-house-124019-13822',
        "QA-307: theharborhouseinn.com, the site MICHELIN's restaurant page links to, is one business for the inn "
        "and the restaurant: titled 'Two Michelin Star Restaurant in Mendocino | Harbor House Inn', one address "
        "(5600 South Highway 1, Elk, CA 95432) and one phone for both, 'our Michelin-starred restaurant' beside the "
        "inn's 11 rooms and cottages. Read 2026-10-30; restaurant pin {d} m from the hotel's MICHELIN pin."),
}


def n(s):
    return re.sub(r'[^a-z0-9 ]', '', unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower())


STOP = {'restaurant', 'hotel', 'by', 'the', 'at', 'and', 'in', 'of', 'a', 'collection', 'resort', 'spa', 'hotels', 'resorts',
        'inn', 'house', 'new', 'york', 'los', 'angeles', 'san', 'francisco', 'la', 'el', 'de', 'del', 'las', 'grand',
        'beach', 'club', 'residences', 'suites', 'lodge'}


def toks(s):
    return {t for t in n(s).split() if t not in STOP and len(t) > 1}


def sim(a, b):
    ta, tb = toks(a), toks(b)
    if ta and tb and (ta <= tb or tb <= ta):
        return 1.0
    return difflib.SequenceMatcher(None, n(a).replace(' ', ''), n(b).replace(' ', '')).ratio()


def dist(a, b, c, d):
    R = 6371000
    p1, p2 = math.radians(a), math.radians(c)
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(d - b) / 2) ** 2
    return round(2 * R * math.asin(math.sqrt(h)))


def slug(u):
    m = re.search(r'/restaurant/([^/?#]+)', u or '')
    return m.group(1).lower() if m else None


def bare(s):
    return re.sub(r'-\d{5,}$', '', s or '')


def path_town(u):
    m = re.search(r'/([^/]+)/restaurant/', u or '')
    return re.sub(r'_\d+$', '', m.group(1).lower()) if m else None


def hid(u):
    m = re.search(r'-(\d+)/?$', (u or '').split('?')[0])
    return m.group(1) if m else None


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


REGION_NORM = {'New York State': 'New York'}


def reg(r):
    return REGION_NORM.get(r, r) or None


def country(CC, X, first_code, first_hcode, shared):
    cc = CC.lower()
    rest = X.get('restaurants') or []
    cities = X.get('cities') or []
    hotels = X.get('hotels') or []
    links = {(l['hotel_code'], l['restaurant_code']) for l in (X.get('links') or [])}
    linked_restaurants = {l['restaurant_code'] for l in (X.get('links') or [])}
    url_in_use = set(X.get('michelin_urls_in_use') or [])
    hurl_in_use = set(X.get('hotel_michelin_urls_in_use') or [])
    research = list(csv.DictReader(open(os.path.join(HERE, f'{cc}_research_2026.csv'))))
    keyh = list(csv.DictReader(open(os.path.join(HERE, f'{cc}_key_hotels_2026.csv'))))

    report = []
    newtowns = {}              # (town, region) -> True
    tk = lambda t: n(t).replace(' ', '')
    prod_cities = [c for c in cities if c['country'] == CC]
    # a town name MICHELIN places in more than one state/province needs its region
    # (US hotel pages name the state as the restaurant pages do, bar "New York" for
    # "New York State"; Canadian and Mexican hotel pages carry tourist areas such as
    # "Riviera Maya" or nothing, so only their restaurant regions count)
    states = collections.defaultdict(set)
    for r in research:
        states[tk(TOWN_FIX.get((CC, r['city']), r['city']))].add(reg(r['region']))
    for k in keyh:
        if CC == 'US' and not isinstance(TOWN_FIX.get((CC, k['city'].strip())), tuple):
            states[tk(TOWN_FIX.get((CC, k['city'].strip()), k['city'].strip()))].add(reg(k['region']))
    for c in prod_cities:
        if c['region']:
            states[tk(c['name'])].add(c['region'])
    chosen = {}

    def town_of(t, region):
        """-> (city name, city region) resolving to exactly one cities row after the migration."""
        t = TOWN_FIX.get((CC, t.strip()), t.strip())
        if isinstance(t, tuple):
            t, region = t
        region = reg(region)
        key = tk(t)
        ambiguous = len(states[key]) > 1
        same = [c for c in prod_cities if tk(c['name']) == key]
        if ambiguous:
            hit = [c for c in same if c['region'] == region]
            if len(hit) == 1:
                return hit[0]['name'], hit[0]['region']
            if any(c['region'] is None for c in same):
                raise SystemExit(f'{CC} town {t!r} is ambiguous ({sorted(states[key])}) and production has a region-less row: decide by hand')
            name = chosen.setdefault((key, region), t)
            newtowns[(name, region)] = True
            return name, region
        if same:
            if len(same) != 1:
                raise SystemExit(f'{CC} town {t!r}: {len(same)} production rows')
            return same[0]['name'], same[0]['region']
        name = chosen.setdefault((key, None), t)
        newtowns[(name, None)] = True
        return name, None

    for r in research:   # restaurant spellings first: they are MICHELIN's listing names
        town_of(r['city'], r['region'])

    # ---- hotels: existing matched by MICHELIN id, else (no michelin_url) by coordinates + name
    ex_hotels = [h for h in hotels if h['country'] == CC]
    by_mid = {hid(h['michelin_url']): h for h in ex_hotels if h['michelin_url']}
    hotel_by_mid = {}          # MICHELIN id -> dict(code, name, lat, lon, keys, new)
    new_hotels, key_changes, hotel_fills = [], [], []
    matched_h = set()
    hcode = first_hcode
    for k in keyh:
        mid = hid(k['michelin_url'])
        keys = int(k['keys'])
        h, how = by_mid.get(mid), 'MICHELIN hotel id'
        if not h:
            near = sorted((dist(e['lat'], e['lon'], float(k['lat']), float(k['lon'])), sim(e['name'], k['name']), e['code']) for e in ex_hotels
                          if not e['michelin_url'] and e['code'] not in matched_h)
            ok = [x for x in near if (x[0] <= 300 and x[1] >= 0.6) or (x[0] <= 500 and x[1] >= 0.9)]   # resorts: Rosewood Mayakoba's pins are 394 m apart
            if len(ok) == 1:
                h = next(e for e in ex_hotels if e['code'] == ok[0][2]); how = f'coordinates {ok[0][0]} m + name (production row has no michelin_url)'
        if h:
            matched_h.add(h['code'])
            hotel_by_mid[mid] = dict(code=h['code'], name=h['name'], lat=float(k['lat']), lon=float(k['lon']), keys=keys, new=False)
            d = dist(h['lat'], h['lon'], float(k['lat']), float(k['lon']))
            report.append(dict(country=CC, code=h['code'], name=h['name'], kind='HOTEL MATCHED',
                               detail=f"by {how}: MICHELIN '{k['name']}' {k['michelin_url']}, {keys} Key(s); stored point {d} m from MICHELIN's"))
            if d > 500:
                report.append(dict(country=CC, code=h['code'], name=h['name'], kind='STORED HOTEL COORDINATES OFF',
                                   detail=f"stored point {d} m from MICHELIN's -- left as is"))
            if h['keys'] != keys:
                key_changes.append((h['code'], keys, h['keys']))
                report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY CHANGE',
                                   detail=f"{h['keys']} -> {keys} (MICHELIN 2026 Keys, 18 Sep 2026)"))
            f = dict(code=h['code'], phone=k['phone'] if not h.get('phone') and k['phone'] else None,
                     website_url=k['website_url'] if not h.get('website_url') and k['website_url'] else None,
                     michelin_url=k['michelin_url'] if not h.get('michelin_url') and k['michelin_url'] not in hurl_in_use else None)
            if f['phone'] or f['website_url'] or f['michelin_url']:
                hotel_fills.append(f)
        else:
            if k['michelin_url'] in hurl_in_use:
                report.append(dict(country=CC, code='', name=k['name'], kind='HOTEL URL ALREADY IN USE', detail=k['michelin_url'] + ' -- not added'))
                continue
            code = f'hotel_{hcode}'; hcode += 1
            town, treg = town_of(k['city'], k['region'])
            row = dict(code=code, name=k['name'], keys=keys, town=town, town_region=treg, address=k['address'],
                       lat=float(k['lat']), lon=float(k['lon']), michelin_url=k['michelin_url'],
                       website_url=k['website_url'] or None, phone=k['phone'] or None)
            new_hotels.append(row)
            hotel_by_mid[mid] = dict(code=code, name=k['name'], lat=row['lat'], lon=row['lon'], keys=keys, new=True)
    for h in new_hotels:   # a new row must never duplicate an existing one under another pin
        for e in ex_hotels:
            if sim(e['name'], h['name']) >= 0.9 and e['code'] not in matched_h:
                raise SystemExit(f"{CC}: new hotel {h['name']!r} shares its name with unmatched {e['code']} {e['name']!r} ({dist(e['lat'], e['lon'], h['lat'], h['lon'])} m) -- decide by hand")
    lost_keys = [h for h in ex_hotels if h['code'] not in matched_h and h['keys'] is not None]
    for h in lost_keys:
        report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY NOT IN MICHELIN 2026',
                           detail=f"production michelin_keys = {h['keys']}; no Key page on MICHELIN's 2026 listing matches it -- left untouched, needs a decision (hotel scope rule 1)"))
    for h in ex_hotels:
        if h['code'] not in matched_h and h['keys'] is None:
            report.append(dict(country=CC, code=h['code'], name=h['name'], kind='HOTEL WITHOUT KEY (World\'s 50 Best)',
                               detail='no MICHELIN Key in 2026; left untouched'))

    # ---- match existing restaurants
    by_slug = collections.defaultdict(list)
    for r in research:
        by_slug[slug(r['michelin_url'])].append(r)
    ex = [r for r in rest if r['country'] == CC]
    matched, used = {}, set()
    for e in ex:
        m = how = None
        s = slug(e.get('michelin_url'))
        cands = [r for r in by_slug.get(s, []) if path_town(r['michelin_url']) == path_town(e.get('michelin_url'))] if s else []
        if len(cands) == 1 and cands[0]['michelin_url'] not in used:
            m, how = cands[0], 'michelin slug'
        if not m and s:
            cands = [r for r in research if bare(slug(r['michelin_url'])) == bare(s) and path_town(r['michelin_url']) == path_town(e.get('michelin_url'))]
            if len(cands) == 1 and cands[0]['michelin_url'] not in used:
                m, how = cands[0], f"michelin slug without MICHELIN's numeric id suffix ({s} -> {slug(cands[0]['michelin_url'])})"
        if not m:
            near = sorted(((dist(e['lat'], e['lon'], float(r['lat']), float(r['lon'])), sim(e['name'], r['name']), i) for i, r in enumerate(research)
                           if r['michelin_url'] not in used))
            ok = [(d, sm, research[i]) for d, sm, i in near if (d <= 200 and sm >= 0.6) or (d <= 1000 and sm >= 0.9)]
            if len(ok) == 1:
                m, how = ok[0][2], f'coordinates {ok[0][0]} m + name'
            elif len(ok) > 1:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='AMBIGUOUS MATCH', detail='left unmatched, check by hand'))
        if m:
            matched[e['code']] = m; used.add(m['michelin_url'])
            d = dist(e['lat'], e['lon'], float(m['lat']), float(m['lon']))
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='matched by ' + how.split(' (')[0],
                               detail=f"{how}: MICHELIN '{m['name']}' {m['michelin_url']}; stored point {d} m from MICHELIN's; stored url {e.get('michelin_url')}"))
            if d > 500:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED COORDINATES OFF',
                                   detail=f"stored point {d} m from MICHELIN's (stored address {e.get('address')!r}; MICHELIN {m['address']!r}) -- left as is"))

    relabel, changes, losses, corrections, optional_rows = [], [], [], [], []
    for e in ex:
        hist = e.get('history') or []
        cur = [h for h in hist if h['current']]
        if not hist and e['stars'] is None:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='NOT STARRED (left as is)',
                               detail=f"inclusion_reason {e['inclusion_reason']}; no star history; not in MICHELIN's starred listing"))
            continue
        if len(cur) != 1:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='NO SINGLE CURRENT ROW', detail='left untouched -- check by hand'))
            continue
        cur = cur[0]
        m = matched.get(e['code'])
        if not m:
            if cur['value'] is not None:
                losses.append(e['code'])
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LOSS (not in MICHELIN listing)', detail=f"{cur['value']} star(s) -> NULL"))
            continue
        s, gy, ann = int(m['stars']), int(m['guide_year']), m['announced_on']
        launch = cur['year'] == 2026 and not cur.get('announced_on')
        if gy == 2025 and launch:
            if any(h['year'] == 2025 for h in hist):
                h25 = [h for h in hist if h['year'] == 2025][0]
                if h25['value'] == s and cur['value'] == s:
                    # decided by the product owner, 2026-10-30 (QA-301): make 2025 current, drop the launch row
                    optional_rows.append((e, cur, h25, m))
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='2026 LAUNCH ROW DROPPED, 2025 MADE CURRENT',
                                       detail=f"MICHELIN's current edition for this guide is 2025 ({s}); production held 2025 = {h25['value']} (not current, history pass) and a launch row 2026 = {cur['value']} (current, no announced_on) that predates any 2026 edition. Relabelling would collide, so the launch row is deleted and 2025 made current (product owner, 2026-10-30; QA-301)"))
                else:
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='2025 ROW DISAGREES',
                                       detail=f"2025 = {h25['value']}, launch 2026 = {cur['value']}, MICHELIN 2025 = {s}; left untouched -- decide by hand"))
            elif cur['value'] == s:
                relabel.append(e['code'])
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LAUNCH ROW RELABELLED 2026 -> 2025',
                                   detail=f"{m['guide']} is MICHELIN's current edition for this restaurant (dateAwarded 2025; next ceremony 14 Dec 2026); value {s} agrees"))
            else:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LAUNCH ROW DISAGREES WITH 2025',
                                   detail=f"launch row 2026 = {cur['value']}, MICHELIN 2025 = {s}; left untouched -- decide by hand"))
            continue
        if cur['year'] == gy and cur['value'] != s:
            corrections.append((e['code'], s, cur['value'], gy))
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED', detail=f"{gy} row holds {cur['value']}, MICHELIN {gy} gives {s}"))
        elif cur['year'] < gy and cur['value'] != s:
            changes.append((e['code'], s, cur['value'], gy, ann))
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STAR CHANGE', detail=f"{cur['year']} = {cur['value']} -> {gy} = {s} ({m['guide']})"))
        elif cur['year'] > gy:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='CURRENT ROW NEWER THAN MICHELIN', detail=f"{cur['year']} = {cur['value']} vs MICHELIN {gy} = {s}; left untouched"))
        else:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind=f'{gy} ROW VERIFIED',
                               detail=f"current row {cur['year']} = {cur['value']} agrees with MICHELIN's live page ({m['guide']}); left as is"))

    # ---- hotel for a restaurant
    key_by_mid = {hid(k['michelin_url']): k for k in keyh}

    def host_for(r, code):
        """-> ('link', hotel, confidence, evidence) | ('property', name, None, evidence) | (None,...)"""
        v = VERIFIED_LINKS.get(r['michelin_url'])
        if v and hid(v[0]) in hotel_by_mid:
            h = hotel_by_mid[hid(v[0])]
            d = dist(float(r['lat']), float(r['lon']), h['lat'], h['lon'])
            return ('link', h, 'exact' if d <= 100 else 'campus', v[1].format(d=d))
        sid = hid(r['stay_hotel_url']) if r['stay_hotel_url'] else None
        if sid and sid in hotel_by_mid:
            h = hotel_by_mid[sid]
            d = dist(float(r['lat']), float(r['lon']), h['lat'], h['lon'])
            return ('link', h, 'exact' if d <= 100 else 'campus',
                    f"MICHELIN restaurant page 'Stay at the hotel' -> {r['stay_hotel_url']} ({r['stay_hotel_name']}), a {h['keys']}-Key hotel; restaurant pin {d} m from the hotel's MICHELIN pin. 2026-10-29.")
        if sid:  # stay link to a MICHELIN-selected (non-Key) hotel
            return ('property', r['stay_hotel_name'], None, 'MICHELIN restaurant page "Stay at the hotel" (no Key)')
        # MICHELIN prints the host hotel as the address's own first segment
        # ("The St. Regis Atlanta, 88 W. Paces Ferry Rd. NW, ..."). That segment must
        # carry no digits, so a street that shares a hotel's name ("342 Bowery" vs
        # The Bowery Hotel) never counts, and must contain the hotel's whole name.
        addr = r['address'] or ''
        first = addr.split(',')[0]
        cands = []
        for mid, h in hotel_by_mid.items():
            d = dist(float(r['lat']), float(r['lon']), h['lat'], h['lon'])
            hn = n(re.sub(r'^the ', '', re.split(r',', h['name'])[0].strip(), flags=re.I))
            if d <= 150 and hn and not re.search(r'\d', first) and hn in n(first):
                cands.append((d, h))
        if len(cands) == 1:
            d, h = cands[0]
            return ('link', h, 'exact' if d <= 100 else 'campus',
                    f"MICHELIN restaurant page address '{addr}' names the {h['keys']}-Key hotel '{h['name']}', whose MICHELIN pin is {d} m from the restaurant's. 2026-10-29.")
        if len(cands) > 1:
            report.append(dict(country=CC, code=code, name=r['name'], kind='HOST HOTEL AMBIGUOUS', detail=f"{[h['name'] for d, h in cands]} -- no link"))
        return (None, None, None, None)

    # ---- new restaurants
    new = []
    code = first_code
    for r in sorted(research, key=lambda r: n(r['name'])):
        if r['michelin_url'] in used:
            continue
        if r['michelin_url'] in url_in_use:
            report.append(dict(country=CC, code='', name=r['name'], kind='URL ALREADY IN USE ELSEWHERE', detail=r['michelin_url'] + ' -- not added'))
            continue
        town, treg = town_of(r['city'], r['region'])
        new.append(dict(code=f'rest_{code}', r=r, town=town, town_region=treg)); code += 1

    new_links, prop_new, prop_clear = [], {}, []
    for x in new:
        kind, h, conf, ev = host_for(x['r'], x['code'])
        if kind == 'link':
            new_links.append((h['code'], x['code'], conf, ev))
        elif kind == 'property':
            prop_new[x['code']] = h
    fills = []
    for e in ex:
        m = matched.get(e['code'])
        if not m:
            continue
        f = dict(code=e['code'])
        f['phone'] = m['phone'] if not e.get('phone') and m['phone'] else None
        f['website_url'] = m['website'] if not e.get('website_url') and m['website'] else None
        f['michelin_url'] = m['michelin_url'] if not e.get('michelin_url') and m['michelin_url'] not in url_in_use else None
        f['property_name'] = None
        kind, h, conf, ev = host_for(m, e['code'])
        if kind == 'link' and (h['code'], e['code']) not in links:
            new_links.append((h['code'], e['code'], conf, ev))
            if e.get('property_name'):
                prop_clear.append((e['code'], e['property_name']))
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='property_name -> hotel link',
                                   detail=f"stored property_name {e['property_name']!r}; the host is now in `hotels` ({h['code']} {h['name']}), so the link replaces it (hotel scope rule 3)"))
        elif kind == 'property' and not e.get('property_name') and e['code'] not in linked_restaurants:
            f['property_name'] = h
        elif kind is None and e.get('property_name'):
            near = [(dist(float(m['lat']), float(m['lon']), hh['lat'], hh['lon']), hh) for hh in hotel_by_mid.values()
                    if sim(e['property_name'], hh['name']) >= 0.8]
            near = [x for x in near if x[0] <= 300]
            if near:
                d, hh = min(near, key=lambda t: t[0])
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='PROPERTY NOW A KEY HOTEL (not linked)',
                                   detail=f"stored property_name {e['property_name']!r}; {hh['code']} {hh['name']} ({hh['keys']} Key) is {d} m away, but MICHELIN gives no 'Stay at the hotel' link and its address does not name the hotel -- name and distance alone do not make a link; decide by hand"))
        if e.get('phone') and m['michelin_phone'] and re.sub(r'\D', '', e['phone']) != re.sub(r'\D', '', m['michelin_phone']):
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED PHONE DIFFERS', detail=f"stored {e['phone']} vs MICHELIN {m['michelin_phone']} -- stored kept"))
        if any(f[k] for k in ('phone', 'website_url', 'property_name', 'michelin_url')):
            fills.append(f)
    for x in new:
        r = x['r']
        if not r['phone'] and r['michelin_phone']:
            report.append(dict(country=CC, code=x['code'], name=r['name'], kind='PHONE HELD BACK', detail=f"MICHELIN {r['michelin_phone']}: {r['phone_source']}"))
        if x['code'] in prop_new:
            report.append(dict(country=CC, code=x['code'], name=r['name'], kind='property_name', detail=prop_new[x['code']]))
    names = {x['code']: x['r']['name'] for x in new} | {e['code']: e['name'] for e in ex}
    for hc, rc, conf, ev in new_links:
        report.append(dict(country=CC, code=rc, name=names.get(rc, rc), kind=f'HOTEL LINK ({conf})', detail=f'{hc}: {ev}'))
    for h in new_hotels:
        if not h['phone'] or not h['website_url']:
            report.append(dict(country=CC, code=h['code'], name=h['name'], kind='HOTEL CONTACT MISSING',
                               detail=('no website; ' if not h['website_url'] else '') + ('no phone' if not h['phone'] else '') + f' -- see {cc}_key_hotels_2026.csv'))

    cnt = collections.Counter(int(r['stars']) for r in research)
    keycnt = collections.Counter(h['keys'] for h in hotel_by_mid.values())
    summary = dict(existing=len(ex), matched=len(matched), relabelled_2025=len(relabel), launch_rows_dropped=len(optional_rows), changes=len(changes), losses=len(losses),
                   corrections=len(corrections), new=len(new), new_phones=sum(1 for x in new if x['r']['phone']), new_place_ids=0,
                   property_names=len(prop_new), links=len(new_links), fills=len(fills),
                   new_hotels=len(new_hotels), new_hotel_phones=sum(1 for h in new_hotels if h['phone']),
                   new_hotel_websites=sum(1 for h in new_hotels if h['website_url']), key_changes=len(key_changes),
                   hotel_fills=len(hotel_fills), keys_not_in_2026=len(lost_keys))
    last_rest, last_hotel = code - 1, hcode - 1
    city_sql = lambda alias: f"(select c.id from public.cities c where c.country_code = '{CC}' and c.name = {alias}.city and c.region is not distinct from {alias}.city_region)"
    city_check = lambda alias: f"(select count(*) from public.cities c where c.country_code = '{CC}' and c.name = {alias}.city and c.region is not distinct from {alias}.city_region) <> 1"

    # ---- SQL
    P = [f"\n-- ============================================================\n-- {CC} {COUNTRY_NAME[CC]}\n-- ============================================================"]
    P.append(f"""do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}';
  if n <> {len(ex)} then raise exception '{CC}: expected {len(ex)} restaurants (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(e['code'])}, {q(e['name'])})" for e in ex)}) e(code, name)
   where not exists (select 1 from public.restaurants r where r.restaurant_code = e.code and r.name = e.name and r.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported restaurant codes no longer carry their exported name', n; end if;
""" if ex else '') + f"""  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len(ex_hotels)} then raise exception '{CC}: expected {len(ex_hotels)} hotels (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(h['code'])}, {q(h['name'])})" for h in ex_hotels)}) e(code, name)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported hotel codes no longer carry their exported name', n; end if;
""" if ex_hotels else '') + (f"""  if exists (select 1 from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'
              and substring(restaurant_code from 6)::int between {first_code} and {last_rest}) then
    raise exception 'restaurant codes rest_{first_code}..rest_{last_rest} are no longer free -- re-check';
  end if;
""" if new else '') + (f"""  if exists (select 1 from public.hotels where hotel_code ~ '^hotel_[0-9]+$'
              and substring(hotel_code from 7)::int between {first_hcode} and {last_hotel}) then
    raise exception 'hotel codes hotel_{first_hcode}..hotel_{last_hotel} are no longer free -- re-check';
  end if;
""" if new_hotels else '') + f"""  if exists (select 1 from public.award_history where award_type = 'michelin_keys' and is_current and guide_year <> {KEY_YEAR}) then
    raise exception 'current michelin_keys rows are not all guide_year {KEY_YEAR} -- decide the year explicitly';
  end if;
end $$;""")

    if new_hotels:
        P.append(f"""-- {CC} 1. MICHELIN Key hotels missing from `hotels` (each with its current 2026 Key row, step 1c)
create temp table _new_hotels_{cc} (code text, name text, keys smallint, city text, city_region text, address text, lon float8, lat float8,
                               michelin_url text, website_url text, phone text) on commit drop;
insert into _new_hotels_{cc} values
{(','+chr(10)).join(f"    ({q(h['code'])}, {q(h['name'])}, {h['keys']}::smallint, {q(h['town'])}, {q(h['town_region'])}, {q(h['address'])}, {h['lon']}, {h['lat']}, {q(h['michelin_url'])}, {q(h['website_url'])}, {q(h['phone'])})" for h in new_hotels)};
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_hotels_{cc} x
   where {city_check('x')};
  if bad is not null then raise exception 'hotel city does not resolve to exactly one {CC} row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_hotels_{cc} x join public.hotels h on h.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'hotel already present (michelin_url): %', bad; end if;
end $$;
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url, website_url, phone)
select x.code, x.name, x.keys, {city_sql('x')}, '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone
  from _new_hotels_{cc} x;""")
    if key_changes:
        P.append(f"""-- {CC} 1b. Key changes on existing hotels (2026 Keys): close the current Key row; 1c opens 2026
create temp table _kchg_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kchg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {'NULL' if w is None else w})" for c, k, w in key_changes)};
update public.award_history a set is_current = false from public.hotels h, _kchg_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys' and a.is_current;
update public.hotels h set michelin_keys = k.keys, updated_at = now() from _kchg_{cc} k
 where h.hotel_code = k.code and h.michelin_keys is not distinct from k.was;""")
    P.append(f"""-- {CC} 1c. current 2026 Key row for every {CC} Key hotel that lacks one (new rows above, and existing
--     hotels the earlier imports left without one; PE_REPORT.md finding 1)
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, {KEY_YEAR}, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED_KEYS}'
  from public.hotels h
 where h.hotel_code = any(array[{', '.join(q(h['code']) for h in hotel_by_mid.values())}])
   and not exists (select 1 from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
                    and a.award_type = 'michelin_keys' and a.is_current);""")
    if hotel_fills:
        P.append(f"""-- {CC} 1d. existing {CC} hotels, fill-only (never overwrites)
create temp table _hfill_{cc} (code text primary key, phone text, website_url text, michelin_url text) on commit drop;
insert into _hfill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])}, {q(f['michelin_url'])})" for f in hotel_fills)};
update public.hotels h set phone = f.phone, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.phone is not null and h.phone is null;
update public.hotels h set website_url = f.website_url, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.website_url is not null and h.website_url is null;
update public.hotels h set michelin_url = f.michelin_url, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.michelin_url is not null and h.michelin_url is null
   and not exists (select 1 from public.hotels o where o.michelin_url = f.michelin_url);""")
    if relabel:
        P.append(f"""-- {CC} 2a. relabel verified launch rows 2026 -> 2025 (values unchanged; each agrees with MICHELIN's live
--     page, whose current edition for these guides is 2025: Northeast Cities, announced 18 Nov 2025)
do $$
begin
  if exists (select 1 from public.award_history ah join public.restaurants r on r.id = ah.entity_id
              where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.guide_year = 2025
                and r.restaurant_code = any(array[{', '.join(q(c) for c in relabel)}])) then
    raise exception '{CC}: 2025 rows already exist for relabel candidates -- this file has run?';
  end if;
end $$;
update public.award_history ah set guide_year = 2025
  from public.restaurants r
 where r.id = ah.entity_id and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2026 and ah.is_current and ah.announced_on is null
   and r.restaurant_code = any(array[{', '.join(q(c) for c in relabel)}]);""")
    if optional_rows:
        codes = ', '.join(q(e['code']) for e, cur, h25, m in optional_rows)
        P.append(f"""-- {CC} 2a'. launch rows 2026 that predate any 2026 edition, where a 2025 row already exists
--     (relabelling would collide): drop the launch row, make 2025 current (values agree with
--     MICHELIN's live 2025 page; product owner, 2026-10-30, QA-301). The delete comes first:
--     only one current row per entity and award type is allowed.
create temp table _drop26_{cc} (code text primary key, value smallint) on commit drop;
insert into _drop26_{cc} values
{(','+chr(10)).join(f"    ({q(e['code'])}, {cur['value']})" for e, cur, h25, m in optional_rows)};
do $$
declare n int;
begin
  select count(*) into n from _drop26_{cc} d join public.restaurants r on r.restaurant_code = d.code
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id and ah.award_type = 'michelin_stars'
   where (ah.guide_year = 2026 and ah.is_current and ah.announced_on is null and ah.award_value = d.value)
      or (ah.guide_year = 2025 and not ah.is_current and ah.award_value = d.value);
  if n <> {2 * len(optional_rows)} then raise exception '{CC}: launch-row fix expected {2 * len(optional_rows)} rows (2026 current + 2025 not current), found %', n; end if;
end $$;
delete from public.award_history ah using public.restaurants r, _drop26_{cc} d
 where r.restaurant_code = d.code and ah.entity_id = r.id and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2026 and ah.is_current and ah.announced_on is null and ah.award_value = d.value;
update public.award_history ah set is_current = true from public.restaurants r, _drop26_{cc} d
 where r.restaurant_code = d.code and ah.entity_id = r.id and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
   and ah.guide_year = 2025 and not ah.is_current and ah.award_value = d.value;""")
    if changes or losses:
        rows = [(c, s, y, a) for c, s, _, y, a in changes] + [(c, None, 2026, None) for c in losses]
        P.append(f"""-- {CC} 2b. changes and losses: close the current row, open the guide year's row
create temp table _chg_{cc} (code text primary key, stars smallint, guide_year smallint, announced_on date) on commit drop;
insert into _chg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {'NULL' if s is None else s}, {y}, {q(a)})" for c, s, y, a in rows)};
update public.award_history ah set is_current = false
  from public.restaurants r, _chg_{cc} c
 where r.id = ah.entity_id and r.restaurant_code = c.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.is_current;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, c.guide_year, 'michelin_stars', c.stars, true, c.announced_on
  from public.restaurants r join _chg_{cc} c on c.code = r.restaurant_code;
update public.restaurants r set michelin_stars = c.stars, updated_at = now()
  from _chg_{cc} c where r.restaurant_code = c.code;""")
    if corrections:
        P.append(f"""-- {CC} 3. import errors corrected in place
create temp table _fix_{cc} (code text primary key, stars smallint, was smallint, guide_year smallint) on commit drop;
insert into _fix_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {s}, {w}, {y})" for c, s, w, y in corrections)};
update public.award_history ah set award_value = f.stars
  from public.restaurants r, _fix_{cc} f
 where r.id = ah.entity_id and r.restaurant_code = f.code and ah.entity_type = 'restaurant'
   and ah.award_type = 'michelin_stars' and ah.guide_year = f.guide_year and ah.is_current and ah.award_value = f.was;
update public.restaurants r set michelin_stars = f.stars, updated_at = now()
  from _fix_{cc} f where r.restaurant_code = f.code and r.michelin_stars = f.was;""")
    if new:
        P.append(f"""-- {CC} 4. starred restaurants missing from the catalogue (Place ID NULL: no Places API in this pass);
--    each award row takes its own guide's year and announcement date
create temp table _new_{cc} (code text, name text, stars smallint, city text, city_region text, address text, lon float8, lat float8,
                        michelin_url text, website_url text, phone text, property_name text, place_id text,
                        guide_year smallint, announced_on date) on commit drop;
insert into _new_{cc} values
{(','+chr(10)).join(f"    ({q(x['code'])}, {q(x['r']['name'])}, {x['r']['stars']}::smallint, {q(x['town'])}, {q(x['town_region'])}, {q(x['r']['address'])}, {x['r']['lon']}, {x['r']['lat']}, {q(x['r']['michelin_url'])}, {q(x['r']['website'])}, {q(x['r']['phone'])}, {q(prop_new.get(x['code']))}, NULL, {x['r']['guide_year']}, {q(x['r']['announced_on'])})" for x in new)};
do $$
declare bad text;
begin
  select string_agg(x.code, ', ') into bad from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;
  if bad is not null then raise exception 'codes no longer free: %', bad; end if;
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_{cc} x
   where {city_check('x')};
  if bad is not null then raise exception 'city does not resolve to exactly one {CC} row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_{cc} x join public.restaurants r on r.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'already present (michelin_url): %', bad; end if;
end $$;
insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
                                address, location, michelin_url, website_url, phone, property_name, google_place_id)
select x.code, x.name, x.stars, 'michelin_star', {city_sql('x')}, '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone, x.property_name, x.place_id
  from _new_{cc} x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, x.guide_year, 'michelin_stars', x.stars, true, x.announced_on
  from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;""")
    if fills:
        P.append(f"""-- {CC} 5. existing restaurants, fill-only (never overwrites)
create temp table _fill_{cc} (code text primary key, phone text, website_url text, property_name text, michelin_url text) on commit drop;
insert into _fill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])}, {q(f['property_name'])}, {q(f['michelin_url'])})" for f in fills)};
update public.restaurants r set phone = f.phone, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set website_url = f.website_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.website_url is not null and r.website_url is null;
update public.restaurants r set michelin_url = f.michelin_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.michelin_url is not null and r.michelin_url is null
   and not exists (select 1 from public.restaurants o where o.michelin_url = f.michelin_url);
update public.restaurants r set property_name = f.property_name, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.property_name is not null and r.property_name is null
   and not exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);""")
    if new_links:
        P.append(f"""-- {CC} 6. links to hotels in `hotels`""" + (f"""; the host of {len(prop_clear)} existing restaurant(s) with a property_name is now in
--    `hotels`, so the link replaces the free-text name (hotel scope rule 3; guarded on the stored value)
create temp table _pclear_{cc} (code text primary key, was text) on commit drop;
insert into _pclear_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {q(w)})" for c, w in prop_clear)};
update public.restaurants r set property_name = NULL, updated_at = now() from _pclear_{cc} p
 where r.restaurant_code = p.code and r.property_name = p.was;""" if prop_clear else '') + f"""
create temp table _links_{cc} (hotel_code text, restaurant_code text, confidence text, evidence text) on commit drop;
insert into _links_{cc} values
{(','+chr(10)).join(f"    ({q(h)}, {q(r)}, {q(c)}, {q(ev)})" for h, r, c, ev in new_links)};
do $$
declare n int;
begin
  select count(*) into n from _links_{cc} l
   where not exists (select 1 from public.hotels h where h.hotel_code = l.hotel_code)
      or not exists (select 1 from public.restaurants r where r.restaurant_code = l.restaurant_code);
  if n <> 0 then raise exception '% links point at a missing hotel or restaurant', n; end if;
end $$;
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, l.confidence, l.evidence, now()
  from _links_{cc} l join public.hotels h on h.hotel_code = l.hotel_code join public.restaurants r on r.restaurant_code = l.restaurant_code
on conflict (hotel_id, restaurant_id) do nothing;""")
    lost_codes = [h['code'] for h in lost_keys]
    excl = f" and hotel_code <> all(array[{', '.join(q(c) for c in lost_codes)}])" if lost_codes else ''
    years = collections.Counter((int(r['guide_year']), int(r['stars'])) for r in research)
    P.append(f"""-- {CC} post-conditions: MICHELIN's live {CC} listings (every guide) and the 2026 {CC} Keys
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 3;
  if n <> {cnt[3]} then raise exception '{CC}: expected {cnt[3]} three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 2;
  if n <> {cnt[2]} then raise exception '{CC}: expected {cnt[2]} two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 1;
  if n <> {cnt[1]} then raise exception '{CC}: expected {cnt[1]} one-star, found %', n; end if;
""" + ''.join(f"""  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.guide_year = {y} and ah.award_value = {s};
  if n <> {c} then raise exception '{CC}: expected {c} current {y} rows of {s} star(s), found %', n; end if;
""" for (y, s), c in sorted(years.items())) + f"""  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.michelin_stars is not null
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '{CC}: % starred restaurants without exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '{CC}: % restaurants disagree with their current award row', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '{CC}: % restaurants have both a hotel link and a property_name', n; end if;
  -- Keys: the {len(hotel_by_mid)} {CC} Key hotels, plus the {len(lost_codes)} hotel(s) still holding a Key MICHELIN no longer shows (left for a decision)
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 3{excl};
  if n <> {keycnt[3]} then raise exception '{CC}: expected {keycnt[3]} three-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 2{excl};
  if n <> {keycnt[2]} then raise exception '{CC}: expected {keycnt[2]} two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 1{excl};
  if n <> {keycnt[1]} then raise exception '{CC}: expected {keycnt[1]} one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = '{CC}' and h.michelin_keys is not null{excl.replace('hotel_code', 'h.hotel_code')}
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '{CC}: % Key hotels without exactly one matching current Key row', n; end if;
end $$;""")

    optional = ''
    for h in lost_keys:
        optional += f"""
-- {h['code']} {h['name']}: production holds michelin_keys = {h['keys']}, but no Key page in MICHELIN's
-- 2026 {COUNTRY_NAME[CC]} hotel listing matches it (README). Hotel scope rule 1 (CLAUDE.md) keeps only
-- Key and World's 50 Best hotels in `hotels`; removing the row is a destructive change and is
-- NOT prepared. The minimum, if confirmed, is to record the loss:
--
-- update public.award_history set is_current = false where entity_type = 'hotel' and award_type = 'michelin_keys' and is_current
--    and entity_id = (select id from public.hotels where hotel_code = '{h['code']}');
-- update public.hotels set michelin_keys = NULL, updated_at = now()
--  where hotel_code = '{h['code']}' and name = {q(h['name'])} and country_code = '{CC}' and michelin_keys = {h['keys']};
-- insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
-- select 'hotel', id, {KEY_YEAR}, 'michelin_keys', NULL, true, date '{ANNOUNCED_KEYS}' from public.hotels where hotel_code = '{h['code']}';
"""
    return dict(P=P, report=report, towns=sorted(newtowns, key=lambda t: (t[0], t[1] or '')), summary=summary, cnt=cnt, keycnt=keycnt,
                next_code=code, next_hcode=hcode, optional=optional, years=years)


def main():
    export_path, first_code, first_hcode, mig_name = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    X = json.load(open(export_path))
    if isinstance(X, list):
        X = X[0]
    present = {c['country_code'] for c in X.get('countries_present') or []}
    out, code, hcode = {}, first_code, first_hcode
    for CC in ('US', 'CA', 'MX'):
        out[CC] = country(CC, X, code, hcode, None)
        code, hcode = out[CC]['next_code'], out[CC]['next_hcode']
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'detail'])
        w.writeheader()
        for CC in out:
            w.writerows(out[CC]['report'])
    rows = [(CC, t, r) for CC in out for t, r in out[CC]['towns']]
    ca_country = "" if 'CA' in present else """
-- Canada: production has no `countries` row for CA (read-only check
-- 2026-10-29), and every CA city, restaurant and hotel below references one.
-- As in 20261023140000_add_gb_ie_2026_star_and_key_cities.sql (IE), the
-- country comes first; since 20261018120000_add_country_timezones.sql,
-- `timezones` is NOT NULL with at least one zone, so it carries every CA zone
-- from the IANA database, in zone.tab order as US and MX are stored (tzdata
-- 2025b zone.tab, read on this machine 2026-10-29; all 23 present in
-- production's pg_timezone_names).
insert into public.countries (country_code, name, flag_emoji, timezones)
values ('CA', 'Canada', '\U0001F1E8\U0001F1E6', array['America/St_Johns', 'America/Halifax', 'America/Glace_Bay',
        'America/Moncton', 'America/Goose_Bay', 'America/Blanc-Sablon', 'America/Toronto', 'America/Iqaluit',
        'America/Atikokan', 'America/Winnipeg', 'America/Resolute', 'America/Rankin_Inlet', 'America/Regina',
        'America/Swift_Current', 'America/Edmonton', 'America/Cambridge_Bay', 'America/Inuvik', 'America/Creston',
        'America/Dawson_Creek', 'America/Fort_Nelson', 'America/Whitehorse', 'America/Dawson', 'America/Vancouver'])
on conflict (country_code) do nothing;
"""
    open(os.path.join(MIG_DIR, mig_name), 'w').write(f"""-- MICHELIN United States, Canada and Mexico (stars of every current guide; 2026
-- Keys): the country and city prerequisite for the starred restaurants and Key
-- hotels added by
-- supabase/data/enrichment/michelin_us_ca_mx_2026/prepared_us_ca_mx_stars_2026.sql.
-- Generated by build_prepared.py from production's export (written
-- 2026-10-29). Filename timestamp is a sequence number only. Names are
-- MICHELIN's own town names (restaurant pages; for hotels, the hotel page's
-- locality); Mexico City's alcaldías are filed as Mexico City, as production
-- already does. None exists in production's export, compared accent-, case-,
-- space- and hyphen-insensitively. region is set only where MICHELIN puts one
-- town name in two states or provinces (production already separates
-- Washington, District of Columbia from Washington, Virginia); otherwise NULL,
-- matching the existing rows. postal_municipality left NULL. Idempotent: ON
-- CONFLICT targets countries_pkey and cities_unique_key.

begin;
{ca_country}
insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, {q(r)})" for c, t, r in rows) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    summ = {CC: out[CC]['summary'] for CC in out}
    head = f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN United States (US), Canada (CA) and Mexico (MX): bring every
-- restaurant's stars and award_history in line with MICHELIN's live listings
-- (each guide's current edition: Northeast Cities 2025, announced 18 Nov 2025;
-- California 2026, 24 Jun; Florida 2026, 28 May; American Southwest 2026,
-- 26 Aug; Colorado 2026, 14 Sep; Texas 2026, 8 Oct; American South 2026,
-- 21 Oct; Mexico 2026, 20 May; Québec 2026, 6 May; Toronto & Region 2026,
-- 22 Sep; Vancouver 2026, 6 Oct) and the 2026 Keys (18 Sep 2026); add the
-- starred restaurants and Key hotels missing from the catalogue, link
-- restaurants to Key hotels where MICHELIN says so, and complete existing rows
-- (fill-only). Generated by build_prepared.py; evidence and every judgement
-- call in match_report.csv and README.md.
--
-- Summary US: {json.dumps(summ['US'])}
-- Summary CA: {json.dumps(summ['CA'])}
-- Summary MX: {json.dumps(summ['MX'])}
--
-- PREREQUISITE: supabase/migrations/{mig_name}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;
"""
    opt = ''.join(out[CC]['optional'] for CC in out)
    open(os.path.join(HERE, 'prepared_us_ca_mx_stars_2026.sql'), 'w').write(
        head + '\n'.join('\n\n'.join(out[CC]['P']) for CC in out) + '\n\ncommit;\n' +
        ('' if not opt else '\n\n-- ============================================================\n-- OPTIONAL -- commented out; each needs an explicit decision\n-- ============================================================\n' + opt))
    for CC in out:
        print(CC, json.dumps(out[CC]['summary']))
        print('  towns:', len(out[CC]['towns']), '| report:', dict(collections.Counter(r['kind'] for r in out[CC]['report'])))
        print('  expected stars:', dict(out[CC]['cnt']), 'by year:', dict(out[CC]['years']), 'keys:', dict(out[CC]['keycnt']))
    print('codes rest', first_code, '..', code - 1, 'hotel', first_hcode, '..', hcode - 1)


if __name__ == '__main__':
    main()
