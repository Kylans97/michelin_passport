#!/usr/bin/env python3
"""Build the Hong Kong (HK), Macau (MO) and Taiwan (TW) prepared SQL from production's export.

Usage:
  python3 build_prepared.py <export.json> <first_rest_code> <first_hotel_code> <migration_name>

  export.json      the JSON cell of export_hk_mo_tw_query.sql (saved as a file)
  first_rest_code  first restaurant code number (above production's max and every claimed range)
  first_hotel_code first hotel code number (same rule)
  migration_name   e.g. 20261023170000_add_hk_mo_tw_2026_star_and_key_cities.sql

Copied from ../michelin_cn_2026/build_prepared.py, one block per country (as
../michelin_gb_ie_2026 did for GB and IE). Reads only committed research here:
  hk_mo_tw_research_2026.csv     MICHELIN restaurant pages, edition, phone evidence, host hotel
  hk_mo_tw_key_hotels_2026.csv   HK/MO/TW Key hotels: MICHELIN page + website/phone research
Writes match_report.csv, prepared_hk_mo_tw_stars_2026.sql and ../../../migrations/<migration_name>.

Rules applied (see README.md):
  * HK and MO are MICHELIN's Hong Kong & Macau 2026 guide (19 Mar 2026), TW its
    Taiwan 2026 guide (21 Jul 2026); every award row is guide_year 2026;
  * existing restaurants are matched by MICHELIN slug and town segment, else by
    coordinates + name (no GCJ-02 offset outside mainland China), else by hand
    with stated evidence (MANUAL_MATCH) -- never by name alone; existing hotels
    by MICHELIN's numeric hotel id;
  * a stored value MICHELIN's current edition confirms is left as is;
  * new restaurants: Place ID NULL; phone only when MICHELIN's number is on
    the venue's own site;
  * hotel link when MICHELIN's restaurant page says "Stay at the hotel" for a
    Key hotel, or MICHELIN's restaurant address puts it inside a Key hotel (or a
    World's 50 Best hotel already in `hotels`) whose address gives the same street,
    within 300 m; an existing row's property_name naming that hotel is cleared
    (hotel scope rule 3). A host hotel not in `hotels` goes in property_name.
"""
import csv, json, math, os, re, sys, unicodedata, difflib, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'michelin_cn_2026'))
from gcj02 import dist as _dist

HERE = os.path.dirname(os.path.abspath(__file__))
MIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), 'migrations')

ANNOUNCED_KEYS = '2026-09-18'    # MICHELIN Key 2026 global reveal
LINK_MAX_M = 300
COUNTRIES = ('HK', 'MO', 'TW')
# Existing rows MICHELIN identifies, but whose stored point is too far for the coordinate rule.
MANUAL_MATCH = {
    'rest_0463': ('https://guide.michelin.com/en/taichung-region/taichung/restaurant/jl-studio',
                  "the only JL Studio in MICHELIN's Taiwan listing, same city (Taichung), three stars continuously "
                  "(stored 2023 = 3, 2026 = 3; MICHELIN Taiwan 2026 article: 'JL Studio in Taichung ... kept' three stars); "
                  "MICHELIN's address (59 Cunzhong Street, West District) is 3.3 km from the stored one "
                  "(689 Yifeng Road Sec. 4, Nantun) -- probably a relocation; the restaurant's own site is a placeholder"),
}


def n(s):
    return re.sub(r'[^a-z0-9 ]', '', unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower())


STOP = {'restaurant', 'hotel', 'by', 'the', 'at', 'and', 'in', 'of', 'a'}


def toks(s):
    return {t for t in n(s).split() if t not in STOP and len(t) > 1}


def sim(a, b):
    ta, tb = toks(a), toks(b)
    if ta and tb and (ta <= tb or tb <= ta):
        return 1.0
    return difflib.SequenceMatcher(None, n(a).replace(' ', ''), n(b).replace(' ', '')).ratio()


def dist(a, b, c, d):
    return _dist(float(a), float(b), float(c), float(d))


def slug(u):
    m = re.search(r'/restaurant/([^/?#]+)', u or '')
    return m.group(1).lower() if m else None


def path_town(u):
    m = re.search(r'/([^/]+)/restaurant/', u or '')
    return m.group(1).lower() if m else None


def hid(u):
    m = re.search(r'-(\d+)/?$', (u or '').split('?')[0])
    return m.group(1) if m else None


GENERIC = {'road', 'street', 'drive', 'lane', 'avenida', 'estrada', 'rua', 'macau', 'macao', 'cotai', 'hong', 'kong',
           'central', 'kowloon', 'taipei', 'section', 'district', 'resort', 'hotel', 'tower'}


def street_toks(s):
    return {t for t in n(s).split() if len(t) > 3 and t not in GENERIC}


def nums(s):
    return set(re.findall(r'\d+', s or ''))


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


def country(CC, X, first_code, first_hcode):
    cc = CC.lower()
    rest = X.get('restaurants') or []
    cities = X.get('cities') or []
    hotels = X.get('hotels') or []
    links = {(l['hotel_code'], l['restaurant_code']) for l in (X.get('links') or [])}
    linked_restaurants = {l['restaurant_code'] for l in (X.get('links') or [])}
    url_in_use = set(X.get('michelin_urls_in_use') or [])
    hurl_in_use = set(X.get('hotel_michelin_urls_in_use') or [])
    research = [r for r in csv.DictReader(open(os.path.join(HERE, 'hk_mo_tw_research_2026.csv'))) if r['country'] == CC]
    keyh = [k for k in csv.DictReader(open(os.path.join(HERE, 'hk_mo_tw_key_hotels_2026.csv'))) if k['country'] == CC]
    assert CC in {c['country_code'] for c in X.get('countries_present') or []}, f'production has no {CC} countries row'
    ex_by_code = {h['code']: h for h in hotels if h['country'] == CC}

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

    for r in research:
        town_of(r['city'])

    # ---- hotels: existing matched by MICHELIN id; the rest are new
    ex_h = {hid(h['michelin_url']): h for h in hotels if h['country'] == CC}
    hotel_by_mid = {}
    new_hotels, key_changes, hotel_fills = [], [], []
    hcode = first_hcode
    for k in keyh:
        mid = k['michelin_id']
        keys = int(k['keys'])
        if mid in ex_h:
            h = ex_h[mid]
            hotel_by_mid[mid] = dict(code=h['code'], name=h['name'], lat=float(k['lat']), lon=float(k['lon']), keys=keys, new=False,
                                     street=k['street'])
            d = dist(h['lat'], h['lon'], k['lat'], k['lon'])
            report.append(dict(code=h['code'], name=h['name'], kind='HOTEL matched by MICHELIN id',
                               detail=f"{mid}; stored point {d} m from MICHELIN's pin"))
            if h['keys'] != keys:
                key_changes.append((h['code'], keys, h['keys']))
                report.append(dict(code=h['code'], name=h['name'], kind='KEY CHANGE',
                                   detail=f"{h['keys']} -> {keys}: MICHELIN's hotel page carries {keys} Key(s) (2026 Keys, 18 Sep 2026)"))
            f = dict(code=h['code'], phone=k['phone'] if not h.get('phone') and k['phone'] else None,
                     website_url=k['website_url'] if not h.get('website_url') and k['website_url'] else None)
            if f['phone'] or f['website_url']:
                hotel_fills.append(f)
        else:
            if k['michelin_url'] in hurl_in_use:
                report.append(dict(code='', name=k['name'], kind='HOTEL URL ALREADY IN USE', detail=k['michelin_url'] + ' -- not added'))
                continue
            code = f'hotel_{hcode}'; hcode += 1
            row = dict(code=code, name=k['name'], keys=keys, town=town_of(k['city']), address=k['address'],
                       lat=float(k['lat']), lon=float(k['lon']), michelin_url=k['michelin_url'],
                       website_url=k['website_url'] or None, phone=k['phone'] or None)
            new_hotels.append(row)
            hotel_by_mid[mid] = dict(code=code, name=k['name'], lat=row['lat'], lon=row['lon'], keys=keys, new=True, street=k['street'])
    lost_keys = [h for m, h in ex_h.items() if m not in hotel_by_mid and h['keys'] is not None]
    for h in lost_keys:
        report.append(dict(code=h['code'], name=h['name'], kind='KEY NOT IN MICHELIN 2026',
                           detail=f"production michelin_keys = {h['keys']}; MICHELIN's page carries no Key -- left untouched, needs a decision"))
    for r in research:
        r['lat0'], r['lon0'] = r['lat'], r['lon']

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
        if not m and e['code'] in MANUAL_MATCH:
            mm = [r for r in research if r['michelin_url'] == MANUAL_MATCH[e['code']][0] and r['michelin_url'] not in used]
            if len(mm) == 1:
                m, how = mm[0], 'hand (' + MANUAL_MATCH[e['code']][1] + ')'
        if not m:
            near = sorted(((dist(e['lat'], e['lon'], float(r['lat0']), float(r['lon0'])), sim(e['name'], r['name']), i)
                           for i, r in enumerate(research) if r['michelin_url'] not in used))
            ok = [(d, sm, research[i]) for d, sm, i in near if (d <= 200 and sm >= 0.6) or (d <= 1000 and sm >= 0.9)]
            if len(ok) == 1:
                m, how = ok[0][2], f'coordinates {ok[0][0]} m + name'
            elif len(ok) > 1:
                report.append(dict(code=e['code'], name=e['name'], kind='AMBIGUOUS MATCH', detail='left unmatched, check by hand'))
        if m:
            matched[e['code']] = m; used.add(m['michelin_url'])
            d = dist(e['lat'], e['lon'], m['lat0'], m['lon0'])
            report.append(dict(code=e['code'], name=e['name'], kind='matched by ' + how.split(' (')[0],
                               detail=f"{how}: MICHELIN '{m['name']}' {m['michelin_url']}; MICHELIN address '{m['address']}', stored '{e['address']}'; "
                                      f"stored point {d} m from MICHELIN's pin" + (' -- stored address and point NOT changed (QA)' if d > 500 else '')))

    changes, losses, corrections = [], [], []
    for e in ex:
        cur = [h for h in (e.get('history') or []) if h['current']]
        if len(cur) != 1:
            report.append(dict(code=e['code'], name=e['name'], kind='NO SINGLE CURRENT ROW', detail='left untouched -- check by hand'))
            continue
        cur = cur[0]
        m = matched.get(e['code'])
        if m:
            s, y = int(m['stars']), int(m['guide_year'])
            if cur['value'] == s:
                report.append(dict(code=e['code'], name=e['name'], kind='CURRENT ROW VERIFIED',
                                   detail=f"current row {cur['year']} = {cur['value']}; MICHELIN {m['selection']} {y} gives {s} -- unchanged, no action (DATA_UPDATE_PROCESS §3)"))
            elif cur['year'] == y:
                corrections.append((e['code'], s, cur['value'], y))
                report.append(dict(code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED', detail=f"{y} row holds {cur['value']}, MICHELIN {y} gives {s}"))
            elif cur['year'] < y:
                changes.append((e['code'], s, cur['value'], y, m['announced_on']))
                report.append(dict(code=e['code'], name=e['name'], kind='CHANGE', detail=f"{cur['year']} = {cur['value']} -> {y} = {s}"))
            else:
                report.append(dict(code=e['code'], name=e['name'], kind='CURRENT ROW NEWER THAN MICHELIN EDITION', detail='left untouched -- check by hand'))
        elif cur['value'] is not None and e['stars'] is not None:
            losses.append(e['code'])
            report.append(dict(code=e['code'], name=e['name'], kind='NOT IN MICHELIN LISTING', detail=f"{cur['value']} star(s); left untouched -- check by hand"))
    assert not losses, f'a {CC} loss needs a decision by hand'

    # ---- hotel for a restaurant
    def host_for(r, code):
        if r['host_kind'] in ('key', 'hotel'):
            if r['host_kind'] == 'key':
                h = hotel_by_mid[r['host']]
            else:   # a non-Key hotel already in `hotels` (World's 50 Best): production's own row
                e = ex_by_code[r['host']]
                h = dict(code=e['code'], name=e['name'], lat=e['lat'], lon=e['lon'], keys=e['keys'], street=e['address'])
            d = dist(r['lat'], r['lon'], h['lat'], h['lon'])
            street = h['street']
            # the same street number, or (no number on the hotel page) every distinctive word of its street address
            same_no = (nums(street) & nums(r['address'])) if nums(street) else bool(street_toks(street)) and street_toks(street) <= street_toks(r['address'])
            if not same_no or d > LINK_MAX_M:
                report.append(dict(code=code, name=r['name'], kind='KEY HOTEL HOST NOT LINKED',
                                   detail=f"MICHELIN's address '{r['address']}' names {h['name']} ({h['code']}, address '{h['street']}'), "
                                          f"but {'the streets differ' if not same_no else f'the two MICHELIN points are {d} m apart'} -- no link, no property_name; decide by hand"))
                return (None, None, None, None)
            return ('link', h, 'exact',
                    (f"{r['host_evidence']} ({h['name']}); " if r['host_evidence'].startswith('MICHELIN restaurant page') else
                     f"MICHELIN restaurant page address '{r['address']}' places it in {h['name']}; ")
                    + (f"MICHELIN's Key hotel page ({h['keys']} Key(s)) gives" if r['host_kind'] == 'key' else f"production's {h['code']} (World's 50 Best, no Key) gives")
                    + f" '{h['street']}' ({'same street number' if nums(street) else 'same street'}); points {d} m apart. 2026-10-29.")
        if r['host_kind'] == 'property':
            return ('property', r['host'], None, None)
        return (None, None, None, None)

    # ---- new restaurants
    new = []
    code = first_code
    for r in sorted(research, key=lambda r: n(r['name']) + ' ' + r['michelin_url']):
        if r['michelin_url'] in used:
            continue
        if r['michelin_url'] in url_in_use:
            report.append(dict(code='', name=r['name'], kind='URL ALREADY IN USE ELSEWHERE', detail=r['michelin_url'] + ' -- not added'))
            continue
        new.append(dict(code=f'rest_{code}', r=r, town=town_of(r['city']))); code += 1

    new_links, prop_new = [], {}
    for x in new:
        kind, h, conf, ev = host_for(x['r'], x['code'])
        if kind == 'link':
            new_links.append((h['code'], x['code'], conf, ev))
        elif kind == 'property':
            prop_new[x['code']] = h
    fills, clears = [], []
    for e in ex:
        m = matched.get(e['code'])
        if not m:
            continue
        f = dict(code=e['code'])
        f['phone'] = m['phone'] if not e.get('phone') and m['phone'] else None
        f['website_url'] = m['website'] if not e.get('website_url') and m['website'] else None
        f['michelin_url'] = m['michelin_url'] if not e.get('michelin_url') else None
        f['property_name'] = None
        kind, h, conf, ev = host_for(m, e['code'])
        if kind == 'link' and (h['code'], e['code']) not in links:
            new_links.append((h['code'], e['code'], conf, ev))
            if e.get('property_name'):
                # hotel scope rule 3: property_name only for a hotel NOT in `hotels`; the link replaces it
                clears.append((e['code'], e['property_name']))
                report.append(dict(code=e['code'], name=e['name'], kind='property_name CLEARED (now linked)',
                                   detail=f"stored property_name '{e['property_name']}' names {h['name']} ({h['code']}), which is in `hotels` -- replaced by the link (CLAUDE.md hotel scope rule 3)"))
        elif kind == 'property' and not e.get('property_name') and e['code'] not in linked_restaurants:
            f['property_name'] = h
        if e.get('phone') and m['michelin_phone'] and re.sub(r'\D', '', e['phone']) != re.sub(r'\D', '', m['michelin_phone']):
            report.append(dict(code=e['code'], name=e['name'], kind='STORED PHONE DIFFERS', detail=f"stored {e['phone']} vs MICHELIN {m['michelin_phone']} -- stored kept"))
        if any(f[k] for k in ('phone', 'website_url', 'michelin_url', 'property_name')):
            fills.append(f)
            report.append(dict(code=e['code'], name=e['name'], kind='FILL (only empty fields)', detail=json.dumps({k: v for k, v in f.items() if v and k != 'code'}, ensure_ascii=False)))
    for x in new:
        r = x['r']
        if not r['phone'] and r['michelin_phone']:
            report.append(dict(code=x['code'], name=r['name'], kind='PHONE HELD BACK', detail=f"MICHELIN {r['michelin_phone']}: {r['phone_source']}"))
        if x['code'] in prop_new:
            report.append(dict(code=x['code'], name=r['name'], kind='property_name', detail=f"{prop_new[x['code']]} (MICHELIN address: {r['address']})"))
    for hc, rc, conf, ev in new_links:
        report.append(dict(code=rc, name=next((x['r']['name'] for x in new if x['code'] == rc), rc), kind=f'HOTEL LINK ({conf})', detail=f'{hc}: {ev}'))
    for h in new_hotels:
        if not h['phone'] or not h['website_url']:
            report.append(dict(code=h['code'], name=h['name'], kind='HOTEL CONTACT MISSING',
                               detail=('no website; ' if not h['website_url'] else '') + ('no phone' if not h['phone'] else '') + ' -- see hk_mo_tw_key_hotels_2026.csv'))

    cnt = collections.Counter(int(r['stars']) for r in research)
    keycnt = collections.Counter(h['keys'] for h in hotel_by_mid.values())
    summary = dict(existing=len(ex), matched=len(matched), property_names_cleared=len(clears), changes=len(changes), corrections=len(corrections),
                   new=len(new), new_phones=sum(1 for x in new if x['r']['phone']), new_websites=sum(1 for x in new if x['r']['website']),
                   new_place_ids=0, property_names=len(prop_new), links=len(new_links), fills=len(fills),
                   new_hotels=len(new_hotels), new_hotel_phones=sum(1 for h in new_hotels if h['phone']),
                   new_hotel_websites=sum(1 for h in new_hotels if h['website_url']), key_changes=len(key_changes),
                   hotel_fills=len(hotel_fills), keys_not_in_2026=len(lost_keys))
    last_rest, last_hotel = code - 1, hcode - 1
    by_year = collections.Counter((x['r']['guide_year'], x['r']['announced_on']) for x in new)

    # ---- SQL
    ex_hotels = [h for h in hotels if h['country'] == CC]
    P = []
    hotel_name_guard = (f"""  select count(*) into n from (values {', '.join(f"({q(h['code'])}, {q(h['name'])})" for h in ex_hotels)}) e(code, name)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported hotel codes no longer carry their exported name', n; end if;
""" if ex_hotels else '')
    P.append(f"""do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}';
  if n <> {len(ex)} then raise exception '{CC}: expected {len(ex)} restaurants (export), found % -- production changed, re-check', n; end if;
  select count(*) into n from (values {', '.join(f"({q(e['code'])}, {q(e['name'])})" for e in ex)}) e(code, name)
   where not exists (select 1 from public.restaurants r where r.restaurant_code = e.code and r.name = e.name and r.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported restaurant codes no longer carry their exported name', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len(ex_hotels)} then raise exception '{CC}: expected {len(ex_hotels)} hotels (export), found % -- production changed, re-check', n; end if;
{hotel_name_guard}  if exists (select 1 from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'
              and substring(restaurant_code from 6)::int between {first_code} and {last_rest}) then
    raise exception 'restaurant codes rest_{first_code}..rest_{last_rest} are no longer free -- re-check';
  end if;
  if exists (select 1 from public.hotels where hotel_code ~ '^hotel_[0-9]+$'
              and substring(hotel_code from 7)::int between {first_hcode} and {last_hotel}) then
    raise exception 'hotel codes hotel_{first_hcode}..hotel_{last_hotel} are no longer free -- re-check';
  end if;
  if (select count(distinct guide_year) from public.award_history where award_type = 'michelin_keys' and is_current) > 1
     or exists (select 1 from public.award_history where award_type = 'michelin_keys' and is_current and guide_year <> 2026) then
    raise exception 'current michelin_keys rows are not all guide_year 2026 -- decide the year explicitly';
  end if;
end $$;""")

    P.append(f"""-- ============================================================
-- {CC}
-- ============================================================""")
    P.append(f"""-- 1. MICHELIN Key hotels missing from `hotels` (each with its current 2026 Key row).
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
        P.append(f"""-- 1b. Key changes on existing hotels (NULL-safe: a World's 50 Best hotel may hold no Key yet)
create temp table _kchg_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kchg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {'NULL' if w is None else w})" for c, k, w in key_changes)};
update public.award_history a set is_current = false from public.hotels h, _kchg_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys' and a.is_current;
update public.hotels h set michelin_keys = k.keys, updated_at = now() from _kchg_{cc} k
 where h.hotel_code = k.code and h.michelin_keys is not distinct from k.was;""")
    P.append(f"""-- 1c. current 2026 Key row for every {CC} Key hotel that lacks one (the August World's 50 Best import left the
--     existing ones without; PE_REPORT finding 1)
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED_KEYS}'
  from public.hotels h
 where h.hotel_code = any(array[{', '.join(q(h['code']) for h in hotel_by_mid.values())}])
   and not exists (select 1 from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
                    and a.award_type = 'michelin_keys' and a.is_current);""")
    if hotel_fills:
        P.append(f"""-- 1d. existing {CC} hotels, fill-only (never overwrites)
create temp table _hfill_{cc} (code text primary key, phone text, website_url text) on commit drop;
insert into _hfill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])})" for f in hotel_fills)};
update public.hotels h set phone = f.phone, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.phone is not null and h.phone is null;
update public.hotels h set website_url = f.website_url, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.website_url is not null and h.website_url is null;""")
    if changes:
        P.append(f"""-- 2. changes in the current edition of each restaurant's guide: close the current row, open the new one
create temp table _chg_{cc} (code text primary key, stars smallint, guide_year smallint, announced_on date) on commit drop;
insert into _chg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {s}, {y}, date '{a}')" for c, s, _, y, a in changes)};
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
        P.append(f"""-- 3. import errors corrected in place
create temp table _fix_{cc} (code text primary key, stars smallint, was smallint, guide_year smallint) on commit drop;
insert into _fix_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {s}, {w}, {y})" for c, s, w, y in corrections)};
update public.award_history ah set award_value = f.stars
  from public.restaurants r, _fix_{cc} f
 where r.id = ah.entity_id and r.restaurant_code = f.code and ah.entity_type = 'restaurant'
   and ah.award_type = 'michelin_stars' and ah.guide_year = f.guide_year and ah.is_current and ah.award_value = f.was;
update public.restaurants r set michelin_stars = f.stars, updated_at = now()
  from _fix_{cc} f where r.restaurant_code = f.code and r.michelin_stars = f.was;""")
    P.append(f"""-- 4. starred restaurants missing from the catalogue, each with its first award row in its own
--    guide's edition: {'; '.join(f'{y} (announced {a}): {c}' for (y, a), c in sorted(by_year.items()))}.
--    Place ID NULL: no Places API in this pass (QA).
create temp table _new_{cc} (code text, name text, stars smallint, city text, address text, lon float8, lat float8,
                        michelin_url text, website_url text, phone text, property_name text, place_id text,
                        guide_year smallint, announced_on date) on commit drop;
insert into _new_{cc} values
{(','+chr(10)).join(f"    ({q(x['code'])}, {q(x['r']['name'])}, {x['r']['stars']}::smallint, {q(x['town'])}, {q(x['r']['address'])}, {x['r']['lon']}, {x['r']['lat']}, {q(x['r']['michelin_url'])}, {q(x['r']['website'])}, {q(x['r']['phone'])}, {q(prop_new.get(x['code']))}, NULL, {x['r']['guide_year']}, date '{x['r']['announced_on']}')" for x in new)};
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
select 'restaurant', r.id, x.guide_year, 'michelin_stars', x.stars, true, x.announced_on
  from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;""")
    if fills:
        P.append(f"""-- 5. existing restaurants, fill-only (never overwrites)
create temp table _fill_{cc} (code text primary key, phone text, website_url text, michelin_url text, property_name text) on commit drop;
insert into _fill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])}, {q(f['michelin_url'])}, {q(f['property_name'])})" for f in fills)};
update public.restaurants r set phone = f.phone, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set website_url = f.website_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.website_url is not null and r.website_url is null;
update public.restaurants r set michelin_url = f.michelin_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.michelin_url is not null and r.michelin_url is null;
update public.restaurants r set property_name = f.property_name, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.property_name is not null and r.property_name is null
   and not exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);""")
    if clears:
        P.append(f"""-- 5b. existing restaurants whose property_name names a hotel that is in `hotels` and is linked
--     below: the link replaces it (CLAUDE.md hotel scope rule 3). Only the exported value is cleared.
create temp table _clear_{cc} (code text primary key, was text) on commit drop;
insert into _clear_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {q(w)})" for c, w in clears)};
update public.restaurants r set property_name = null, updated_at = now() from _clear_{cc} c
 where r.restaurant_code = c.code and r.property_name = c.was;""")
    if new_links:
        P.append(f"""-- 6. links to hotels in `hotels`
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
    exp_years = collections.Counter(int(r['guide_year']) for r in research if r['michelin_url'] not in used)
    year_checks = ''.join(f"""  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and r.restaurant_code between 'rest_{first_code}' and 'rest_{last_rest}' and ah.guide_year = {y};
  if n <> {c} then raise exception 'expected {c} new restaurants with a current {y} row, found %', n; end if;
""" for y, c in sorted(exp_years.items()))
    P.append(f"""-- post-conditions ({CC}): MICHELIN's live listing and the 2026 Keys
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 3;
  if n <> {cnt[3]} then raise exception 'expected {cnt[3]} three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 2;
  if n <> {cnt[2]} then raise exception 'expected {cnt[2]} two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 1;
  if n <> {cnt[1]} then raise exception 'expected {cnt[1]} one-star, found %', n; end if;
  -- rows that hold or ever held a star (a World's 50 Best row MICHELIN never starred, e.g. Wing, has no star history)
  select count(*) into n from public.restaurants r where r.country_code = '{CC}'
     and (r.michelin_stars is not null or exists (select 1 from public.award_history ah where ah.entity_type = 'restaurant'
          and ah.entity_id = r.id and ah.award_type = 'michelin_stars'))
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '% restaurants without exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '% restaurants disagree with their current award row', n; end if;
{year_checks}  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '% restaurants have both a hotel link and a property_name', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 3;
  if n <> {keycnt[3]} then raise exception 'expected {keycnt[3]} three-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 2;
  if n <> {keycnt[2]} then raise exception 'expected {keycnt[2]} two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 1;
  if n <> {keycnt[1]} then raise exception 'expected {keycnt[1]} one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = '{CC}' and h.michelin_keys is not null
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% Key hotels without exactly one matching current Key row', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.hotels h on h.id = hr.hotel_id where h.country_code = '{CC}';
  if n <> {len(links) + len(new_links)} then raise exception 'expected {len(links) + len(new_links)} {CC} hotel links, found %', n; end if;
end $$;""")
    for row in report:
        row['country'] = CC
    return dict(P=P, report=report, towns=sorted(newtowns), summary=summary, next_code=code, next_hcode=hcode,
                cnt=cnt, keycnt=keycnt, by_year=by_year, first=(first_code, first_hcode), last=(last_rest, last_hotel))


def main():
    export_path, first_code, first_hcode, mig_name = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    X = json.load(open(export_path))
    if isinstance(X, list):
        X = X[0]
    out, code, hcode = {}, first_code, first_hcode
    for CC in COUNTRIES:
        out[CC] = country(CC, X, code, hcode)
        code, hcode = out[CC]['next_code'], out[CC]['next_hcode']
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'detail'])
        w.writeheader()
        for CC in out:
            w.writerows(out[CC]['report'])
    rows = [(CC, t) for CC in out for t in out[CC]['towns']]
    open(os.path.join(MIG_DIR, mig_name), 'w').write(f"""-- MICHELIN Hong Kong & Macau 2026 and Taiwan 2026 (HK, MO, TW): the city
-- prerequisite for the starred restaurants and Key hotels added by
-- supabase/data/enrichment/michelin_hk_mo_tw_2026/prepared_hk_mo_tw_stars_2026.sql.
-- Generated by build_prepared.py from production's export (written
-- 2026-10-30). Filename timestamp is a sequence number only. Names are
-- MICHELIN's own town names (restaurant pages; for hotels, the hotel page's
-- locality, with Hong Kong Island / Kowloon written Hong Kong, Cotai Macau, and
-- Taipei districts Taipei, as the restaurant pages do; Sun Moon Lake and Xinpu
-- are areas, as for GB and Spain). None exists in production's export,
-- compared accent-, case-, space- and hyphen-insensitively. region and
-- postal_municipality left NULL, matching the existing rows. The countries rows
-- for HK, MO and TW already exist. Idempotent: ON CONFLICT targets
-- cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, NULL)" for c, t in rows) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    summ = {CC: out[CC]['summary'] for CC in out}
    head = f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide Hong Kong & Macau 2026 (announced 19 March 2026, Macau) and
-- MICHELIN Guide Taiwan 2026 (announced 21 July 2026), Keys 2026 (18 September
-- 2026): bring every HK, MO and TW restaurant's stars and award_history in line
-- with MICHELIN's live listings, add the starred restaurants and Key hotels
-- missing from the catalogue, link restaurants to hotels in `hotels` where
-- MICHELIN says so, and complete existing rows (fill-only; a property_name that
-- names a hotel now linked is cleared). Generated by build_prepared.py; evidence
-- and every judgement call in match_report.csv and README.md.
--
""" + ''.join(f"-- Summary {CC}: {json.dumps(summ[CC])}\n" for CC in out) + f"""--
-- PREREQUISITE: supabase/migrations/{mig_name}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

"""
    open(os.path.join(HERE, 'prepared_hk_mo_tw_stars_2026.sql'), 'w').write(head + '\n\n'.join('\n\n'.join(out[CC]['P']) for CC in out) + '\n\ncommit;\n')
    for CC in out:
        o = out[CC]
        print(CC, json.dumps(o['summary']))
        print('  towns:', o['towns'], '| report:', dict(collections.Counter(r['kind'] for r in o['report'])))
        print('  expected stars:', dict(o['cnt']), 'keys:', dict(o['keycnt']), 'codes', o['first'], '..', o['last'])


if __name__ == '__main__':
    main()
