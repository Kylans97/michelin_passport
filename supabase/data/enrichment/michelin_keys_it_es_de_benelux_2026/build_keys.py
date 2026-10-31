#!/usr/bin/env python3
"""Build the IT/ES/DE/BE/NL/LU MICHELIN Key refresh (research 2026-10-31).

Usage:
  python3 build_keys.py <first_hotel_code> <migration_name>

Reads only committed files:
  _source/production_export_20261031.json   production, read-only (export_keys_query.sql)
  _source/michelin_hotel_listing_20261031.json  every card of /en/hotels-stays/<country>
  _source/michelin_hotel_pages_20261031.json    every Key hotel page + every production
                                                hotel page that is not a Key card
  _source/michelin_article_*.json               MICHELIN's Key articles (2024, 2025, 2026)
  decisions.json                                by-hand judgements, each with evidence

Writes <cc>_key_hotels.csv, match_report.csv, prepared_keys_it_es_de_benelux_2026.sql
and supabase/migrations/<migration_name>.

Rules (README):
  * identity is MICHELIN's numeric hotel id (the stored michelin_url), never a name;
    a new hotel within 150 m of any stored hotel is held back as a possible duplicate;
  * the hotel page's JSON-LD `award` decides the 2026 Key (cards are a cross-check);
  * a Key that changed: the launch row (labelled 2026) is relabelled to the edition
    whose MICHELIN article gives exactly its value (QA-217 rule), else held back;
  * a production Key hotel that is not a 2026 Key hotel is reported, never changed.
"""
import collections, csv, glob, json, math, os, re, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
MIG_DIR = os.path.normpath(os.path.join(HERE, '../../../migrations'))
SRC = os.path.join(HERE, '_source')
K = {'One': 1, 'Two': 2, 'Three': 3}
CARD = {'ONE_KEY': 1, 'TWO_KEYS': 2, 'THREE_KEYS': 3}
COUNTRIES = {'IT': 'italy', 'ES': 'spain', 'DE': 'germany', 'BE': 'belgium', 'NL': 'netherlands', 'LU': 'luxembourg'}
LD_COUNTRY = {'ITA': 'IT', 'ESP': 'ES', 'DEU': 'DE', 'BEL': 'BE', 'NLD': 'NL', 'LUX': 'LU'}
# MICHELIN's 2026 global Key article (18 Sep 2026): Key hotels per country
EXPECT = {'IT': 224, 'ES': 122, 'DE': 130, 'BE': 18, 'NL': 18, 'LU': 2}
KEY_YEAR, ANNOUNCED = 2026, '2026-09-18'


def n(s):
    s = unicodedata.normalize('NFKD', s or '')
    return ''.join(c for c in s if not unicodedata.combining(c)).lower()


def tk(s):
    return re.sub(r'[\s\-\'’.]', '', n(s))


def dist(a, b, c, d):
    p = math.pi / 180
    x = (math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2)
    return round(12742000 * math.asin(math.sqrt(x)))


def hid(u):
    m = re.search(r'-(\d+)/?$', (u or '').split('?')[0]) or re.search(r'/h/(\d+)/?$', (u or ''))
    return m.group(1) if m else None


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


TIERS = [(r'^the (one|two|three)[- ]keys? hotels$', {'one': 1, 'two': 2, 'three': 3}),
         (r'^los hoteles con (una|dos|tres) llaves?$', {'una': 1, 'dos': 2, 'tres': 3}),
         (r'^de (één|een|twee|drie) sleutel hotels$', {'één': 1, 'een': 1, 'twee': 2, 'drie': 3})]


def tier(heading):
    """Key tier named by an article's tier heading (English, Spanish, Dutch), else None."""
    h = (heading or '').strip().lower()
    for rx, val in TIERS:
        m = re.search(rx, h)
        if m:
            return val[m.group(1)]
    return None


def article_keys():
    """MICHELIN id -> {year: keys} from every saved Key article whose headings name a tier."""
    out = collections.defaultdict(dict)
    src, bad = {}, set()
    for f in sorted(glob.glob(os.path.join(SRC, 'michelin_article_*.json'))):
        a = json.load(open(f))
        year = a.get('edition')
        if not year:
            continue
        for l in a['links']:
            # tier lists only: under a heading "The One/Two/Three(-)Key Hotels", one entry per
            # line printed "Town: <hotel>" (or "Town - <hotel>"); an empty anchor right after
            # a "Town: Hotel" line is that line's link (Kronelamm, DE 2025). Body-text mentions
            # and photo captions are not tier entries.
            m = tier(l['heading']) or tier(l.get('section'))
            i = hid(l['href'])
            listed = re.search(r'[:\-–]$', l['prefix']) or (not l['text'] and ':' in l['prefix'])
            if m and i and listed:
                v = m
                if out[i].get(year, v) != v or (i, year) in bad:
                    # one MICHELIN id under two tiers of the same edition: the article
                    # links two hotels to one id (DE 2025: 7589 is both "Hotel am
                    # Steinplatz" and "Roomers Berlin Steinplatz"); no evidence either way
                    bad.add((i, year)); out[i].pop(year, None); src.pop((i, year), None)
                    continue
                out[i][year] = v
                src[(i, year)] = f"{os.path.basename(f)}: '{l['prefix'].split('>')[-1].strip()} {l['text']}' under '{l['heading']}'"
    return out, src, bad


def main():
    first_hcode, mig_name = int(sys.argv[1]), sys.argv[2]
    X = json.load(open(os.path.join(SRC, 'production_export_20261031.json')))
    listing = json.load(open(os.path.join(SRC, 'michelin_hotel_listing_20261031.json')))['rows']
    pages = {p['url']: p for p in json.load(open(os.path.join(SRC, 'michelin_hotel_pages_20261031.json')))['pages']}
    pages_by_id = {hid(u): p for u, p in pages.items()}
    D = json.load(open(os.path.join(HERE, 'decisions.json')))
    art, art_src, art_bad = article_keys()

    hotels = X['hotels']
    all_ids = {hid(u) for u in X['hotel_michelin_urls_in_use']}
    cities = X['cities']

    # ---- MICHELIN 2026 Key hotels of the six countries, from their own pages
    cards, foreign = {}, {}
    for r in listing:
        if r['pid'] and r['pid'].isdigit() and r['distinction'] in CARD:
            if (r['hotel_country'] or '').upper() not in COUNTRIES:
                # The Little Nell (Aspen), a recommendation card MICHELIN shows on every
                # country listing (as on France's); counted under its own country
                foreign.setdefault(r['pid'], r)
                continue
            cards.setdefault(r['pid'], r)
    keyh = collections.defaultdict(list)
    report = []
    for pid, r in cards.items():
        p = pages_by_id.get(pid)
        assert p and p['status'] == 200 and p['ld'], ('page missing', pid, r['url'])
        ld = p['ld']
        if not ld.get('award'):
            report.append(dict(country='', code='', name=p['h1'], kind='CARD KEY, PAGE NO AWARD', detail=r['url']))
            continue
        a = ld['address']
        CC = LD_COUNTRY.get(a.get('addressCountry'))
        if CC is None:
            report.append(dict(country=a.get('addressCountry'), code='', name=p['h1'], kind='KEY CARD OUTSIDE THESE COUNTRIES',
                               detail=f"{r['url']} listed under /{r['listing']}; JSON-LD addressCountry {a.get('addressCountry')} -- not handled here"))
            continue
        keys = K[ld['award']['awardFor'].split()[0]]
        keyh[CC].append(dict(
            name=p['h1'], keys=keys, card_keys=CARD[r['distinction']], city=a.get('addressLocality'),
            address=', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in ((a.get('postalCode') or '').strip(), a.get('addressLocality')) if y)) if x and x.strip()),
            lat=float(ld['geo']['latitude']), lon=float(ld['geo']['longitude']), michelin_url=p['final_url'].split('?')[0],
            michelin_id=pid, michelin_phone=ld.get('telephone'), date_awarded=ld['award'].get('dateAwarded'),
            address_country=a.get('addressCountry'), listing=r['listing'],
            keys_2025=art.get(pid, {}).get(2025), keys_2024=art.get(pid, {}).get(2024)))
    for pid, r in foreign.items():
        report.append(dict(country=r['hotel_country'].upper(), code='', name=r['name'], kind='KEY CARD OF ANOTHER COUNTRY',
                           detail=f"{r['url']} shown on the listings of {', '.join(sorted({x['listing'] for x in listing if x['pid'] == pid}))} -- not handled here"))
    for CC, rows in keyh.items():
        rows.sort(key=lambda r: (-r['keys'], n(r['name'])))
        assert len(rows) == EXPECT[CC], (CC, len(rows), EXPECT[CC])

    key_ids = {k['michelin_id'] for rows in keyh.values() for k in rows}
    P, summ, towns_all = [], {}, []
    hcode = first_hcode
    for CC in COUNTRIES:
        cc = CC.lower()
        rows = keyh[CC]
        prod = [h for h in hotels if h['country'] == CC]
        ex = {hid(h['michelin_url']): h for h in prod}
        assert len(ex) == len(prod), CC
        city_names = {}
        prod_towns = set()
        for c in cities:
            if c['country'] == CC:
                city_names.setdefault(tk(c['name']), c['name']); prod_towns.add(c['name'])
        newtowns = set()

        def town_of(t, r):
            fix = D['towns'].get(r['michelin_url'])
            if fix:
                t = fix['town']
            t2 = city_names.setdefault(tk(t), t)
            if t2 not in prod_towns:
                newtowns.add(t2)
            return t2

        new, changes, fixes, verified, missing_row, held = [], [], [], [], [], []
        for k in rows:
            mid = k['michelin_id']
            if mid in ex:
                h = ex[mid]
                k['match'] = h['code']
                d = dist(h['lat'], h['lon'], k['lat'], k['lon'])
                cur = [x for x in (h['key_history'] or []) if x['current']]
                if d > 500:
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind='STORED HOTEL COORDINATES OFF (QA-388)',
                                       detail=f"matched by MICHELIN id {mid}; stored point {d} m from MICHELIN's -- reported, not changed"))
                if h['keys'] == k['keys']:
                    if cur:
                        verified.append(h['code'])
                        report.append(dict(country=CC, code=h['code'], name=h['name'], kind='2026 KEY VERIFIED',
                                           detail=f"MICHELIN id {mid}; stored point {d} m from MICHELIN's; production {h['keys']} = MICHELIN 2026 {k['keys']}; launch row left as is"))
                    else:
                        missing_row.append(h['code'])
                        report.append(dict(country=CC, code=h['code'], name=h['name'], kind='2026 KEY ROW ADDED (QA-390)',
                                           detail=f"MICHELIN id {mid}; production {h['keys']} = MICHELIN 2026; no michelin_keys row in award_history, one is written"))
                    continue
                launch = cur[0] if cur else None
                k25, k24 = k['keys_2025'], k['keys_2024']
                launch_ok = bool(launch and launch['year'] == 2026 and launch['announced_on'] is None
                                 and launch['value'] == h['keys'] and len(h['key_history']) == 1)
                no_row = not h['key_history']
                dec = D['hotels'].get(h['code'])
                if dec and dec.get('outcome') == 'hold':
                    held.append(h['code'])
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY CHANGE HELD BACK', detail=dec['evidence']))
                    continue
                src = art_src.get((mid, 2025))
                if k25 is not None and k25 == h['keys'] and (launch_ok or no_row):
                    # the stored Key is MICHELIN's 2025 Key: a real change in 2026
                    mode = 'relabel' if launch_ok else 'prior'
                    changes.append(dict(code=h['code'], name=h['name'], was=h['keys'], keys=k['keys'], launch_year=2025, mode=mode))
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind=f"KEY CHANGE {h['keys']} -> {k['keys']} (QA-383)",
                                       detail=f"MICHELIN id {mid}; production {h['keys']} is MICHELIN's 2025 Key ({src}); "
                                              + ("launch row 2026 relabelled 2025, non-current" if mode == 'relabel'
                                                 else "no Key row stored: a non-current 2025 row with that value is written")
                                              + f"; 2026 = {k['keys']} written"))
                elif k25 is not None and launch_ok:
                    # the stored Key matches no MICHELIN edition: an import error, corrected in place
                    fixes.append(dict(code=h['code'], name=h['name'], was=h['keys'], keys=k['keys']))
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind=f"KEY IMPORT ERROR {h['keys']} -> {k['keys']} (QA-384)",
                                       detail=f"MICHELIN id {mid}; launch row 2026 = {h['keys']}, but MICHELIN gives {k25} in 2025 ({src})"
                                              + (f" and {k24} in 2024 ({art_src.get((mid, 2024))})" if k24 is not None else ", no 2024 entry")
                                              + f" and {k['keys']} in 2026: the launch value matches no edition; the 2026 row is corrected in place to {k['keys']}"))
                else:
                    held.append(h['code'])
                    report.append(dict(country=CC, code=h['code'], name=h['name'], kind='KEY CHANGE HELD BACK',
                                       detail=f"production {h['keys']}, MICHELIN 2026 {k['keys']}; MICHELIN 2025 article {k25}, 2024 article {k24}; "
                                              f"Key history {h['key_history']}: the stored row's edition is not proven, nothing written"))
            else:
                if mid in all_ids:
                    raise SystemExit(f'{mid} stored on a hotel of another country')
                near = [(dist(h['lat'], h['lon'], k['lat'], k['lon']), h) for h in hotels if h['lat'] is not None]
                # a stored hotel nearby that is matched to its own, different 2026 Key id is a
                # neighbour, not a duplicate (Hassler / Hotel de la Ville, 16 m); hold only when
                # the stored hotel is not accounted for by MICHELIN's 2026 Key list
                near = [x for x in near if x[0] <= 150 and hid(x[1]['michelin_url']) not in key_ids]
                if near and not D['not_duplicates'].get(mid):
                    held.append(mid)
                    report.append(dict(country=CC, code='', name=k['name'], kind='NEW HOTEL HELD BACK (possible duplicate)',
                                       detail=f"{k['michelin_url']}: within 150 m of " + '; '.join(f"{h['code']} {h['name']} ({h['michelin_url']}, {d} m)" for d, h in near)))
                    continue
                code = f'hotel_{hcode}'; hcode += 1
                k['match'] = code
                k['town'] = town_of(k['city'], k)
                if k['town'] != k['city']:
                    k['town_note'] = (D['towns'].get(k['michelin_url']) or {}).get('evidence') or f"page locality '{k['city']}' = production's '{k['town']}'"
                new.append(dict(k, code=code))
                report.append(dict(country=CC, code=code, name=k['name'], kind='NEW KEY HOTEL',
                                   detail=f"MICHELIN id {mid}, {k['keys']} Key(s), town {k['town']}; MICHELIN 2025 article {k['keys_2025']}"
                                          + (f"; nearest stored hotel {D['not_duplicates'][mid]}" if D['not_duplicates'].get(mid) else '')))
        seen = {k['michelin_id'] for k in rows}
        lost = []
        for mid, h in ex.items():
            if mid in seen or h['keys'] is None:
                continue
            p = pages_by_id.get(mid)
            state = ('page ' + str(p['status']) + (', award ' + p['ld']['award']['awardFor'] if p.get('ld') and p['ld'].get('award') else ', no award on the page')) if p else 'page not read'
            lost.append(h['code'])
            report.append(dict(country=CC, code=h['code'], name=h['name'], kind='NOT A 2026 KEY HOTEL ON MICHELIN (QA-387)',
                               detail=f"MICHELIN id {mid}; production {h['keys']} Key(s); {h['michelin_url']}: {state}; MICHELIN 2025 article {art.get(mid, {}).get(2025)} -- left untouched, needs a decision"))
        for k in rows:
            k.setdefault('match', 'HELD'); k.setdefault('town', ''); k.setdefault('town_note', '')
        with open(os.path.join(HERE, f'{cc}_key_hotels.csv'), 'w', newline='') as f:
            cols = ['match', 'name', 'keys', 'card_keys', 'keys_2025', 'keys_2024', 'city', 'town', 'town_note', 'address',
                    'lat', 'lon', 'michelin_url', 'michelin_id', 'michelin_phone', 'date_awarded', 'address_country', 'listing']
            w = csv.DictWriter(f, fieldnames=cols, extrasaction='ignore'); w.writeheader(); w.writerows(rows)

        after = collections.Counter()
        for h in prod:
            after[h['keys']] += 1
        for c in changes + fixes:
            after[c['was']] -= 1; after[c['keys']] += 1
        for h in new:
            after[h['keys']] += 1
        summ[CC] = dict(michelin=dict(collections.Counter(k['keys'] for k in rows)), production_before=dict(collections.Counter(h['keys'] for h in prod)),
                        after={k: v for k, v in after.items() if v}, new_hotels=len(new), key_changes=len(changes), key_import_errors=len(fixes), verified=len(verified),
                        key_rows_added_existing=len(missing_row), not_key_on_michelin=len(lost), held=len(held), new_towns=len(newtowns))
        towns_all += [(CC, t) for t in sorted(newtowns)]
        last = hcode - 1

        # ---- SQL for this country
        P.append(f"\n-- ============================================================\n-- {CC}: {json.dumps(summ[CC])}\n-- ============================================================")
        P.append(f"""do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len(prod)} then raise exception '{CC}: expected {len(prod)} hotels (export), found % -- production changed, re-check', n; end if;
  select count(*) into n from (values {', '.join(f"({q(h['code'])}, {q(h['name'])}, {h['keys'] if h['keys'] is not None else 'NULL'}::smallint)" for h in prod)}) e(code, name, keys)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = '{CC}'
                      and h.michelin_keys is not distinct from e.keys);
  if n <> 0 then raise exception '{CC}: % exported hotels no longer carry their exported name or Key', n; end if;
end $$;""")
        rel = [c for c in changes if c['mode'] == 'relabel']
        pri = [c for c in changes if c['mode'] == 'prior']
        if rel:
            P.append(f"""-- {CC} 1a. Key changes: the launch row (labelled 2026, announced_on NULL) holds MICHELIN's 2025
--    Key (MICHELIN's own 2025 Key article, match_report.csv); relabelled 2025 and closed, value
--    unchanged (QA-217 rule); the 2026 row is written in step 3
create temp table _krel_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _krel_{cc} values
{(','+chr(10)).join(f"    ({q(c['code'])}, {c['keys']}, {c['was']})" for c in rel)};
do $$
declare n int;
begin
  select count(*) into n from _krel_{cc} k join public.hotels h on h.hotel_code = k.code and h.michelin_keys = k.was
    join public.award_history a on a.entity_type = 'hotel' and a.entity_id = h.id and a.award_type = 'michelin_keys'
   where a.is_current and a.guide_year = 2026 and a.award_value = k.was and a.announced_on is null
     and (select count(*) from public.award_history o where o.entity_type = 'hotel' and o.entity_id = h.id
           and o.award_type = 'michelin_keys') = 1;
  if n <> {len(rel)} then raise exception '{CC}: % of {len(rel)} Key launch rows found as exported -- has this file run?', n; end if;
end $$;
update public.award_history a set guide_year = 2025, is_current = false
  from public.hotels h, _krel_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys'
   and a.is_current and a.guide_year = 2026 and a.announced_on is null and a.award_value = k.was;
update public.hotels h set michelin_keys = k.keys, updated_at = now()
  from _krel_{cc} k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
        if pri:
            P.append(f"""-- {CC} 1b. Key changes on hotels stored without any Key row: the stored Key is MICHELIN's 2025 Key
--    (2025 Key article, match_report.csv); written as a non-current 2025 row, the 2026 row in step 3
create temp table _kpri_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kpri_{cc} values
{(','+chr(10)).join(f"    ({q(c['code'])}, {c['keys']}, {c['was']})" for c in pri)};
do $$
declare n int;
begin
  select count(*) into n from _kpri_{cc} k join public.hotels h on h.hotel_code = k.code and h.michelin_keys = k.was
   where not exists (select 1 from public.award_history o where o.entity_type = 'hotel' and o.entity_id = h.id
                      and o.award_type = 'michelin_keys');
  if n <> {len(pri)} then raise exception '{CC}: % of {len(pri)} hotels found without a Key row as exported -- has this file run?', n; end if;
end $$;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2025, 'michelin_keys', k.was, false, NULL
  from public.hotels h join _kpri_{cc} k on k.code = h.hotel_code;
update public.hotels h set michelin_keys = k.keys, updated_at = now()
  from _kpri_{cc} k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
        if fixes:
            P.append(f"""-- {CC} 1c. Key import errors: the launch row's value matches no MICHELIN edition (2024, 2025 and
--    2026 articles and pages agree with each other, not with it); corrected in place to 2026
create temp table _kfix_{cc} (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kfix_{cc} values
{(','+chr(10)).join(f"    ({q(c['code'])}, {c['keys']}, {c['was']})" for c in fixes)};
do $$
declare n int;
begin
  select count(*) into n from _kfix_{cc} k join public.hotels h on h.hotel_code = k.code and h.michelin_keys = k.was
    join public.award_history a on a.entity_type = 'hotel' and a.entity_id = h.id and a.award_type = 'michelin_keys'
   where a.is_current and a.guide_year = 2026 and a.award_value = k.was and a.announced_on is null;
  if n <> {len(fixes)} then raise exception '{CC}: % of {len(fixes)} Key launch rows found as exported -- has this file run?', n; end if;
end $$;
update public.award_history a set award_value = k.keys
  from public.hotels h, _kfix_{cc} k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys'
   and a.is_current and a.guide_year = 2026 and a.announced_on is null and a.award_value = k.was;
update public.hotels h set michelin_keys = k.keys, updated_at = now()
  from _kfix_{cc} k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
        if new:
            P.append(f"""-- {CC} 2. MICHELIN 2026 Key hotels missing from `hotels`: {new[0]['code']}..{new[-1]['code']}
--    (name = page h1; address, pin and michelin_url = page JSON-LD; website, phone and
--    Place ID NULL: not researched in this pass, QA-385; towns QA-386)
create temp table _new_{cc} (code text, name text, keys smallint, city text, address text, lon float8, lat float8,
                        michelin_url text) on commit drop;
insert into _new_{cc} values
{(','+chr(10)).join(f"    ({q(h['code'])}, {q(h['name'])}, {h['keys']}::smallint, {q(h['town'])}, {q(h['address'])}, {h['lon']}, {h['lat']}, {q(h['michelin_url'])})" for h in new)};
do $$
declare bad text;
begin
  if exists (select 1 from public.hotels h join _new_{cc} x on x.code = h.hotel_code) then
    raise exception '{CC}: hotel codes {new[0]['code']}..{new[-1]['code']} are no longer free -- re-check';
  end if;
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_{cc} x
   where (select count(*) from public.cities c where c.country_code = '{CC}' and c.name = x.city) <> 1;
  if bad is not null then raise exception '{CC}: hotel city does not resolve to exactly one row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_{cc} x join public.hotels h
    on substring(h.michelin_url from '-([0-9]+)/?$') = substring(x.michelin_url from '-([0-9]+)/?$');
  if bad is not null then raise exception '{CC}: hotel already present (MICHELIN id): %', bad; end if;
end $$;
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url)
select x.code, x.name, x.keys,
       (select c.id from public.cities c where c.country_code = '{CC}' and c.name = x.city), '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography, x.michelin_url
  from _new_{cc} x;""")
        todo = [c['code'] for c in changes] + [h['code'] for h in new] + missing_row
        if todo:
            P.append(f"""-- {CC} 3. current 2026 Key row for the Key changes, the new hotels and the existing hotels
--    imported without any Key row
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, {KEY_YEAR}, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED}'
  from public.hotels h
 where h.hotel_code = any(array[{', '.join(q(c) for c in todo)}])
   and not exists (select 1 from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
                    and a.award_type = 'michelin_keys' and a.is_current);""")
        exp = sum(v for k2, v in after.items() if k2 is not None)
        P.append(f"""-- {CC} 4. post-conditions
do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys is not null;
  if n <> {exp} then raise exception '{CC}: expected {exp} Key hotels, found %', n; end if;
""" + ''.join(f"""  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = {kk};
  if n <> {after[kk]} then raise exception '{CC}: expected {after[kk]} {kk}-Key hotels, found %', n; end if;
""" for kk in (1, 2, 3)) + f"""  select count(*) into n from public.hotels h where h.country_code = '{CC}' and h.michelin_keys is not null
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '{CC}: % Key hotels without exactly one matching current Key row', n; end if;
end $$;""")

    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'detail']); w.writeheader(); w.writerows(report)

    open(os.path.join(MIG_DIR, mig_name), 'w').write(f"""-- MICHELIN 2026 Key hotels, Italy, Spain, Germany, Belgium, the Netherlands and
-- Luxembourg: the city prerequisite for the Key hotels added by
-- supabase/data/enrichment/michelin_keys_it_es_de_benelux_2026/prepared_keys_it_es_de_benelux_2026.sql.
-- Generated by build_keys.py from production's read-only export of 2026-10-31
-- (written 2026-10-31; the filename timestamp is a sequence number only). Names are
-- the hotel page's locality, or the town recorded in decisions.json with its
-- evidence; none exists in production's export for its country, compared
-- accent-, case-, space- and hyphen-insensitively. region and
-- postal_municipality left NULL, matching the existing rows. Idempotent: ON
-- CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, NULL)" for c, t in towns_all) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    head = f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Key hotels 2026 (global Key launch, 18 September 2026) for Italy, Spain,
-- Germany, Belgium, the Netherlands and Luxembourg: write the Key changes on existing
-- hotels (launch row relabelled to the edition it holds, QA-217 rule), add the Key
-- hotels missing from the catalogue, and give every Key hotel exactly one current
-- Key row. Hotels MICHELIN no longer shows with a Key are reported only
-- (match_report.csv, README). No restaurant, link or property_name is touched.
-- Generated by build_keys.py; evidence in match_report.csv, decisions.json, README.md.
--
-- PREREQUISITE: supabase/migrations/{mig_name}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

do $$
begin
  if exists (select 1 from public.award_history a join public.hotels h on h.id = a.entity_id
              where a.entity_type = 'hotel' and a.award_type = 'michelin_keys' and a.is_current and a.guide_year <> 2026
                and h.country_code in ('IT', 'ES', 'DE', 'BE', 'NL', 'LU')) then
    raise exception 'current michelin_keys rows of these countries are not all guide_year 2026 -- re-check';
  end if;
end $$;
"""
    open(os.path.join(HERE, 'prepared_keys_it_es_de_benelux_2026.sql'), 'w').write(head + '\n\n'.join(P) + '\n\ncommit;\n')
    for CC in summ:
        print(CC, json.dumps(summ[CC]))
    print('report:', dict(collections.Counter(r['kind'] for r in report)))
    print('codes hotel', first_hcode, '..', hcode - 1, '| new towns', len(towns_all))


if __name__ == '__main__':
    main()
