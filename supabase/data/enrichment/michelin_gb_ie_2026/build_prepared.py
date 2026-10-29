#!/usr/bin/env python3
"""Build the United Kingdom 2026 prepared SQL from production's export.

Usage:
  python3 build_prepared_gb.py <export.json> <first_rest_code> <first_hotel_code> <migration_name>

  export.json      the JSON cell of export_gb_query.sql (saved as a file)
  first_rest_code  first restaurant code number to use (above production's max
                   AND above every code claimed by unapplied files on any branch)
  first_hotel_code first hotel code number to use (same rule)
  migration_name   e.g. 20261023140000_add_gb_2026_star_and_key_cities.sql

Follows ../michelin_de_it/build_prepared_de_it.py. Reads only committed
research in this folder:
  gb_research_2026.csv                      MICHELIN restaurant pages + phone evidence
  gb_key_hotels_2026.csv                    UK Key hotels: MICHELIN page + website/phone research
  _source/michelin_article_every_star_gbi_2026.txt   MICHELIN's 2026 star article ("Inside the ... Key ...")
Writes, into this folder: match_report.csv, prepared_gb_stars_2026.sql, and
../../../migrations/<migration_name>.

Rules applied (see README.md):
  * existing restaurants are matched to MICHELIN by slug and town segment of
    the MICHELIN path, else same Google Place ID, else coordinates + name --
    never by name alone; existing hotels by MICHELIN's numeric hotel id;
  * the GB launch rows hold 2026 values (each checked against MICHELIN's live
    2026 page), so there is no relabel; a row no longer listed is a loss
    (2026 = NULL);
  * Channel Islands entries in MICHELIN's UK listing are excluded (not UK; no
    GG/JE country row);
  * new restaurants: Place ID left NULL (no Places API in this session);
    phone only when the MICHELIN number is printed on the venue's own site;
  * hotel link when MICHELIN's restaurant page says "Stay at the hotel" for a
    Key hotel (identity by MICHELIN hotel id), or MICHELIN's 2026 star article
    says the restaurant is "Inside the ...-Key <hotel>" and that hotel's
    MICHELIN pin is within 500 m; a non-Key host hotel goes in property_name.
"""
import csv, json, math, os, re, sys, unicodedata, difflib, collections

HERE = os.path.dirname(os.path.abspath(__file__))
MIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), 'migrations')

ANNOUNCED_STARS = '2026-02-09'   # MICHELIN Guide Ceremony GB&I 2026, Dublin
ANNOUNCED_KEYS = '2026-09-18'    # MICHELIN Key launch GB&I 2026
CC = 'GB'


def n(s):
    return re.sub(r'[^a-z0-9 ]', '', unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower())


STOP = {'restaurant', 'hotel', 'by', 'the', 'at', 'and', 'in', 'of', 'a', 'london', 'collection', 'dorchester', 'firmdale', 'hotels'}


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


def article_hosts(text, name):
    """MICHELIN's star article prints 'Name, Town(Inside the X-MICHELIN-Key Hotel)'.
    Return (kind, hotel) for this restaurant's own entry, or None. The entry must be
    the name, a comma, a town, an optional ' – New', then the bracket -- nothing that
    looks like the start of the next entry (a lower-case letter followed directly by
    a capital, as the article runs its entries together)."""
    for m in re.finditer(re.escape(name), text, re.I):
        rest = text[m.end():m.end() + 200]
        mm = re.match(r"(?:,\s*([^()\[\]]{1,40}?))?(\s*–\s*New)?\((Inside|Affiliated with|Across the road from) the ([^)]*)\)", rest)
        if not mm or re.search(r'[a-z][A-Z]', mm.group(1) or ''):
            continue
        rel, host = mm.group(3), mm.group(4)
        k = re.match(r'(One|Two|Three)-MICHELIN-Key (.*)', host)
        if k:
            return rel, 'key', k.group(2).strip()
        s = re.match(r'MICHELIN-Selected (.*)', host)
        if s:
            return rel, 'selected', s.group(1).strip()
    return None


def country(CC, X, first_code, first_hcode):
    cc = CC.lower()
    rest = X.get('restaurants') or []
    cities = X.get('cities') or []
    hotels = X.get('hotels') or []
    links = {(l['hotel_code'], l['restaurant_code']) for l in (X.get('links') or [])}
    linked_restaurants = {l['restaurant_code'] for l in (X.get('links') or [])}
    pid_in_use = set(X.get('place_ids_in_use') or [])
    url_in_use = set(X.get('michelin_urls_in_use') or [])
    hurl_in_use = set(X.get('hotel_michelin_urls_in_use') or [])
    research = list(csv.DictReader(open(os.path.join(HERE, f'{cc}_research_2026.csv'))))
    keyh = list(csv.DictReader(open(os.path.join(HERE, f'{cc}_key_hotels_2026.csv'))))
    art = re.sub(r'\s+', ' ', open(os.path.join(HERE, '_source/michelin_article_every_star_gbi_2026.txt')).read())

    report = []
    newtowns = set()
    # Towns compare accent-, case-, space- and hyphen-insensitively, against
    # production and against towns already chosen in this run (MICHELIN writes
    # "Hampton in Arden" on the restaurant page, "Hampton-in-Arden" on the hotel's).
    tk = lambda t: n(t).replace(' ', '')
    city_names = {tk(c['name']): c['name'] for c in cities if c['country'] == CC}

    def town_of(t):
        t2 = city_names.setdefault(tk(t), t)
        if t2 not in {c['name'] for c in cities if c['country'] == CC}:
            newtowns.add(t2)
        return t2

    excluded = [r for r in research if r['country_override']]
    for r in excluded:
        report.append(dict(country=r['country_override'], code='', name=r['name'], kind='EXCLUDED (Crown Dependency)',
                           detail=f"{r['stars']} star(s), {r['city']} -- in MICHELIN's UK listing but not the UK; production has no {r['country_override']} country row; not added"))
    research = [r for r in research if not r['country_override']]
    for r in research:   # restaurant spellings first: they are MICHELIN's listing names
        town_of(r['city'])

    # ---- hotels: existing matched by MICHELIN id; the rest are new
    ex_h = {hid(h['michelin_url']): h for h in hotels if h['country'] == CC}
    hotel_by_mid = {}          # MICHELIN id -> dict(code, name, lat, lon, keys, new)
    new_hotels, key_changes, key_rows_missing, hotel_fills = [], [], [], []
    hcode = first_hcode
    for k in keyh:
        mid = hid(k['michelin_url'])
        keys = int(k['keys'])
        if mid in ex_h:
            h = ex_h[mid]
            hotel_by_mid[mid] = dict(code=h['code'], name=h['name'], lat=float(k['lat']), lon=float(k['lon']), keys=keys, new=False)
            d = dist(h['lat'], h['lon'], float(k['lat']), float(k['lon']))
            if d > 500:
                report.append(dict(country=CC, code=h['code'], name=h['name'], kind='STORED HOTEL COORDINATES OFF',
                                   detail=f"matched by MICHELIN id {mid}; stored point {d} m from MICHELIN's"))
            if h['keys'] != keys:
                key_changes.append((h['code'], keys, h['keys']))
                report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY CHANGE',
                                   detail=f"{h['keys']} -> {keys} (MICHELIN 2026 Key launch)"))
            key_rows_missing.append(h['code'])  # guarded by NOT EXISTS in SQL
            f = dict(code=h['code'], phone=k['phone'] if not h.get('phone') and k['phone'] else None,
                     website_url=k['website_url'] if not h.get('website_url') and k['website_url'] else None)
            if f['phone'] or f['website_url']:
                hotel_fills.append(f)
        else:
            if k['michelin_url'] in hurl_in_use:
                report.append(dict(country=CC, code='', name=k['name'], kind='HOTEL URL ALREADY IN USE', detail=k['michelin_url'] + ' -- not added'))
                continue
            code = f'hotel_{hcode}'; hcode += 1
            row = dict(code=code, name=k['name'], keys=keys, town=town_of(k['city']), address=k['address'],
                       lat=float(k['lat']), lon=float(k['lon']), michelin_url=k['michelin_url'],
                       website_url=k['website_url'] or None, phone=k['phone'] or None)
            new_hotels.append(row)
            hotel_by_mid[mid] = dict(code=code, name=k['name'], lat=row['lat'], lon=row['lon'], keys=keys, new=True)
    lost_keys = [h for m, h in ex_h.items() if m not in hotel_by_mid]
    for h in lost_keys:
        report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY NOT IN MICHELIN 2026',
                           detail=f"production michelin_keys = {h['keys']}; MICHELIN's page {h['michelin_url']} carries no Key and the 2026 UK & Ireland Key article does not list it -- left untouched, needs a decision (hotel scope rule 1)"))

    # ---- match existing restaurants
    by_slug = collections.defaultdict(list)
    for r in research:
        by_slug[slug(r['michelin_url'])].append(r)
    ex = [r for r in rest if r['country'] == CC]
    matched, used = {}, set()
    pid_index = {r['place_id']: r for r in research if r['place_certainty'] == 'confirmed' and r['place_id']}
    for e in ex:
        m = how = None
        s = slug(e.get('michelin_url'))
        cands = [r for r in by_slug.get(s, []) if path_town(r['michelin_url']) == path_town(e.get('michelin_url'))] if s else []
        if len(cands) == 1 and cands[0]['michelin_url'] not in used:
            m, how = cands[0], 'michelin slug'
            d = dist(e['lat'], e['lon'], float(m['lat']), float(m['lon']))
            if d > 500:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED COORDINATES OFF',
                                   detail=f"matched by MICHELIN slug; stored point is {d} m from MICHELIN's"))
        if not m and e.get('google_place_id') in pid_index and pid_index[e['google_place_id']]['michelin_url'] not in used:
            m, how = pid_index[e['google_place_id']], 'same Google Place ID'
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
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='matched by ' + how,
                               detail=f"MICHELIN '{m['name']}' {m['michelin_url']}; stored point {d} m from MICHELIN's; stored url {e.get('michelin_url')}"))

    changes, losses, corrections = [], [], []
    for e in ex:
        cur = [h for h in (e.get('history') or []) if h['current']]
        if len(cur) != 1:
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='NO SINGLE CURRENT ROW', detail='left untouched -- check by hand'))
            continue
        cur = cur[0]
        m = matched.get(e['code'])
        if m:
            s26 = int(m['stars'])
            if cur['year'] == 2026 and cur['value'] != s26:
                corrections.append((e['code'], s26, cur['value']))
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED', detail=f"2026 row holds {cur['value']}, MICHELIN 2026 gives {s26}"))
            elif cur['year'] != 2026 and cur['value'] != s26:
                changes.append((e['code'], s26, cur['value']))
            else:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='2026 ROW VERIFIED',
                                   detail=f"launch row {cur['year']} = {cur['value']} agrees with MICHELIN's live 2026 page; left as is (announced_on stays NULL)"))
        elif cur['value'] is not None:
            losses.append(e['code'])
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LOSS (not in MICHELIN 2026 listing)', detail=f"{cur['value']} star(s) -> 2026 NULL"))

    # ---- hotel for a restaurant
    def host_for(r, code):
        """-> ('link', hotel, confidence, evidence) | ('property', name, None, evidence) | (None,...)"""
        sid = hid(r['stay_hotel_url']) if r['stay_hotel_url'] else None
        if sid and sid in hotel_by_mid:
            h = hotel_by_mid[sid]
            d = dist(float(r['lat']), float(r['lon']), h['lat'], h['lon'])
            return ('link', h, 'exact' if d <= 100 else 'campus',
                    f"MICHELIN restaurant page 'Stay at the hotel' -> {r['stay_hotel_url']} ({r['stay_hotel_name']}), a {h['keys']}-Key hotel; restaurant pin {d} m from the hotel's MICHELIN pin. 2026-10-29.")
        a = article_hosts(art, r['name'])
        if a and a[0] == 'Inside' and a[1] == 'key':
            cands = sorted(((dist(float(r['lat']), float(r['lon']), h['lat'], h['lon']), sim(a[2], h['name']), h) for h in hotel_by_mid.values()), key=lambda t: t[0])
            ok = [(d, s, h) for d, s, h in cands if d <= 500 and s >= 0.6]
            if len(ok) == 1:
                d, s, h = ok[0]
                return ('link', h, 'exact' if d <= 100 else 'campus',
                        f"MICHELIN 'Every MICHELIN-Star Restaurant in Great Britain & Ireland 2026': '(Inside the ...-MICHELIN-Key {a[2]})'; the hotel row's pin (gb/ie_key_hotels_2026.csv) {d} m from the restaurant's. 2026-10-29.")
            report.append(dict(country=CC, code=code, name=r['name'], kind='ARTICLE HOST NOT LINKED',
                               detail=f"article says inside Key hotel '{a[2]}', but {len(ok)} Key hotel(s) within 500 m with a matching name (nearest: {cands[0][2]['name']} {cands[0][0]} m) -- no link, no property_name"))
            return (None, None, None, None)
        if sid:  # stay link to a MICHELIN-selected (non-Key) hotel
            return ('property', r['stay_hotel_name'], None, 'MICHELIN restaurant page "Stay at the hotel" (no Key)')
        if a and a[0] == 'Inside' and a[1] == 'selected':
            return ('property', a[2], None, 'MICHELIN 2026 star article "Inside the MICHELIN-Selected ..."')
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
        new.append(dict(code=f'rest_{code}', r=r, town=town_of(r['city']))); code += 1

    new_links, prop_new = [], {}
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
        f['property_name'] = None
        kind, h, conf, ev = host_for(m, e['code'])
        if kind == 'link' and (h['code'], e['code']) not in links:
            new_links.append((h['code'], e['code'], conf, ev))
        elif kind == 'property' and not e.get('property_name') and e['code'] not in linked_restaurants:
            f['property_name'] = h
        if e.get('phone') and m['michelin_phone'] and re.sub(r'\D', '', e['phone']) != re.sub(r'\D', '', m['michelin_phone']):
            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED PHONE DIFFERS', detail=f"stored {e['phone']} vs MICHELIN {m['michelin_phone']} -- stored kept"))
        if any(f[k] for k in ('phone', 'website_url', 'property_name')):
            fills.append(f)
    for x in new:
        r = x['r']
        if not r['phone'] and r['michelin_phone']:
            report.append(dict(country=CC, code=x['code'], name=r['name'], kind='PHONE HELD BACK', detail=f"MICHELIN {r['michelin_phone']}: {r['phone_source']}"))
        if x['code'] in prop_new:
            report.append(dict(country=CC, code=x['code'], name=r['name'], kind='property_name', detail=prop_new[x['code']]))
    for hc, rc, conf, ev in new_links:
        report.append(dict(country=CC, code=rc, name=next((x['r']['name'] for x in new if x['code'] == rc), rc), kind=f'HOTEL LINK ({conf})', detail=f'{hc}: {ev}'))
    for h in new_hotels:
        if not h['phone'] or not h['website_url']:
            report.append(dict(country=CC, code=h['code'], name=h['name'], kind='HOTEL CONTACT MISSING',
                               detail=('no website; ' if not h['website_url'] else '') + ('no phone' if not h['phone'] else '') + ' -- see gb_key_hotels_2026.csv'))

    cnt = collections.Counter(int(r['stars']) for r in research)
    keycnt = collections.Counter(h['keys'] for h in hotel_by_mid.values())
    summary = dict(existing=len(ex), matched=len(matched), changes=len(changes), losses=len(losses), corrections=len(corrections),
                   new=len(new), new_phones=sum(1 for x in new if x['r']['phone']), new_place_ids=0, property_names=len(prop_new),
                   links=len(new_links), fills=len(fills), excluded_crown_dependencies=len(excluded),
                   new_hotels=len(new_hotels), new_hotel_phones=sum(1 for h in new_hotels if h['phone']),
                   new_hotel_websites=sum(1 for h in new_hotels if h['website_url']), key_changes=len(key_changes),
                   hotel_fills=len(hotel_fills), keys_not_in_2026=len(lost_keys))
    last_rest, last_hotel = code - 1, hcode - 1

    # ---- SQL
    P = [f"\n-- ============================================================\n-- {CC}\n-- ============================================================"]
    P.append(f"""do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}';
  if n <> {len(ex)} then raise exception '{CC}: expected {len(ex)} restaurants (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(e['code'])}, {q(e['name'])})" for e in ex)}) e(code, name)
   where not exists (select 1 from public.restaurants r where r.restaurant_code = e.code and r.name = e.name and r.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported restaurant codes no longer carry their exported name', n; end if;
""" if ex else '') + f"""  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len([h for h in hotels if h['country'] == CC])} then raise exception '{CC}: expected {len([h for h in hotels if h['country'] == CC])} hotels (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(h['code'])}, {q(h['name'])})" for h in hotels if h['country'] == CC)}) e(code, name)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported hotel codes no longer carry their exported name', n; end if;
""" if ex_h else '') + f"""  if exists (select 1 from public.restaurants where restaurant_code ~ '^rest_[0-9]+$'
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

    if new_hotels:
        P.append(f"""-- 1. MICHELIN Key hotels missing from `hotels` (each with its current 2026 Key row)
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
        P.append(f"""-- 1b. Key changes on existing hotels
create temp table _kchg_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kchg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {w})" for c, k, w in key_changes)};
update public.award_history a set is_current = false from public.hotels h, _kchg_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys' and a.is_current;
update public.hotels h set michelin_keys = k.keys, updated_at = now() from _kchg_{cc} k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
    P.append(f"""-- 1c. current 2026 Key row for every UK Key hotel that lacks one (new rows above, and existing
--     GB hotels the August World's 50 Best import left without one; PE_REPORT.md finding 1)
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED_KEYS}'
  from public.hotels h
 where h.hotel_code = any(array[{', '.join(q(h['code']) for h in hotel_by_mid.values())}])
   and not exists (select 1 from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
                    and a.award_type = 'michelin_keys' and a.is_current);""")
    if hotel_fills:
        P.append(f"""-- 1d. existing GB hotels, fill-only (never overwrites)
create temp table _hfill_{cc} (code text primary key, phone text, website_url text) on commit drop;
insert into _hfill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])})" for f in hotel_fills)};
update public.hotels h set phone = f.phone, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.phone is not null and h.phone is null;
update public.hotels h set website_url = f.website_url, updated_at = now() from _hfill_{cc} f where h.hotel_code = f.code and f.website_url is not null and h.website_url is null;""")
    if changes or losses:
        rows = [(c, s) for c, s, _ in changes] + [(c, None) for c in losses]
        P.append(f"""-- 2. 2026 changes and losses: close the current row, open 2026
create temp table _chg_{cc} (code text primary key, stars smallint) on commit drop;
insert into _chg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {'NULL' if s is None else s})" for c, s in rows)};
update public.award_history ah set is_current = false
  from public.restaurants r, _chg_{cc} c
 where r.id = ah.entity_id and r.restaurant_code = c.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.is_current;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', c.stars, true, date '{ANNOUNCED_STARS}'
  from public.restaurants r join _chg_{cc} c on c.code = r.restaurant_code;
update public.restaurants r set michelin_stars = c.stars, updated_at = now()
  from _chg_{cc} c where r.restaurant_code = c.code;""")
    if corrections:
        P.append(f"""-- 3. import errors corrected in place
create temp table _fix_{cc} (code text primary key, stars smallint, was smallint) on commit drop;
insert into _fix_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {s}, {w})" for c, s, w in corrections)};
update public.award_history ah set award_value = f.stars
  from public.restaurants r, _fix_{cc} f
 where r.id = ah.entity_id and r.restaurant_code = f.code and ah.entity_type = 'restaurant'
   and ah.award_type = 'michelin_stars' and ah.guide_year = 2026 and ah.is_current and ah.award_value = f.was;
update public.restaurants r set michelin_stars = f.stars, updated_at = now()
  from _fix_{cc} f where r.restaurant_code = f.code and r.michelin_stars = f.was;""")
    if new:
        P.append(f"""-- 4. starred restaurants missing from the catalogue (Place ID NULL: no Places API in this pass)
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
select 'restaurant', r.id, 2026, 'michelin_stars', x.stars, true, date '{ANNOUNCED_STARS}'
  from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;""")
    if fills:
        P.append(f"""-- 5. existing restaurants, fill-only (never overwrites)
create temp table _fill_{cc} (code text primary key, phone text, website_url text, property_name text) on commit drop;
insert into _fill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])}, {q(f['property_name'])})" for f in fills)};
update public.restaurants r set phone = f.phone, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set website_url = f.website_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.website_url is not null and r.website_url is null;
update public.restaurants r set property_name = f.property_name, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.property_name is not null and r.property_name is null
   and not exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);""")
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
    lost_codes = [h['code'] for h in lost_keys]
    P.append(f"""-- post-conditions: MICHELIN's live 2026 UK listing (Channel Islands excluded) and the 2026 UK Keys
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 3;
  if n <> {cnt[3]} then raise exception 'expected {cnt[3]} three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 2;
  if n <> {cnt[2]} then raise exception 'expected {cnt[2]} two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 1;
  if n <> {cnt[1]} then raise exception 'expected {cnt[1]} one-star, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}'
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '% restaurants without exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '% restaurants disagree with their current award row', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '% restaurants have both a hotel link and a property_name', n; end if;
  -- Keys: the {len(hotel_by_mid)} UK Key hotels, plus the {len(lost_codes)} hotel(s) still holding a Key MICHELIN no longer shows (left for a decision)
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 3{f" and hotel_code <> all(array[{', '.join(q(c) for c in lost_codes)}])" if lost_codes else ''};
  if n <> {keycnt[3]} then raise exception 'expected {keycnt[3]} three-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 2{f" and hotel_code <> all(array[{', '.join(q(c) for c in lost_codes)}])" if lost_codes else ''};
  if n <> {keycnt[2]} then raise exception 'expected {keycnt[2]} two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 1{f" and hotel_code <> all(array[{', '.join(q(c) for c in lost_codes)}])" if lost_codes else ''};
  if n <> {keycnt[1]} then raise exception 'expected {keycnt[1]} one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = '{CC}' and h.michelin_keys is not null{f" and h.hotel_code <> all(array[{', '.join(q(c) for c in lost_codes)}])" if lost_codes else ''}
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% Key hotels without exactly one matching current Key row', n; end if;
end $$;""")

    optional = '' if not lost_keys else '\n\n-- ============================================================\n-- OPTIONAL -- commented out; needs an explicit decision\n-- ============================================================\n' + '\n'.join(
        f"""-- {h['code']} {h['name']}: production holds michelin_keys = {h['keys']}, but MICHELIN's own page
-- ({h['michelin_url']}) carries no Key and the 2026 UK & Ireland Key article
-- (18 Sep 2026) does not list it. Hotel scope rule 1 (CLAUDE.md) keeps only Key and
-- World's 50 Best hotels in `hotels`; removing the row is a destructive change and
-- is NOT prepared. The minimum, if confirmed, is to record the loss:
--
-- update public.hotels set michelin_keys = NULL, updated_at = now()
--  where hotel_code = '{h['code']}' and name = {q(h['name'])} and country_code = '{CC}' and michelin_keys = {h['keys']};
-- insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
-- select 'hotel', id, 2026, 'michelin_keys', NULL, true, date '{ANNOUNCED_KEYS}' from public.hotels
--  where hotel_code = '{h['code']}' and not exists (select 1 from public.award_history a where a.entity_id = hotels.id
--        and a.award_type = 'michelin_keys' and a.is_current);""" for h in lost_keys) + '\n'
    return dict(P=P, report=report, towns=sorted(newtowns), summary=summary, cnt=cnt, keycnt=keycnt,
                next_code=code, next_hcode=hcode, optional=optional)


def main():
    export_path, first_code, first_hcode, mig_name = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    X = json.load(open(export_path))
    if isinstance(X, list):
        X = X[0]
    countries = [c for c in X.get('countries_present') or [] if c['country_code'] == 'IE']
    out, code, hcode = {}, first_code, first_hcode
    for CC in ('GB', 'IE'):
        out[CC] = country(CC, X, code, hcode)
        code, hcode = out[CC]['next_code'], out[CC]['next_hcode']
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'detail'])
        w.writeheader()
        for CC in out:
            w.writerows(out[CC]['report'])
    rows = [(CC, t) for CC in out for t in out[CC]['towns']]
    ie_country = "" if countries else """
-- Ireland: production has no `countries` row for IE (read-only check
-- 2026-10-29), and every IE city, restaurant and hotel below references one.
-- Ireland is in scope by the product owner's decision of 2026-10-29. As in
-- 20261016120000_add_worlds_50_best_countries_and_cities.sql (EC, PA, VN), the
-- country comes first; since 20261018120000_add_country_timezones.sql,
-- `timezones` is NOT NULL with at least one zone, so it carries IE's zone from
-- the IANA database (tzdata 2025b zone.tab: "IE  +5320-00615  Europe/Dublin",
-- read on this machine 2026-10-29; present in production's pg_timezone_names).
insert into public.countries (country_code, name, flag_emoji, timezones)
values ('IE', 'Ireland', '\U0001F1EE\U0001F1EA', array['Europe/Dublin'])
on conflict (country_code) do nothing;
"""
    open(os.path.join(MIG_DIR, mig_name), 'w').write(f"""-- MICHELIN Great Britain & Ireland 2026 (United Kingdom and Ireland): the
-- country and city prerequisite for the starred restaurants and Key hotels
-- added by supabase/data/enrichment/michelin_gb_ie_2026/prepared_gb_ie_stars_2026.sql.
-- Generated by build_prepared_gb.py from production's export (written
-- 2026-10-29). Filename timestamp is a sequence number only. Names are
-- MICHELIN's own town names (restaurant pages; for hotels, the hotel page's
-- locality, which is sometimes an area such as "The Lake District", as for
-- Spain's island rows). None exists in production's export, compared accent-,
-- case-, space- and hyphen-insensitively. region and postal_municipality left
-- NULL, matching the existing rows. Idempotent: ON CONFLICT targets
-- countries_pkey and cities_unique_key.

begin;
{ie_country}
insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, NULL)" for c, t in rows) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    summ = {CC: out[CC]['summary'] for CC in out}
    head = f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide Great Britain & Ireland 2026, United Kingdom (GB) and
-- Ireland (IE) (stars announced 9 February 2026, Dublin; Keys announced
-- 18 September 2026): bring every GB and IE restaurant's stars and
-- award_history in line with MICHELIN's live 2026 listings, add the starred
-- restaurants and Key hotels missing from the catalogue, link restaurants to
-- Key hotels where MICHELIN says so, and complete existing rows (fill-only).
-- Generated by build_prepared_gb.py; evidence and every judgement call in
-- match_report.csv and README.md.
--
-- Summary GB: {json.dumps(summ['GB'])}
-- Summary IE: {json.dumps(summ['IE'])}
--
-- PREREQUISITE: supabase/migrations/{mig_name}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;
"""
    open(os.path.join(HERE, 'prepared_gb_ie_stars_2026.sql'), 'w').write(
        head + '\n'.join('\n\n'.join(out[CC]['P']) for CC in out) + '\n\ncommit;\n' + ''.join(out[CC]['optional'] for CC in out))
    for CC in out:
        print(CC, json.dumps(out[CC]['summary']))
        print('  towns:', len(out[CC]['towns']), '| report:', collections.Counter(r['kind'] for r in out[CC]['report']))
        print('  expected stars:', dict(out[CC]['cnt']), 'keys:', dict(out[CC]['keycnt']))
    print('codes rest', first_code, '..', code - 1, 'hotel', first_hcode, '..', hcode - 1)


if __name__ == '__main__':
    main()
