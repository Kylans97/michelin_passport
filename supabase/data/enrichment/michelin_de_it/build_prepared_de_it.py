#!/usr/bin/env python3
"""Build the Germany + Italy 2026 prepared SQL from production's export.

Usage:
  python3 build_prepared_de_it.py <export.json> <first_free_code> <migration_name> <qa_first_id>

  export.json      the JSON cell of export_de_it_query.sql (saved as a file)
  first_free_code  first restaurant code number to use (above production's max
                   AND above every code already claimed by unapplied files)
  migration_name   e.g. 20261023130000_add_de_it_2026_star_cities.sql
  qa_first_id      e.g. 252 (QA ids are only referenced in comments/report)

Reads only committed research (this folder and ../michelin_{de,it}_stars/).
Writes, into this folder: match_report.csv, prepared_de_it_stars_2026.sql,
and ../../../migrations/<migration_name>.

Rules applied (see README.md):
  * existing rows are matched to MICHELIN by the MICHELIN slug (within 2 km),
    else by coordinates (<= 200 m) plus a name check -- never by name alone;
  * Germany: launch rows labelled 2026 are verified against MICHELIN's 2025
    list and relabelled 2025 (values unchanged); 2026 changes are written as
    new rows; rows no longer listed become losses (2026 = NULL);
  * Italy: launch rows hold 2026 values; a 2026 row whose value MICHELIN's
    2026 list contradicts is an import error and is corrected in place;
    rows in MICHELIN's 2026 article but offline now are KEPT (Belgian
    precedent) and reported;
  * new restaurants: confirmed Place ID / phone only; hotel link when
    MICHELIN's 'Stay at the hotel' page lies within 150 m of a hotels row
    with a matching name, else property_name.
"""
import csv, json, math, os, re, sys, unicodedata, difflib, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ENR = os.path.dirname(HERE)
MIG_DIR = os.path.join(os.path.dirname(os.path.dirname(ENR)), 'migrations')

ANNOUNCED = {'DE': '2026-06-23', 'IT': '2025-11-19'}
CCL = {'DE': 'de', 'IT': 'it'}


def n(s):
    return re.sub(r'[^a-z0-9 ]', '', unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower())


STOP = {'restaurant', 'ristorante', 'restaurante', 'gasthaus', 'gasthof', 'landhaus', 'hotel', 'by', 'the',
        'il', 'la', 'lo', 'le', 'i', 'di', 'da', 'del', 'della', 'al', 'alla', 'e', 'and', 'in', 'zum', 'zur', 'der', 'die', 'das', 'im', 'am', 'and'}


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


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


def main():
    export_path, first_code, mig_name, qa_first = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4])
    X = json.load(open(export_path))
    if isinstance(X, list):
        X = X[0]
    rest = X.get('restaurants') or []
    cities = X.get('cities') or []
    hotels = X.get('hotels') or []
    links = {(l['hotel_code'], l['restaurant_code']) for l in (X.get('links') or [])}
    linked_restaurants = {l['restaurant_code'] for l in (X.get('links') or [])}
    pid_in_use = set(X.get('place_ids_in_use') or [])
    url_in_use = set(X.get('michelin_urls_in_use') or [])
    stay = json.load(open(os.path.join(HERE, 'michelin_hotel_pages_20261029.json')))
    de2025 = json.load(open(os.path.join(ENR, 'michelin_de_stars/_source/michelin_full_list_2025_parsed.json')))
    it2026 = json.load(open(os.path.join(ENR, 'michelin_it_stars/_source/michelin_full_list_2026_parsed.json')))

    report = []
    sql_parts = []
    newtowns = set()
    code = first_code
    summary = {}
    expected = {}

    for CC in ('DE', 'IT'):
        cc = CCL[CC]
        research = list(csv.DictReader(open(os.path.join(ENR, f'michelin_{cc}_stars/{cc}_research_2026.csv'))))
        by_slug = collections.defaultdict(list)
        for r in research:
            by_slug[slug(r['michelin_url'])].append(r)
        ex = [r for r in rest if r['country'] == CC]
        city_names = {n(c['name']): c['name'] for c in cities if c['country'] == CC}
        hot = [h for h in hotels if h['country'] == CC]

        # ---- match existing rows to MICHELIN's live list
        matched = {}      # code -> research row
        used = set()
        def path_town(u):
            m_ = re.search(r'/([^/]+)/restaurant/', u or '')
            return m_.group(1).lower() if m_ else None
        pid_index = {r['place_id']: r for r in research if r['place_certainty'] == 'confirmed' and r['place_id']}
        for e in ex:
            m = None; how = None
            s = slug(e.get('michelin_url'))
            # (a) MICHELIN slug + same town segment of the MICHELIN path
            cands = [r for r in by_slug.get(s, []) if path_town(r['michelin_url']) == path_town(e.get('michelin_url'))] if s else []
            if len(cands) == 1 and cands[0]['michelin_url'] not in used:
                m, how = cands[0], 'michelin slug'
                d = dist(e['lat'], e['lon'], float(m['lat']), float(m['lon']))
                if d > 500:
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED COORDINATES OFF',
                                       detail=f"matched by MICHELIN slug; stored point is {d} m from MICHELIN's ({m['lat']}, {m['lon']})"))
            # (b) same Google record
            if not m and e.get('google_place_id') in pid_index and pid_index[e['google_place_id']]['michelin_url'] not in used:
                m, how = pid_index[e['google_place_id']], 'same Google Place ID'
            # (c) coordinates + name
            if not m:
                near = sorted(((dist(e['lat'], e['lon'], float(r['lat']), float(r['lon'])), sim(e['name'], r['name']), r) for r in research
                               if r['michelin_url'] not in used), key=lambda t: t[0])
                ok = [(d, sm, r) for d, sm, r in near if (d <= 200 and sm >= 0.6) or (d <= 1000 and sm >= 0.9)]
                if len(ok) == 1 or (len(ok) > 1 and ok[0][1] >= 0.9 and ok[1][1] < 0.9):
                    m, how = ok[0][2], f'coordinates {ok[0][0]} m + name'
                elif len(ok) > 1:
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='AMBIGUOUS MATCH',
                                       detail='; '.join(f"{r['name']} {d} m" for d, sm, r in ok[:3]) + ' -- left unmatched, check by hand'))
            if m:
                matched[e['code']] = m; used.add(m['michelin_url'])
                if how != 'michelin slug':
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='matched by ' + how.split(' ')[0] + (' ' + how.split(' ')[1] if how.startswith('same') else ''),
                                       detail=f"{how}: MICHELIN '{m['name']}' {m['michelin_url']}"))

        def current(e):
            cur = [h for h in (e.get('history') or []) if h['current']]
            return cur[0] if len(cur) == 1 else None

        relabel, changes, losses, corrections, kept = [], [], [], [], []
        for e in ex:
            cur = current(e)
            m = matched.get(e['code'])
            if cur is None:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='NO SINGLE CURRENT ROW', detail='left untouched -- check by hand'))
                continue
            if CC == 'DE':
                # MICHELIN's 2025 list prints German town names (München), production
                # English ones (Munich): match on the name, use the town only to break ties.
                exact = [a for a in de2025 if n(a['name']).replace(' ', '') == n(e['name']).replace(' ', '')]
                v25 = exact if len(exact) == 1 else [a for a in de2025 if sim(a['name'], e['name']) >= 0.8]
                if len(v25) > 1:
                    v25 = [a for a in v25 if n(a['city'])[:4] in (n(e['city'])[:4], n(m['city'])[:4] if m else '')] or v25
                launch = cur['year'] == 2026 and not cur.get('announced_on')
                has2025 = any(h['year'] == 2025 for h in (e.get('history') or []))
                if launch and has2025:
                    # A later history pass already recorded the 2025 edition for this
                    # restaurant; relabelling would collide with that row. The launch row
                    # then stands as the 2026 value (true when MICHELIN 2026 agrees).
                    report.append(dict(country=CC, code=e['code'], name=e['name'], kind='2025 ROW ALREADY PRESENT',
                                       detail=f"history pass recorded 2025 = {[h['value'] for h in e['history'] if h['year'] == 2025][0]}; launch 2026 row ({cur['value']}) kept as the 2026 value, not relabelled"))
                    base = cur['value']
                elif launch:
                    if len(v25) == 1 and v25[0]['tier'] == cur['value']:
                        relabel.append(e['code'])
                        base = cur['value']
                    else:
                        report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LAUNCH ROW NOT VERIFIED IN 2025 LIST',
                                           detail=f"2026-labelled value {cur['value']}; 2025 list: {[(a['name'], a['tier']) for a in v25]} -- not relabelled, left untouched"))
                        continue
                else:
                    base = cur['value']
                if m:
                    s26 = int(m['stars'])
                    if s26 != base:
                        if e['code'] in relabel or cur['year'] != 2026:
                            changes.append((e['code'], s26, base))
                        else:  # current row already labelled 2026 and not relabelled: correct it in place
                            corrections.append((e['code'], s26, base))
                            report.append(dict(country=CC, code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED',
                                               detail=f"2026 row holds {base}, MICHELIN 2026 gives {s26}"))
                else:
                    if base is not None:
                        losses.append(e['code'])
                        report.append(dict(country=CC, code=e['code'], name=e['name'], kind='LOSS (not in MICHELIN 2026 listing)',
                                           detail=f"{base} star(s) in 2025; absent from the live 2026 listing -- MICHELIN's 2026 total is 339 vs 338 live, so one absentee may be a mid-year removal rather than a lost star: confirm"))
            else:  # IT
                if m:
                    s26 = int(m['stars'])
                    if cur['year'] == 2026 and cur['value'] != s26:
                        corrections.append((e['code'], s26, cur['value']))
                        report.append(dict(country=CC, code=e['code'], name=e['name'], kind='IMPORT ERROR CORRECTED',
                                           detail=f"2026 row holds {cur['value']}, MICHELIN 2026 gives {s26}"))
                    elif cur['year'] != 2026 and cur['value'] != s26:
                        changes.append((e['code'], s26, cur['value']))
                else:
                    in_art = [a for a in it2026 if sim(a['name'], e['name']) >= 0.8]
                    if in_art:
                        kept.append((e['code'], e['stars']))
                        report.append(dict(country=CC, code=e['code'], name=e['name'], kind='KEPT (in 2026 article, offline now)',
                                           detail=f"article: {[(a['city'], a['name'], a['tier']) for a in in_art]} -- stars kept, as for Belgium (QA-220); confirm"))
                    else:
                        report.append(dict(country=CC, code=e['code'], name=e['name'], kind='NOT IN MICHELIN 2026',
                                           detail='neither live nor in the 2026 article -- left untouched, check by hand'))

        # ---- new restaurants
        new = []
        for r in sorted(research, key=lambda r: n(r['name'])):
            if r['michelin_url'] in used:
                continue
            if r['michelin_url'] in url_in_use:
                report.append(dict(country=CC, code='', name=r['name'], kind='URL ALREADY IN USE ELSEWHERE', detail=r['michelin_url'] + ' -- not added'))
                continue
            town = city_names.get(n(r['city']), r['city'])
            if town not in city_names.values():
                newtowns.add((CC, town))
            pid = r['place_id'] if r['place_certainty'] == 'confirmed' and r['place_id'] not in pid_in_use else None
            if r['place_certainty'] == 'confirmed' and r['place_id'] in pid_in_use:
                report.append(dict(country=CC, code='', name=r['name'], kind='PLACE ID IN USE', detail=r['place_id'] + ' held by another restaurant -- left null'))
            new.append(dict(code=f'rest_{code}', r=r, town=town, place_id=pid)); code += 1

        # ---- hotel links / property names (new + existing)
        def hotel_for(r):
            if not r.get('stay_hotel_url'):
                return None, None
            key = r['stay_hotel_url'].replace('https://guide.michelin.com', '')
            h = stay.get(key)
            if not h or not h.get('lat'):
                return None, None
            near = sorted(((dist(float(h['lat']), float(h['lon']), x['lat'], x['lon']), x) for x in hot), key=lambda t: t[0])
            if near and near[0][0] <= 150 and sim(h['h1'], near[0][1]['name']) >= 0.5:
                return near[0][1], h
            if near and near[0][0] <= 150:
                report.append(dict(country=CC, code='', name=r['name'], kind='HOTEL NEAR BUT NAME DIFFERS',
                                   detail=f"MICHELIN hotel '{h['h1']}' vs our {near[0][1]['code']} '{near[0][1]['name']}' {near[0][0]} m -- no link, no property_name"))
                return 'ambiguous', h
            return None, h

        new_links, prop_new = [], {}
        for nr in new:
            hrow, h = hotel_for(nr['r'])
            if hrow == 'ambiguous':
                continue
            if hrow:
                d = dist(float(nr['r']['lat']), float(nr['r']['lon']), hrow['lat'], hrow['lon'])
                new_links.append((hrow['code'], nr['code'], 'exact' if d <= 100 else 'campus',
                                  f"MICHELIN restaurant page 'Stay at the hotel' -> {nr['r']['stay_hotel_url']} ({h['h1']}); that page's pin within 150 m of {hrow['code']}; restaurant pin {d} m from it. 2026-10-29."))
            elif h:
                prop_new[nr['code']] = h['h1']
        fills = []
        for e in ex:
            m = matched.get(e['code'])
            if not m:
                continue
            f = dict(code=e['code'], name=e['name'])
            f['michelin_url'] = m['michelin_url'] if not e.get('michelin_url') and m['michelin_url'] not in url_in_use else None
            f['phone'] = m['phone'] if not e.get('phone') and m['phone'] else None
            f['website_url'] = m['website'] if not e.get('website_url') and m['website'] else None
            f['place_id'] = m['place_id'] if (not e.get('google_place_id') and m['place_certainty'] == 'confirmed' and m['place_id'] not in pid_in_use) else None
            if e.get('google_place_id') and m['place_certainty'] == 'confirmed' and m['place_id'] and e['google_place_id'] != m['place_id']:
                report.append(dict(country=CC, code=e['code'], name=e['name'], kind='STORED PLACE ID DIFFERS',
                                   detail=f"stored {e['google_place_id']} vs research {m['place_id']} ({m['google_name']}) -- stored kept, check by hand"))
            hrow, h = hotel_for(m)
            f['property_name'] = None
            if hrow and hrow != 'ambiguous':
                if (hrow['code'], e['code']) not in links:
                    d = dist(e['lat'], e['lon'], hrow['lat'], hrow['lon'])
                    new_links.append((hrow['code'], e['code'], 'exact' if d <= 100 else 'campus',
                                      f"MICHELIN restaurant page 'Stay at the hotel' -> {m['stay_hotel_url']} ({h['h1']}); that page's pin within 150 m of {hrow['code']}; restaurant pin {d} m from it. 2026-10-29."))
            elif h and hrow is None and not e.get('property_name') and e['code'] not in linked_restaurants:
                f['property_name'] = h['h1']
            if any(f[k] for k in ('michelin_url', 'phone', 'website_url', 'place_id', 'property_name')):
                fills.append(f)

        # ---- expected post-condition counts
        cnt = collections.Counter(int(r['stars']) for r in research if r['michelin_url'] in used or any(x['r'] is r for x in new))
        for c, s in kept:
            if s:
                cnt[int(s)] += 1
        expected[CC] = cnt
        summary[CC] = dict(existing=len(ex), matched=len(matched), relabel=len(relabel), changes=len(changes), losses=len(losses),
                           corrections=len(corrections), kept=len(kept), new=len(new), new_place_ids=sum(1 for x in new if x['place_id']),
                           new_phones=sum(1 for x in new if x['r']['phone']), links=len(new_links), fills=len(fills))

        # ---- SQL for this country
        A = ANNOUNCED[CC]
        P = []
        P.append(f"\n-- ============================================================\n-- {CC}\n-- ============================================================")
        P.append(f"""do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}';
  if n <> {len(ex)} then raise exception '{CC}: expected {len(ex)} restaurants (export), found % -- production changed, re-check', n; end if;
""" + (f"""  select count(*) into n from (values {', '.join(f"({q(e['code'])}, {q(e['name'])})" for e in ex)}) e(code, name)
   where not exists (select 1 from public.restaurants r where r.restaurant_code = e.code and r.name = e.name and r.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported codes no longer carry their exported name', n; end if;
""" if ex else '') + "end $$;")
        if relabel:
            P.append(f"""-- {CC} 1. relabel verified launch rows 2026 -> 2025 (values unchanged; each checked against MICHELIN's 2025 list)
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
        if changes or losses:
            rows = [(c, s) for c, s, _ in changes] + [(c, None) for c in losses]
            P.append(f"""-- {CC} 2. 2026 changes (promotions/demotions) and losses: close the current row, open 2026
create temp table _chg_{cc} (code text primary key, stars smallint) on commit drop;
insert into _chg_{cc} values
{(','+chr(10)).join(f"    ({q(c)}, {'NULL' if s is None else s})" for c, s in rows)};
update public.award_history ah set is_current = false
  from public.restaurants r, _chg_{cc} c
 where r.id = ah.entity_id and r.restaurant_code = c.code
   and ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars' and ah.is_current;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', c.stars, true, date '{A}'
  from public.restaurants r join _chg_{cc} c on c.code = r.restaurant_code;
update public.restaurants r set michelin_stars = c.stars, updated_at = now()
  from _chg_{cc} c where r.restaurant_code = c.code;""")
        if corrections:
            P.append(f"""-- {CC} 3. import errors: a 2026 row whose value MICHELIN's 2026 list contradicts
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
            P.append(f"""-- {CC} 4. starred restaurants missing from the catalogue
create temp table _new_{cc} (code text, name text, stars smallint, city text, address text, lon float8, lat float8,
                         michelin_url text, website_url text, phone text, property_name text, place_id text) on commit drop;
insert into _new_{cc} values
{(','+chr(10)).join(f"    ({q(x['code'])}, {q(x['r']['name'])}, {x['r']['stars']}::smallint, {q(x['town'])}, {q(x['r']['address'])}, {x['r']['lon']}, {x['r']['lat']}, {q(x['r']['michelin_url'])}, {q(x['r']['website'])}, {q(x['r']['phone'])}, {q(prop_new.get(x['code']))}, {q(x['place_id'])})" for x in new)};
do $$
declare bad text;
begin
  select string_agg(x.code, ', ') into bad from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;
  if bad is not null then raise exception '{CC}: codes no longer free: %', bad; end if;
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_{cc} x
   where (select count(*) from public.cities c where c.country_code = '{CC}' and c.name = x.city) <> 1;
  if bad is not null then raise exception '{CC}: city does not resolve to exactly one row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_{cc} x join public.restaurants r on r.michelin_url = x.michelin_url;
  if bad is not null then raise exception '{CC}: already present (michelin_url): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_{cc} x join public.restaurants r on r.google_place_id = x.place_id;
  if bad is not null then raise exception '{CC}: Place ID already used: %', bad; end if;
end $$;
insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
                                address, location, michelin_url, website_url, phone, property_name, google_place_id)
select x.code, x.name, x.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = '{CC}' and c.name = x.city), '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone, x.property_name, x.place_id
  from _new_{cc} x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', x.stars, true, date '{A}'
  from _new_{cc} x join public.restaurants r on r.restaurant_code = x.code;""")
        if fills:
            P.append(f"""-- {CC} 5. existing rows, fill-only (never overwrites)
create temp table _fill_{cc} (code text primary key, michelin_url text, phone text, website_url text, place_id text, property_name text) on commit drop;
insert into _fill_{cc} values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['michelin_url'])}, {q(f['phone'])}, {q(f['website_url'])}, {q(f['place_id'])}, {q(f['property_name'])})" for f in fills)};
do $$
declare bad text;
begin
  select string_agg(f.code, ', ') into bad from _fill_{cc} f join public.restaurants r on r.michelin_url = f.michelin_url and r.restaurant_code <> f.code;
  if bad is not null then raise exception '{CC}: michelin_url used by another row: %', bad; end if;
  select string_agg(f.code, ', ') into bad from _fill_{cc} f join public.restaurants r on r.google_place_id = f.place_id and r.restaurant_code <> f.code;
  if bad is not null then raise exception '{CC}: Place ID used by another row: %', bad; end if;
end $$;
update public.restaurants r set michelin_url = f.michelin_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.michelin_url is not null and r.michelin_url is null;
update public.restaurants r set phone = f.phone, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set website_url = f.website_url, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.website_url is not null and r.website_url is null;
update public.restaurants r set google_place_id = f.place_id, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.place_id is not null and r.google_place_id is null;
update public.restaurants r set property_name = f.property_name, updated_at = now() from _fill_{cc} f where r.restaurant_code = f.code and f.property_name is not null and r.property_name is null
   and not exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);""")
        if new_links:
            P.append(f"""-- {CC} 6. links to hotels in `hotels`
create temp table _links_{cc} (hotel_code text, restaurant_code text, confidence text, evidence text) on commit drop;
insert into _links_{cc} values
{(','+chr(10)).join(f"    ({q(h)}, {q(r)}, {q(c)}, {q(ev)})" for h, r, c, ev in new_links)};
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, l.confidence, l.evidence, now()
  from _links_{cc} l join public.hotels h on h.hotel_code = l.hotel_code join public.restaurants r on r.restaurant_code = l.restaurant_code
on conflict (hotel_id, restaurant_id) do nothing;""")
        cn = expected[CC]
        P.append(f"""-- {CC} post-conditions: MICHELIN's live 2026 listing{' plus the KEPT rows' if kept else ''}
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 3;
  if n <> {cn[3]} then raise exception '{CC}: expected {cn[3]} three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 2;
  if n <> {cn[2]} then raise exception '{CC}: expected {cn[2]} two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}' and michelin_stars = 1;
  if n <> {cn[1]} then raise exception '{CC}: expected {cn[1]} one-star, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}'
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '{CC}: % restaurants without exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r join public.award_history ah on ah.entity_type = 'restaurant'
     and ah.entity_id = r.id and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = '{CC}' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '{CC}: % restaurants disagree with their current award row', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '{CC}: % restaurants have both a hotel link and a property_name', n; end if;
end $$;""")
        sql_parts.append('\n\n'.join(P))

    # ---- write outputs
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'detail'])
        w.writeheader(); w.writerows(report)
    towns = sorted(newtowns)
    mig = f"""-- MICHELIN Germany 2026 / Italy 2026: city-only prerequisite for the starred
-- restaurants added by supabase/data/enrichment/michelin_de_it/prepared_de_it_stars_2026.sql.
-- Generated by build_prepared_de_it.py from production's export. Filename
-- timestamp is a sequence number only. Names are MICHELIN's English listing
-- names, as production writes German and Italian towns (Munich, Rome). None
-- exists in production's export, compared accent- and case-insensitively.
-- region and postal_municipality left NULL, matching the existing rows.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, NULL)" for c, t in towns) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""" if towns else None
    if mig:
        open(os.path.join(MIG_DIR, mig_name), 'w').write(mig)
    head = f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Germany 2026 (announced 23 June 2026) and Italy 2026 (announced
-- 19 November 2025): bring every German and Italian restaurant's stars and
-- award_history in line with MICHELIN's live 2026 listing, add the starred
-- restaurants missing from the catalogue with verified Google Place IDs and
-- phones, and complete the existing rows (fill-only). Generated by
-- build_prepared_de_it.py; evidence and every judgement call in
-- match_report.csv and README.md.
--
-- Germany: launch rows hold 2025 values (verified per row against
-- MICHELIN's 2025 list) and are relabelled 2025 first, as for the
-- Netherlands; 2026 changes and losses are then written as new rows.
-- Italy: launch rows hold 2026 values; import errors corrected in place;
-- rows in MICHELIN's 2026 article that are offline now are KEPT.
--
-- Summary: {json.dumps(summary)}
--
-- PREREQUISITE: supabase/migrations/{mig_name if mig else '(none needed)'}.
-- One transaction; every check raises and rolls the whole file back.

begin;
"""
    optional = '''

-- ============================================================
-- OPTIONAL -- commented out; needs an explicit decision
-- ============================================================
-- Aqua (rest_0186, Wolfsburg) closed: "Nach 25 Jahren: Drei-Sterne-Restaurant
-- 'Aqua' in Wolfsburg schliesst", last services in March 2026 (ms-aktuell.de;
-- chef Sven Elverfeld's own announcement via foodle.pro); MICHELIN's page now
-- returns "Restaurant not found". The exact last day is not confirmed, so
-- status_since stays NULL rather than a guessed date. The loss itself
-- (2026 = NULL) is already in the file above; this only sets the status.
--
-- update public.restaurants
--    set status = 'permanently_closed',
--        status_note = 'Closed after 25 years; last services March 2026 (exact date not confirmed)',
--        updated_at = now()
--  where restaurant_code = 'rest_0186' and name = 'Aqua' and country_code = 'DE';
--
-- Courtier (rest_0230, Weissenhaus) is reported permanently closed after its
-- chefs left (tageskarte.io), but the timing is unclear and one listing still
-- shows reviews from April 2026 -- logged, not prepared.
'''
    open(os.path.join(HERE, 'prepared_de_it_stars_2026.sql'), 'w').write(head + '\n'.join(sql_parts) + '\n\ncommit;\n' + optional)
    print(json.dumps(summary, indent=1))
    print('new towns:', len(towns), '| report rows:', len(report), collections.Counter(r['kind'] for r in report))
    print('expected counts:', {k: dict(v) for k, v in expected.items()}, '| next free code:', code)


if __name__ == '__main__':
    main()
