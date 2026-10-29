#!/usr/bin/env python3
"""Build the Switzerland / Austria / Nordic Countries prepared SQL from production's export.

Usage:
  python3 build_prepared.py <export.json> <first_rest_code> <first_hotel_code> <migration_name>

  export.json      the JSON cell of export_ch_at_nordic_query.sql (saved as a file)
  first_rest_code  first restaurant code number to use (above production's max
                   AND above every code claimed by unapplied files on any branch)
  first_hotel_code first hotel code number to use (same rule)
  migration_name   e.g. 20261023180000_add_ch_at_nordic_star_and_key_cities.sql

Follows ../michelin_gb_ie_2026/build_prepared.py. Reads only committed research
in this folder:
  <cc>_research.csv       MICHELIN restaurant pages + phone evidence (build_research.py)
  <cc>_key_hotels.csv     MICHELIN Key hotel pages (build_key_hotels.py)
  decisions.json          every by-hand judgement (launch-row editions, losses,
                          Key-row editions, a MICHELIN "Stay at the hotel" link
                          not used), each with its evidence
Writes, into this folder: match_report.csv, prepared_ch_at_nordic_stars_2026.sql,
and ../../../migrations/<migration_name>.

Rules applied (see README.md):
  * existing restaurants are matched to MICHELIN by slug and town segment of
    the MICHELIN path (any locale prefix), else coordinates + name -- never by
    name alone; existing hotels by MICHELIN's numeric hotel id;
  * edition per guide: Switzerland's live selection is the 2025 edition
    (20 Oct 2025; the 2026 ceremony is 2 Nov 2026), Austria 2026 (18 Mar 2026),
    Nordic Countries 2026 (1 Jun 2026); Keys 2026 (global launch 18 Sep 2026);
  * a launch row labelled 2026 whose value is not that guide's 2026 value is
    relabelled to the edition it was verified against (QA-217 rule), never
    overwritten to make room; a launch row verified against no edition is an
    import error, corrected in place and logged;
  * a row no longer listed by MICHELIN is a loss (edition = NULL), unless
    decisions.json says otherwise;
  * new restaurants: Place ID NULL (no Places API in this session); phone only
    when the MICHELIN number is printed on the venue's own site;
  * hotel link when MICHELIN's restaurant page says "Stay at the hotel" for a
    Key hotel (identity by MICHELIN hotel id); a non-Key host hotel goes in
    property_name.
"""
import csv, json, math, os, re, sys, unicodedata, difflib, collections

HERE = os.path.dirname(os.path.abspath(__file__))
MIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), 'migrations')

GUIDES = {   # country -> (research file, star edition, announced_on, guide name)
    'CH': ('ch', 2025, '2025-10-20', 'MICHELIN Guide Switzerland 2025 (Lausanne, 20 October 2025)'),
    'AT': ('at', 2026, '2026-03-18', 'MICHELIN Guide Austria 2026 (18 March 2026)'),
    'DK': ('dk', 2026, '2026-06-01', 'MICHELIN Guide Nordic Countries 2026 (Copenhagen, 1 June 2026)'),
    'FO': ('fo', 2026, '2026-06-01', 'MICHELIN Guide Nordic Countries 2026 (Copenhagen, 1 June 2026)'),
    'SE': ('se', 2026, '2026-06-01', 'MICHELIN Guide Nordic Countries 2026 (Copenhagen, 1 June 2026)'),
    'NO': ('no', 2026, '2026-06-01', 'MICHELIN Guide Nordic Countries 2026 (Copenhagen, 1 June 2026)'),
    'FI': ('fi', 2026, '2026-06-01', 'MICHELIN Guide Nordic Countries 2026 (Copenhagen, 1 June 2026)'),
    'IS': ('is', 2026, '2026-06-01', 'MICHELIN Guide Nordic Countries 2026 (Copenhagen, 1 June 2026)'),
}
KEY_YEAR, ANNOUNCED_KEYS = 2026, '2026-09-18'   # MICHELIN global Key launch 2026
NEW_COUNTRIES = {   # added by the migration when production has no row
    'IS': ('Iceland', '\U0001F1EE\U0001F1F8', ['Atlantic/Reykjavik']),
}


def n(s):
    return re.sub(r'[^a-z0-9 ]', '', unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower())


STOP = {'restaurant', 'hotel', 'by', 'the', 'at', 'and', 'in', 'of', 'a', 'gourmet', 'le', 'la', 'de', 'im'}


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


def path_town(u):
    m = re.search(r'/([^/]+)/restaurant/', u or '')
    return m.group(1).lower() if m else None


def hid(u):
    m = re.search(r'-(\d+)/?$', (u or '').split('?')[0])
    return m.group(1) if m else None


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


def qa(v):
    return 'NULL' if v is None else str(v)


def country(CC, X, D, first_code, first_hcode):
    cc, star_year, announced, guide = GUIDES[CC]
    rest = X.get('restaurants') or []
    cities = X.get('cities') or []
    hotels = [h for h in (X.get('hotels') or []) if h['country'] == CC]
    links = {(l['hotel_code'], l['restaurant_code']) for l in (X.get('links') or [])}
    linked_restaurants = {l['restaurant_code'] for l in (X.get('links') or [])}
    url_in_use = set(X.get('michelin_urls_in_use') or [])
    hurl_in_use = {hid(u) for u in (X.get('hotel_michelin_urls_in_use') or [])}
    research = list(csv.DictReader(open(os.path.join(HERE, f'{cc}_research.csv')))) if os.path.exists(os.path.join(HERE, f'{cc}_research.csv')) else []
    keyh = list(csv.DictReader(open(os.path.join(HERE, f'{cc}_key_hotels.csv')))) if os.path.exists(os.path.join(HERE, f'{cc}_key_hotels.csv')) else []
    dec_r = D.get('restaurants', {})
    dec_h = D.get('hotels', {})

    report = []
    newtowns = set()
    tk = lambda t: n(t).replace(' ', '')
    prod_towns = {c['name'] for c in cities if c['country'] == CC}
    city_names = {tk(c['name']): c['name'] for c in cities if c['country'] == CC}

    def town_of(t):
        t2 = city_names.setdefault(tk(t), t)
        if t2 not in prod_towns:
            newtowns.add(t2)
        return t2

    for r in research:   # restaurant spellings first: MICHELIN's English listing names
        town_of(r['city'])

    # ---- hotels: existing matched by MICHELIN id; the rest are new
    ex_h = {hid(h['michelin_url']): h for h in hotels}
    hotel_by_mid = {}
    new_hotels, key_changes, hotel_fills = [], [], []
    key_relabel, key_fix = [], []
    hcode = first_hcode
    for k in keyh:
        mid = k['michelin_id']
        keys = int(k['keys'])
        if mid in ex_h:
            h = ex_h[mid]
            hotel_by_mid[mid] = dict(code=h['code'], name=h['name'], lat=float(k['lat']), lon=float(k['lon']), keys=keys, new=False)
            d = dist(h['lat'], h['lon'], float(k['lat']), float(k['lon']))
            report.append(dict(country=CC, code=h['code'], name=h['name'], kind='hotel matched by MICHELIN id',
                               detail=f"{mid}; stored point {d} m from MICHELIN's; MICHELIN 2026 {keys} Key(s), production {h['keys']}"))
            if d > 500:
                report.append(dict(country=CC, code=h['code'], name=h['name'], kind='STORED HOTEL COORDINATES OFF',
                                   detail=f"matched by MICHELIN id {mid}; stored point {d} m from MICHELIN's"))
            cur = [x for x in (h.get('key_history') or []) if x['current']]
            if h['keys'] != keys:
                dh = dec_h.get(h['code'])
                if not dh:
                    raise SystemExit(f"{h['code']} {h['name']}: Key {h['keys']} -> {keys} needs an entry in decisions.json (which edition the launch row holds)")
                if dh['launch_row'] == 'relabel':
                    key_relabel.append((h['code'], dh['year'], h['keys']))
                    key_changes.append((h['code'], keys, h['keys']))
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY CHANGE (launch row relabelled)',
                                       detail=f"launch row 2026 = {h['keys']} is MICHELIN's {dh['year']} Key ({dh['evidence']}); relabelled {dh['year']}; 2026 = {keys}"))
                else:
                    key_fix.append((h['code'], keys, h['keys']))
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY IMPORT ERROR CORRECTED',
                                       detail=f"launch row 2026 = {h['keys']}, MICHELIN 2026 = {keys}: {dh['evidence']}"))
            elif cur and cur[0]['year'] == KEY_YEAR:
                report.append(dict(country=CC, code=h['code'], name=h['name'], kind='2026 KEY ROW VERIFIED',
                                   detail=f"launch row 2026 = {h['keys']} agrees with MICHELIN's live 2026 page; left as is"))
            f = dict(code=h['code'], phone=None, website_url=None)
            if f['phone'] or f['website_url']:
                hotel_fills.append(f)
        else:
            if mid in hurl_in_use:
                report.append(dict(country=CC, code='', name=k['name'], kind='HOTEL URL ALREADY IN USE', detail=k['michelin_url'] + ' -- not added'))
                continue
            code = f'hotel_{hcode}'; hcode += 1
            row = dict(code=code, name=k['name'], keys=keys, town=town_of(k['city']), address=k['address'],
                       lat=float(k['lat']), lon=float(k['lon']), michelin_url=k['michelin_url'],
                       website_url=k['website_url'] or None, phone=k['phone'] or None)
            new_hotels.append(row)
            hotel_by_mid[mid] = dict(code=code, name=k['name'], lat=row['lat'], lon=row['lon'], keys=keys, new=True)
    lost_keys = [h for m, h in ex_h.items() if m not in hotel_by_mid and h['keys'] is not None]
    for h in lost_keys:
        report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY NOT IN MICHELIN 2026',
                           detail=f"production michelin_keys = {h['keys']}; not a Key hotel in MICHELIN's 2026 listing -- left untouched, needs a decision"))

    # ---- match existing restaurants
    by_slug = collections.defaultdict(list)
    for r in research:
        by_slug[slug(r['michelin_url'])].append(r)
    ex = [r for r in rest if r['country'] == CC]
    matched, used = {}, set()
    for e in ex:
        m = how = None
        dr = dec_r.get(e['code'], {})
        if dr.get('michelin_url'):
            m = next((r for r in research if r['michelin_url'] == dr['michelin_url']), None)
            how = 'decision: ' + dr.get('match_evidence', '')
        s = slug(e.get('michelin_url'))
        cands = [r for r in by_slug.get(s, []) if path_town(r['michelin_url']) == path_town(e.get('michelin_url'))] if s and not m else []
        if len(cands) == 1 and cands[0]['michelin_url'] not in used:
            m, how = cands[0], 'michelin slug'
        if not m:
            near = sorted(((dist(e['lat'], e['lon'], float(r['lat']), float(r['lon'])), sim(e['name'], r['name']), i) for i, r in enumerate(research)
                           if r['michelin_url'] not in used))
            ok = [(d, sm, research[i]) for d, sm, i in near if (d <= 200 and sm >= 0.6) or (d <= 1000 and sm >= 0.9)]
            if len(ok) == 1:
                m, how = ok[0][2], f'coordinates {ok[0][0]} m + name'
            elif len(ok) > 1:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='AMBIGUOUS MATCH',
                                   detail='left unmatched, check by hand: ' + '; '.join(f"{r['name']} {d} m" for d, s_, r in ok)))
        if m:
            matched[e['code']] = m; used.add(m['michelin_url'])
            d = dist(e['lat'], e['lon'], float(m['lat']), float(m['lon']))
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='matched by ' + how,
                               detail=f"MICHELIN '{m['name']}' {m['michelin_url']}; stored point {d} m from MICHELIN's; stored url {e.get('michelin_url')}"))
            if d > 500:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED COORDINATES OFF',
                                   detail=f"stored point is {d} m from MICHELIN's"))

    relabel, changes, losses, corrections = [], [], [], []   # relabel: (code, to_year, value)
    for e in ex:
        hist = e.get('history') or []
        cur = [h for h in hist if h['current']]
        if len(cur) != 1:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='NO SINGLE CURRENT ROW', detail='left untouched -- check by hand'))
            continue
        cur = cur[0]
        m = matched.get(e['code'])
        live = int(m['stars']) if m else None
        dr = dec_r.get(e['code'], {})
        launch = cur['year'] == 2026 and cur['announced_on'] is None
        # Which edition does the launch row hold?
        if launch and star_year == 2025:
            # No 2026 Swiss edition exists yet: every 2026 label is wrong.
            v25 = dr.get('edition_value', live) if 'edition_value' in dr or m else None
            if v25 is None:
                raise SystemExit(f"{e['code']} {e['name']}: not in MICHELIN's live 2025 listing -- needs a decisions.json entry")
            if any(h['year'] == 2025 for h in hist):
                raise SystemExit(f"{e['code']}: already has a 2025 row")
            if cur['value'] == v25:
                relabel.append((e['code'], 2025, cur['value']))
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LAUNCH ROW RELABELLED 2026 -> 2025',
                                   detail=f"value {cur['value']} = MICHELIN Switzerland 2025 ({dr.get('evidence') or 'live 2025 page'}); values unchanged"))
            else:
                relabel.append((e['code'], 2025, cur['value']))
                corrections.append((e['code'], v25, cur['value'], 2025))
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED (and relabelled 2025)',
                                   detail=f"launch row 2026 = {cur['value']}; MICHELIN Switzerland 2025 gives {v25} ({dr.get('evidence') or 'live 2025 page'})"))
            after = v25
            if m is None:
                # in the 2025 edition but no longer live
                if dr.get('outcome') == 'loss':
                    losses.append((e['code'], dr.get('loss_year', 2025)))
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LOSS', detail=dr['evidence']))
                elif dr.get('outcome') == 'keep':
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='KEPT (in the 2025 edition, no longer live)', detail=dr['evidence']))
            continue
        if m and cur['value'] == live and cur['year'] == star_year:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind=f'{star_year} ROW VERIFIED',
                               detail=f"launch row {cur['year']} = {cur['value']} agrees with MICHELIN's live {star_year} page; left as is (announced_on stays NULL)"))
            continue
        if m and cur['year'] == star_year and cur['value'] != live:
            if dr.get('launch_row') == 'relabel':
                if any(h['year'] == dr['year'] for h in hist):
                    raise SystemExit(f"{e['code']}: already has a {dr['year']} row")
                relabel.append((e['code'], dr['year'], cur['value']))
                changes.append((e['code'], live, cur['value']))
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind=f"LAUNCH ROW RELABELLED 2026 -> {dr['year']}, 2026 CHANGE",
                                   detail=f"launch value {cur['value']} is MICHELIN's {dr['year']} value ({dr['evidence']}); 2026 = {live}"))
            else:
                corrections.append((e['code'], live, cur['value'], star_year))
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED',
                                   detail=f"{star_year} row holds {cur['value']}, MICHELIN {star_year} gives {live}" + (f" ({dr['evidence']})" if dr.get('evidence') else '')))
            continue
        if m is None and cur['value'] is not None:
            if dr.get('outcome') == 'keep':
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='KEPT (not live)', detail=dr['evidence']))
                continue
            if launch and dr.get('launch_row') == 'relabel':
                relabel.append((e['code'], dr['year'], cur['value']))
            losses.append((e['code'], star_year))
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind=f'LOSS (not in MICHELIN {star_year} listing)',
                               detail=f"{cur['value']} star(s) -> {star_year} NULL" + (f"; {dr['evidence']}" if dr.get('evidence') else ' -- confirm')))
            continue
        report.append(dict(country=CC, code=e['code'], name=e['name'], kind='UNHANDLED', detail=json.dumps(cur)))
        raise SystemExit(f"{e['code']} {e['name']}: unhandled history {hist} live={live}")

    # ---- hotel for a restaurant
    def host_for(r):
        if r['michelin_url'] in D.get('stay_exclude', {}):
            return (None, None, None, None)
        sid = hid(r['stay_hotel_url']) if r['stay_hotel_url'] else None
        if sid and sid in hotel_by_mid:
            h = hotel_by_mid[sid]
            d = dist(float(r['lat']), float(r['lon']), h['lat'], h['lon'])
            return ('link', h, 'exact' if d <= 100 else 'campus',
                    f"MICHELIN restaurant page 'Stay at the hotel' -> {r['stay_hotel_url']} ({r['stay_hotel_name']}), a {h['keys']}-Key hotel; restaurant pin {d} m from the hotel's MICHELIN pin. 2026-10-30.")
        if sid:  # stay link to a MICHELIN-selected (non-Key) hotel
            return ('property', r['stay_hotel_name'], None, 'MICHELIN restaurant page "Stay at the hotel" (no Key)')
        return (None, None, None, None)

    for u, ev in D.get('stay_exclude', {}).items():
        r = next((r for r in research if r['michelin_url'] == u), None)
        if r:
            report.append(dict(country=CC, code='', name=r['name'], kind='STAY LINK NOT USED', detail=ev))

    # ---- new restaurants
    new = []
    code = first_code
    for r in sorted(research, key=lambda r: n(r['name'])):
        if r['michelin_url'] in used:
            continue
        if r['michelin_url'] in url_in_use:
            report.append(dict(country=CC, code='', name=r['name'], kind='URL ALREADY IN USE ELSEWHERE', detail=r['michelin_url'] + ' -- not added'))
            continue
        new.append(dict(code=f'rest_{code}', r=r, town=town_of(r['city']))); code += 1

    new_links, prop_new = [], {}
    for x in new:
        kind, h, conf, ev = host_for(x['r'])
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
        f['michelin_url'] = m['michelin_url'] if not e.get('michelin_url') else None
        f['property_name'] = None
        kind, h, conf, ev = host_for(m)
        if kind == 'link' and (h['code'], e['code']) not in links:
            new_links.append((h['code'], e['code'], conf, ev))
        elif kind == 'property' and not e.get('property_name') and e['code'] not in linked_restaurants:
            f['property_name'] = h
        if e.get('phone') and m['michelin_phone'] and re.sub(r'\D', '', e['phone']) != re.sub(r'\D', '', m['michelin_phone']):
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED PHONE DIFFERS', detail=f"stored {e['phone']} vs MICHELIN {m['michelin_phone']} -- stored kept"))
        if e.get('michelin_url') and e['michelin_url'] != m['michelin_url']:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED MICHELIN URL DIFFERS', detail=f"stored {e['michelin_url']} vs {m['michelin_url']} -- stored kept"))
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
        report.append(dict(country=CC, code=h['code'], name=h['name'], kind='NEW KEY HOTEL', detail=f"{h['keys']} Key(s), {h['town']}; website and phone not researched (NULL)"))

    cnt = collections.Counter(int(r['stars']) for r in research)
    kept = [c for c, d in dec_r.items() if d.get('outcome') == 'keep' and any(e['code'] == c for e in ex)]
    for c in kept:
        e = next(e for e in ex if e['code'] == c)
        v = dec_r[c].get('edition_value', e['stars'])
        cnt[v] += 1
    keycnt = collections.Counter(h['keys'] for h in hotel_by_mid.values())
    summary = dict(existing=len(ex), matched=len(matched), relabel=len(relabel), changes=len(changes), losses=len(losses),
                   corrections=len(corrections), kept=len(kept), new=len(new), new_phones=sum(1 for x in new if x['r']['phone']),
                   new_place_ids=0, property_names=len(prop_new), links=len(new_links), fills=len(fills),
                   new_hotels=len(new_hotels), key_changes=len(key_changes), key_fixes=len(key_fix), keys_not_in_2026=len(lost_keys))
    last_rest, last_hotel = code - 1, hcode - 1

    # ---- SQL
    P = [f"\n-- ============================================================\n-- {CC}: {guide}\n-- ============================================================"]
    P.append(f"""do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}';
  if n <> {len(ex)} then raise exception '{CC}: expected {len(ex)} restaurants (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(e['code'])}, {q(e['name'])})" for e in ex)}) e(code, name)
   where not exists (select 1 from public.restaurants r where r.restaurant_code = e.code and r.name = e.name and r.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported restaurant codes no longer carry their exported name', n; end if;
""" if ex else '') + f"""  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len(hotels)} then raise exception '{CC}: expected {len(hotels)} hotels (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(h['code'])}, {q(h['name'])})" for h in hotels)}) e(code, name)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported hotel codes no longer carry their exported name', n; end if;
""" if hotels else '') + (f"""  if exists (select 1 from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'
              and substring(restaurant_code from 6)::int between {first_code} and {last_rest}) then
    raise exception 'restaurant codes rest_{first_code}..rest_{last_rest} are no longer free -- re-check';
  end if;
""" if new else '') + (f"""  if exists (select 1 from public.hotels where hotel_code ~ '^hotel_[0-9]+$'
              and substring(hotel_code from 7)::int between {first_hcode} and {last_hotel}) then
    raise exception 'hotel codes hotel_{first_hcode}..hotel_{last_hotel} are no longer free -- re-check';
  end if;
""" if new_hotels else '') + f"""  if exists (select 1 from public.award_history where award_type = 'michelin_keys' and is_current and guide_year <> 2026) then
    raise exception 'current michelin_keys rows are not all guide_year 2026 -- decide the year explicitly';
  end if;
end $$;""")

    if relabel:
        P.append(f"""-- 1. launch rows labelled 2026 that hold an earlier edition's value: relabel (values unchanged, QA-217 rule)
create temp table _relabel_{cc} (code text primary key, to_year smallint, val smallint) on commit drop;
insert into _relabel_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {y}, {qa(v)})" for c, y, v in relabel)};
do $$
declare n int;
begin
  select count(*) into n from _relabel_{cc} x join public.restaurants r on r.restaurant_code = x.code
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id and ah.award_type = 'michelin_stars'
   where ah.guide_year = 2026 and ah.is_current and ah.announced_on is null and ah.award_value is not distinct from x.val
     and not exists (select 1 from public.award_history o where o.entity_type = 'restaurant' and o.entity_id = r.id
                      and o.award_type = 'michelin_stars' and o.guide_year = x.to_year);
  if n <> {len(relabel)} then raise exception '{CC}: % of {len(relabel)} launch rows found as exported (current 2026, no target-year row) -- has this file run?', n; end if;
end $$;
update public.award_history ah set guide_year = x.to_year
  from public.restaurants r, _relabel_{cc} x
 where r.restaurant_code = x.code and ah.entity_type = 'restaurant' and ah.entity_id = r.id
   and ah.award_type = 'michelin_stars' and ah.guide_year = 2026 and ah.is_current and ah.announced_on is null;""")
    if corrections:
        P.append(f"""-- 2. import errors corrected in place (launch value matches no MICHELIN edition; see match_report.csv)
create temp table _fix_{cc} (code text primary key, stars smallint, was smallint, yr smallint) on commit drop;
insert into _fix_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {qa(s)}, {qa(w)}, {y})" for c, s, w, y in corrections)};
update public.award_history ah set award_value = f.stars
  from public.restaurants r, _fix_{cc} f
 where r.id = ah.entity_id and r.restaurant_code = f.code and ah.entity_type = 'restaurant'
   and ah.award_type = 'michelin_stars' and ah.guide_year = f.yr and ah.is_current and ah.award_value = f.was;
update public.restaurants r set michelin_stars = f.stars, updated_at = now()
  from _fix_{cc} f where r.restaurant_code = f.code and r.michelin_stars = f.was;""")
    if changes or losses:
        rows = [(c, s, star_year) for c, s, _ in changes] + [(c, None, y) for c, y in losses]
        P.append(f"""-- 3. changes and losses: close the current row, open the new edition's row
create temp table _chg_{cc} (code text primary key, stars smallint, yr smallint) on commit drop;
insert into _chg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {qa(s)}, {y})" for c, s, y in rows)};
update public.award_history ah set is_current = false
  from public.restaurants r, _chg_{cc} c
 where r.id = ah.entity_id and r.restaurant_code = c.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.is_current;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, c.yr, 'michelin_stars', c.stars, true, date '{announced}'
  from public.restaurants r join _chg_{cc} c on c.code = r.restaurant_code;
update public.restaurants r set michelin_stars = c.stars, updated_at = now()
  from _chg_{cc} c where r.restaurant_code = c.code;""")
    if new_hotels:
        P.append(f"""-- 4. MICHELIN Key hotels missing from `hotels` (each with its current 2026 Key row below);
--    website and phone NULL: not researched in this pass (README)
create temp table _new_hotels_{cc} (code text, name text, keys smallint, city text, address text, lon float8, lat float8,
                               michelin_url text, website_url text, phone text) on commit drop;
insert into _new_hotels_{cc} values
{(','+chr(10)).join(f"    ({q(h['code'])}, {q(h['name'])}, {h['keys']}::smallint, {q(h['town'])}, {q(h['address'])}, {h['lon']}, {h['lat']}, {q(h['michelin_url'])}, {q(h['website_url'])}, {q(h['phone'])})" for h in new_hotels)};
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_hotels_{cc} x
   where (select count(*) from public.cities c where c.country_code = '{CC}' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'hotel city does not resolve to exactly one {CC} row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_hotels_{cc} x join public.hotels h on h.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'hotel already present (michelin_url): %', bad; end if;
end $$;
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url, website_url, phone)
select x.code, x.name, x.keys,
       (select c.id from public.cities c where c.country_code = '{CC}' and c.name = x.city), '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone
  from _new_hotels_{cc} x;""")
    if key_changes:
        P.append(f"""-- 4b. Key changes on existing hotels: the launch row (labelled 2026) holds the 2025 Key and is
--     relabelled 2025, non-current; the 2026 row is written in 4d
create temp table _kchg_{cc} (code text primary key, keys smallint, was smallint, launch_year smallint) on commit drop;
insert into _kchg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {w}, {next(y for cc2, y, _ in key_relabel if cc2 == c)})" for c, k, w in key_changes)};
do $$
declare n int;
begin
  select count(*) into n from _kchg_{cc} k join public.hotels h on h.hotel_code = k.code and h.michelin_keys = k.was
    join public.award_history a on a.entity_type = 'hotel' and a.entity_id = h.id and a.award_type = 'michelin_keys'
   where a.is_current and a.guide_year = 2026 and a.award_value = k.was
     and not exists (select 1 from public.award_history o where o.entity_type = 'hotel' and o.entity_id = h.id
                      and o.award_type = 'michelin_keys' and o.guide_year = k.launch_year);
  if n <> {len(key_changes)} then raise exception '{CC}: % of {len(key_changes)} Key launch rows found as exported', n; end if;
end $$;
update public.award_history a set guide_year = k.launch_year, is_current = false
  from public.hotels h, _kchg_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys'
   and a.is_current and a.guide_year = 2026;
update public.hotels h set michelin_keys = k.keys, updated_at = now() from _kchg_{cc} k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
    if key_fix:
        P.append(f"""-- 4c. Key import errors corrected in place
create temp table _kfix_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kfix_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {w})" for c, k, w in key_fix)};
update public.award_history a set award_value = k.keys from public.hotels h, _kfix_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys'
   and a.is_current and a.guide_year = 2026 and a.award_value = k.was;
update public.hotels h set michelin_keys = k.keys, updated_at = now() from _kfix_{cc} k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
    if hotel_by_mid:
        P.append(f"""-- 4d. current 2026 Key row for every {CC} Key hotel that lacks one (new rows, Key changes,
--     and existing rows imported without one)
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, {KEY_YEAR}, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED_KEYS}'
  from public.hotels h
 where h.hotel_code = any(array[{', '.join(q(h['code']) for h in hotel_by_mid.values())}])
   and not exists (select 1 from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
                    and a.award_type = 'michelin_keys' and a.is_current);""")
    if new:
        P.append(f"""-- 5. starred restaurants missing from the catalogue (Place ID NULL: no Places API in this pass)
create temp table _new_{cc} (code text, name text, stars smallint, city text, address text, lon float8, lat float8,
                        michelin_url text, website_url text, phone text, property_name text, place_id text) on commit drop;
insert into _new_{cc} values
{(','+chr(10)).join(f"    ({q(x['code'])}, {q(x['r']['name'])}, {x['r']['stars']}::smallint, {q(x['town'])}, {q(x['r']['address'])}, {x['r']['lon']}, {x['r']['lat']}, {q(x['r']['michelin_url'])}, {q(x['r']['website'])}, {q(x['r']['phone'])}, {q(prop_new.get(x['code']))}, NULL)" for x in new)};
do $$
declare bad text;
begin
  select string_agg(x.code, ', ') into bad from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;
  if bad is not null then raise exception 'codes no longer free: %', bad; end if;
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_{cc} x
   where (select count(*) from public.cities c where c.country_code = '{CC}' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one {CC} row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_{cc} x join public.restaurants r on r.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'already present (michelin_url): %', bad; end if;
end $$;
insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
                                address, location, michelin_url, website_url, phone, property_name, google_place_id)
select x.code, x.name, x.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = '{CC}' and c.name = x.city), '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone, x.property_name, x.place_id
  from _new_{cc} x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, {star_year}, 'michelin_stars', x.stars, true, date '{announced}'
  from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;""")
    if fills:
        P.append(f"""-- 6. existing restaurants, fill-only (never overwrites)
create temp table _fill_{cc} (code text primary key, phone text, website_url text, michelin_url text, property_name text) on commit drop;
insert into _fill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])}, {q(f['michelin_url'])}, {q(f['property_name'])})" for f in fills)};
update public.restaurants r set phone = f.phone, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set website_url = f.website_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.website_url is not null and r.website_url is null;
update public.restaurants r set michelin_url = f.michelin_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.michelin_url is not null and r.michelin_url is null;
update public.restaurants r set property_name = f.property_name, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.property_name is not null and r.property_name is null
   and not exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);""")
    if new_links:
        P.append(f"""-- 7. links to hotels in `hotels`
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
    P.append(f"""-- post-conditions: {guide}, live listing; MICHELIN 2026 Keys
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 3;
  if n <> {cnt[3]} then raise exception '{CC}: expected {cnt[3]} three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 2;
  if n <> {cnt[2]} then raise exception '{CC}: expected {cnt[2]} two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 1;
  if n <> {cnt[1]} then raise exception '{CC}: expected {cnt[1]} one-star, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}'
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '{CC}: % restaurants without exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '{CC}: % restaurants disagree with their current award row', n; end if;
  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.guide_year > {star_year};
  if n <> 0 then raise exception '{CC}: % current star rows labelled after the {star_year} edition', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '{CC}: % restaurants have both a hotel link and a property_name', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 3{excl};
  if n <> {keycnt[3]} then raise exception '{CC}: expected {keycnt[3]} three-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 2{excl};
  if n <> {keycnt[2]} then raise exception '{CC}: expected {keycnt[2]} two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 1{excl};
  if n <> {keycnt[1]} then raise exception '{CC}: expected {keycnt[1]} one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = '{CC}' and h.michelin_keys is not null{excl.replace('hotel_code', 'h.hotel_code')}
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys and a.guide_year = {KEY_YEAR}) <> 1;
  if n <> 0 then raise exception '{CC}: % Key hotels without exactly one matching current 2026 Key row', n; end if;
end $$;""")
    return dict(P=P, report=report, towns=sorted(newtowns), summary=summary, cnt=cnt, keycnt=keycnt,
                next_code=code, next_hcode=hcode)


def main():
    export_path, first_code, first_hcode, mig_name = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    X = json.load(open(export_path))
    if isinstance(X, list):
        X = X[0]
    D = json.load(open(os.path.join(HERE, 'decisions.json')))
    present = {c['country_code'] for c in X.get('countries_present') or []}
    out, code, hcode = {}, first_code, first_hcode
    for CC in GUIDES:
        out[CC] = country(CC, X, D, code, hcode)
        code, hcode = out[CC]['next_code'], out[CC]['next_hcode']
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'detail'])
        w.writeheader()
        for CC in out:
            w.writerows(out[CC]['report'])
    rows = [(CC, t) for CC in out for t in out[CC]['towns']]
    new_countries = ''.join(f"""
-- {name}: production has no `countries` row for {cc} (read-only check
-- 2026-10-30), and every {cc} city and restaurant below references one.
-- MICHELIN's Nordic Countries guide covers {name} (2026 edition: 3 one-star
-- restaurants, 5 Key hotels). As in 20261023140000 for Ireland, the country
-- comes first, with its IANA zone (`timezones` is NOT NULL with at least one
-- zone since 20261018120000_add_country_timezones.sql): tzdata zone.tab has a
-- single {cc} entry, {tz[0]} (read on this machine 2026-10-30).
insert into public.countries (country_code, name, flag_emoji, timezones)
values ('{cc}', {q(name)}, '{flag}', array[{', '.join(q(z) for z in tz)}])
on conflict (country_code) do nothing;
""" for cc, (name, flag, tz) in NEW_COUNTRIES.items() if cc not in present)
    open(os.path.join(MIG_DIR, mig_name), 'w').write(f"""-- MICHELIN Switzerland 2025, Austria 2026, Nordic Countries 2026 and the 2026
-- Key hotels of those countries: the country and city prerequisite for the
-- starred restaurants and Key hotels added by
-- supabase/data/enrichment/michelin_ch_at_nordic_2026/prepared_ch_at_nordic_stars_2026.sql.
-- Generated by build_prepared.py from production's export (written
-- 2026-10-30). Filename timestamp is a sequence number only. Names are
-- MICHELIN's own English listing town names (restaurants) or the hotel page's
-- locality (hotels); a name production already holds for the same
-- municipality is reused (Bern, St. Moritz, St. Gallen, ...). None exists in
-- production's export, compared accent-, case-, space- and
-- hyphen-insensitively. region and postal_municipality left NULL, matching the
-- existing rows. Idempotent: ON CONFLICT targets countries_pkey and
-- cities_unique_key.

begin;
{new_countries}
insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, NULL)" for c, t in rows) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    summ = {CC: out[CC]['summary'] for CC in out}
    head = f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Switzerland, Austria and Nordic Countries (Denmark, Faroe Islands,
-- Sweden, Norway, Finland, Iceland): bring every restaurant's stars and
-- award_history in line with MICHELIN's live selections, add the starred
-- restaurants and the 2026 Key hotels missing from the catalogue, link
-- restaurants to Key hotels where MICHELIN says so, and complete existing rows
-- (fill-only). Editions:
--   CH  MICHELIN Guide Switzerland 2025, announced 20 October 2025 (the 2026
--       edition is announced 2 November 2026: re-run this pass after it)
--   AT  MICHELIN Guide Austria 2026, announced 18 March 2026
--   Nordic Countries 2026, announced 1 June 2026 (DK, FO, SE, NO, FI, IS)
--   Keys: MICHELIN global Key launch 2026, 18 September 2026
-- Generated by build_prepared.py; evidence and every judgement call in
-- match_report.csv, decisions.json and README.md.
--
""" + ''.join(f"-- Summary {CC}: {json.dumps(summ[CC])}\n" for CC in out) + f"""--
-- PREREQUISITE: supabase/migrations/{mig_name}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;
"""
    open(os.path.join(HERE, 'prepared_ch_at_nordic_stars_2026.sql'), 'w').write(
        head + '\n'.join('\n\n'.join(out[CC]['P']) for CC in out) + '\n\ncommit;\n')
    for CC in out:
        print(CC, json.dumps(out[CC]['summary']))
        print('  towns:', len(out[CC]['towns']), '| report:', dict(collections.Counter(r['kind'] for r in out[CC]['report'])))
        print('  expected stars:', dict(out[CC]['cnt']), 'keys:', dict(out[CC]['keycnt']))
    print('codes rest', first_code, '..', code - 1, 'hotel', first_hcode, '..', hcode - 1)


if __name__ == '__main__':
    main()
