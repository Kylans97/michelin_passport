#!/usr/bin/env python3
"""Build the Poland + Türkiye 2026 pass (research 2026-11-01).

  python3 build_pl_tr.py

Reads only committed files in _source/:
  production_export_20261101.json            production, read-only (export_pl_tr_query.sql)
  michelin_star_listing_20261101.json        /en/{pl,tr}/restaurants/all-starred
  michelin_restaurant_pages_20261101.json    every starred restaurant's page
  restaurant_site_checks_20261101.json       each MICHELIN website link fetched (check_sites.py)
  michelin_hotel_listing_20261101.json       /en/hotels-stays/{poland,turkey}
  michelin_hotel_pages_20261101.json         every Key hotel's page + every production hotel's page
  michelin_property_hotel_pages_20261101.json  the two non-Key hotels named as host by MICHELIN
Writes pl_tr_restaurants_2026.csv, pl_tr_key_hotels_2026.csv, match_report.csv,
prepared_pl_tr_2026.sql and supabase/migrations/<MIGRATION>.

Rules (README.md):
  * identity: MICHELIN's numeric id (restaurants: listing card / slug + 500 m; hotels: the
    id ending the stored michelin_url), never a name;
  * the page's JSON-LD award decides; restaurant pages say dateAwarded 2026, the global Key
    article of 18 Sep 2026 gives PL 14 / TR 23 Key hotels;
  * a stored 2026 value that MICHELIN 2026 contradicts is corrected in place (QA-384 shape) --
    no 2025 value is asserted for it;
  * phone only when printed on the venue's own site; website = MICHELIN's link when it loads
    and names the venue; no Place ID (no Google access in this session).
"""
import csv, json, math, os, re, unicodedata, collections

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '_source')
MIG_DIR = os.path.normpath(os.path.join(HERE, '../../../migrations'))
MIGRATION = '20261031180000_add_pl_tr_2026_cities.sql'
FIRST_REST, FIRST_HOTEL = 3901, 2901
ANNOUNCED = {'PL': '2026-05-27', 'TR': '2025-12-04'}   # MICHELIN's own edition articles
KEY_ANNOUNCED = '2026-09-18'
KEY_EXPECT = {'PL': 14, 'TR': 23}                      # global Key article, 18 Sep 2026
CARD = {'ONE_KEY': 1, 'TWO_KEYS': 2, 'THREE_KEYS': 3}
LD_KEYS = {'One': 1, 'Two': 2, 'Three': 3}

# Restaurant town = MICHELIN's English listing city (PT precedent), resolved
# accent-insensitively to an existing production row ('Kraków' -> 'Krakow').
# Hotel town = the hotel page's addressLocality with Turkish/Polish diacritics restored;
# one exception, noted per row.
HOTEL_TOWN = {'Alacati': 'Alaçatı', 'Nevsehir': 'Nevşehir', 'Bozbük': 'Bozbük', 'Hisarönü': 'Hisarönü',
              'Şile': 'Şile', 'Büyükada': 'Büyükada', 'Fethiye': 'Fethiye'}
HOTEL_TOWN_NOTE = {
    'Beyoğlu': ('Istanbul', "page locality 'Beyoğlu', a district of central Istanbul; production files "
                            "Beyoğlu's restaurants (Neolokal, Nicole, Mikla) under Istanbul"),
}

# Hotel links and property_name, each from MICHELIN's own pages (no 'Stay at the hotel'
# section exists on any PL/TR restaurant page).
LINKS = {   # restaurant MICHELIN id -> (hotel MICHELIN id, confidence, evidence)
    '1195854': ('15004', 'exact', "MICHELIN's Casa Lavanda review: 'The family-run business includes both a hotel and "
                                  "this restaurant'; restaurant and Key-hotel pages give the same address (Seçilmiş Sokak "
                                  "No:2, Ulupelit, Şile) and phone; pins 34 m apart. 2026-11-01."),
    '1208202': ('5656', 'exact', "MICHELIN's Maçakızı review: 'you arrive at this luxury hotel (the rooms are gorgeous!)'; "
                                 "restaurant and hotel pages give the same phone (+90 252 311 24 00) and website "
                                 "(macakizi.com); pins 95 m apart. 2026-11-01."),
}
PROPERTY = {  # restaurant MICHELIN id -> (property_name, evidence); host hotel not in `hotels`
    '1213363': ('Kayakapi Premium Caves - Cappadocia',
                "MICHELIN's Revithia review: 'set in Kayakapi - the name of both the hotel and the UNESCO-listed "
                "historic neighbourhood'; MICHELIN's website link is kayakapi.com/revithia; the hotel's MICHELIN page "
                "(7054, no Key) lists Revithia. Name as MICHELIN's hotel page writes it."),
    '1208228': ('The Bodrum EDITION',
                "Restaurant and MICHELIN hotel page 13266 (no Key) give the same address, Balyek Caddesi No:5A, "
                "Dirmil, Bodrum; MICHELIN's website link is editionhotels.com/bodrum/restaurants-and-bars/kitchen."),
}
NOT_PLACED = {  # logged, nothing written
    '1213087': "MICHELIN's review places Narımor 'at this stylish boutique hotel' without naming it -- no property_name",
    '1195528': "Mikla sits on top of The Marmara Pera, but no MICHELIN page says so -- no property_name",
}


def fold(s):
    s = unicodedata.normalize('NFKD', (s or '').replace('ı', 'i').replace('İ', 'I'))
    return ''.join(c for c in s if not unicodedata.combining(c)).lower().strip()


def dist(a, b, c, d):
    p = math.pi / 180
    x = (math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2)
    return round(12742000 * math.asin(math.sqrt(x)))


def hid(u):
    m = re.search(r'-(\d+)/?$', (u or '').split('?')[0])
    return m.group(1) if m else None


def slug(u):
    m = re.search(r'/restaurant/([^/?#]+)', u or '')
    return m.group(1).lower() if m else None


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


def addr(a):
    if isinstance(a, str):
        a = json.loads(a)
    a = a or {}
    street = re.sub(r'\s+', ' ', (a.get('streetAddress') or '')).strip().rstrip(',')
    pc = (a.get('postalCode') or '').strip()
    loc = (a.get('addressLocality') or '').strip()
    tail = ' '.join(x for x in (pc if pc != 'None' else '', loc) if x)
    return ', '.join(x for x in (street, tail) if x), loc


def load(name):
    return json.load(open(os.path.join(SRC, name)))


def main():
    X = load('production_export_20261101.json')
    listing = [r for r in load('michelin_star_listing_20261101.json')['rows'] if r['restaurant_country'] in ('pl', 'tr')]
    rpages = {p['url']: p for p in load('michelin_restaurant_pages_20261101.json')['pages']}
    sites = {s['url']: s for s in load('restaurant_site_checks_20261101.json')}
    hcards = [r for r in load('michelin_hotel_listing_20261101.json')['rows'] if r['hotel_country'] in ('pl', 'tr')]
    hpages = {hid(p['url']): p for p in load('michelin_hotel_pages_20261101.json')['pages']}
    ppages = {hid(p['url']): p for p in load('michelin_property_hotel_pages_20261101.json')['pages']}
    cities = {(c['country'], fold(c['name'])): c['name'] for c in X['cities']}
    rest_pid_in_use = set(X['place_ids_in_use'] or [])
    rest_url_in_use = set(X['michelin_urls_in_use'] or [])
    hotel_url_ids = {hid(u) for u in (X['hotel_michelin_urls_in_use'] or [])}
    report, newtowns = [], {}

    def town(cc, name, note=None):
        t = cities.get((cc, fold(name)))
        if t:
            return t
        newtowns.setdefault((cc, name), note)
        return name

    # ================= hotels =================
    keycards = {r['pid']: r for r in hcards if r['distinction'] in CARD}
    stored = {hid(h['michelin_url']): h for h in X['hotels']}
    hrows, kfix, newh = [], [], []
    hcode = FIRST_HOTEL
    for pid, card in sorted(keycards.items(), key=lambda kv: (kv[1]['listing'], kv[1]['name'])):
        p = hpages[pid]
        ld = p['ld'] or {}
        aw = ld.get('award') or {}
        if isinstance(aw, str):
            aw = json.loads(aw)
        m = re.match(r'(One|Two|Three) MICHELIN Key', aw.get('awardFor') or '')
        keys = LD_KEYS[m.group(1)] if m else None
        assert keys == CARD[card['distinction']], (pid, keys, card)
        cc = card['listing']
        geo = ld.get('geo') or {}
        a, loc = addr(ld.get('address'))
        row = dict(country=cc, michelin_id=pid, name=p['h1'], keys=keys, card=card['distinction'],
                   michelin_url=p['url'], address=a, lat=geo.get('latitude'), lon=geo.get('longitude'),
                   michelin_phone=ld.get('telephone'))
        if pid in stored:
            h = stored[pid]
            cur = [x for x in (h['history'] or []) if x['type'] == 'michelin_keys' and x['current']]
            row.update(code=h['code'], action='existing', town=h['city'], stored_keys=h['keys'],
                       stored_row='; '.join(f"{x['year']}={x['value']} announced {x['announced_on']}" for x in cur))
            d = dist(h['lat'], h['lon'], float(row['lat']), float(row['lon']))
            row['note'] = f'stored point {d} m from MICHELIN pin'
            if h['keys'] != keys:
                assert len(cur) == 1 and cur[0]['year'] == 2026 and cur[0]['announced_on'] is None
                kfix.append((h['code'], keys, h['keys']))
                row['action'] = 'Key corrected in place'
            else:
                row['action'] = 'verified, unchanged'
        else:
            t, note = HOTEL_TOWN_NOTE.get(loc, (HOTEL_TOWN.get(loc, loc), ''))
            # a new hotel within 150 m of a stored hotel is held back as a possible duplicate
            near = [(dist(float(row['lat']), float(row['lon']), h['lat'], h['lon']), h['code']) for h in X['hotels']]
            near = [x for x in near if x[0] <= 150]
            assert not near, (pid, near)
            row.update(code=f'hotel_{hcode}', action='new', town=town(cc, t, note), stored_keys=None, stored_row='',
                       note=note)
            hcode += 1
            newh.append(row)
        hrows.append(row)
    # production hotels that are not 2026 Key cards
    for k, h in stored.items():
        if k not in keycards:
            p = hpages.get(k)
            aw = (p['ld'] or {}).get('award') if p else None
            report.append(dict(country=h['country'], code=h['code'], name=h['name'], kind='NOT A 2026 KEY HOTEL',
                               detail=f"stored keys {h['keys']}, award rows {h['history']}; live page award {aw!r} -- "
                                      "a World's 50 Best hotel (catalogue_expansion), left untouched"))
    for cc in ('PL', 'TR'):
        n = sum(1 for r in hrows if r['country'] == cc)
        assert n == KEY_EXPECT[cc], (cc, n)

    # ================= restaurants =================
    stored_r = [r for r in X['restaurants']]
    rrows, rfix, rnew, rfill, links, urlfix, locfix = [], [], [], [], [], [], []
    rcode = FIRST_REST
    hotel_code_by_id = {r['michelin_id']: r['code'] for r in hrows}
    hotel_code_by_id.update({hid(h['michelin_url']): h['code'] for h in X['hotels']})
    used = set()
    for c in sorted(listing, key=lambda r: (r['listing'], fold(r['name']))):
        cc = c['listing']
        p = rpages[c['url']]
        ld = p['ld'] or {}
        aw = ld.get('award') or {}
        stars = {'One': 1, 'Two': 2, 'Three': 3}[aw['awardFor'].split()[0]]
        assert aw.get('dateAwarded') == '2026' and stars == {'ONE_STAR': 1, 'TWO_STARS': 2, 'THREE_STARS': 3}[c['pin']]
        s = sites.get(c['url'], {})
        a, _ = addr(ld.get('address'))
        phone_ok = bool(s.get('phone_on_site') or s.get('phone_on_contact'))
        web_ok = s.get('status') == '200' and s.get('names_venue')
        row = dict(country=cc, michelin_id=c['michelin_id'], name=ld['name'], stars=stars, michelin_url=c['url'],
                   address=a, lat=ld['latitude'], lon=ld['longitude'], listing_city=c['city'],
                   michelin_phone=ld.get('telephone'), phone=ld.get('telephone') if phone_ok else None,
                   phone_source=('on official site' + (f" ({s.get('contact_page')})" if s.get('phone_on_contact') else ''))
                   if phone_ok else 'not found on official site -- left blank',
                   website=p['website'] if web_ok else None,
                   website_source='MICHELIN link loads and names the restaurant' if web_ok else 'not confirmed -- left blank',
                   place_id=None, place_note='no Google access in this session (QA)')
        # match a stored row: MICHELIN slug, same country, within 500 m
        cand = [r for r in stored_r if r['country'] == cc and slug(r['michelin_url']) == slug(c['url'])
                and r['code'] not in used]
        if cand:
            e = cand[0]
            used.add(e['code'])
            d = dist(e['lat'], e['lon'], ld['latitude'], ld['longitude'])
            if d > 500:
                locfix.append((e['code'], e['lat'], e['lon'], e['address'], ld['latitude'], ld['longitude'], a))
                report.append(dict(country=cc, code=e['code'], name=e['name'], kind='LOCATION CORRECTED',
                                   detail=f"stored '{e['address']}' ({e['lat']:.5f}, {e['lon']:.5f}) is {d} m from MICHELIN's "
                                          f"pin ({ld['latitude']}, {ld['longitude']}), '{a}'. Corrected to MICHELIN's. The stored "
                                          f"Place ID {e['google_place_id']} is kept but unverified (QA)"))
            cur = [h for h in (e['history'] or []) if h['type'] == 'michelin_stars' and h['current']]
            assert len(cur) == 1 and cur[0]['year'] == 2026
            row.update(code=e['code'], town=e['city'], stored_stars=e['stars'],
                       note=f"matched by MICHELIN slug; stored point {d} m from MICHELIN pin")
            if e['stars'] != stars:
                rfix.append((e['code'], stars, e['stars']))
                row['action'] = 'stars corrected in place'
            else:
                row['action'] = 'verified, unchanged'
            f = dict(code=e['code'], name=e['name'],
                     phone=row['phone'] if not e['phone'] else None,
                     website_url=row['website'] if not e['website_url'] else None)
            if e['phone'] and row['phone'] and re.sub(r'\D', '', e['phone']) != re.sub(r'\D', '', row['phone']):
                report.append(dict(country=cc, code=e['code'], name=e['name'], kind='STORED PHONE DIFFERS',
                                   detail=f"stored {e['phone']} vs MICHELIN/site {row['phone']} -- stored kept"))
            if f['phone'] or f['website_url']:
                rfill.append(f)
            if e['michelin_url'] != c['url']:
                urlfix.append((e['code'], e['michelin_url'], c['url']))
        else:
            assert c['url'] not in rest_url_in_use
            row.update(code=f'rest_{rcode}', town=town(cc, c['city']), stored_stars=None, action='new', note='')
            rcode += 1
            rnew.append(row)
        mid = c['michelin_id']
        row['hotel_code'], row['property_name'] = None, None
        if mid in LINKS:
            hpid, conf, ev = LINKS[mid]
            row['hotel_code'] = hotel_code_by_id[hpid]
            links.append((row['hotel_code'], row['code'], conf, ev))
        elif mid in PROPERTY:
            row['property_name'] = PROPERTY[mid][0]
            report.append(dict(country=cc, code=row['code'], name=row['name'], kind='property_name', detail=PROPERTY[mid][1]))
        elif mid in NOT_PLACED:
            report.append(dict(country=cc, code=row['code'], name=row['name'], kind='HOTEL NOT NAMED', detail=NOT_PLACED[mid]))
        rrows.append(row)
    for e in stored_r:
        if e['code'] not in used:
            report.append(dict(country=e['country'], code=e['code'], name=e['name'], kind='NOT IN MICHELIN 2026',
                               detail='left untouched, check by hand'))

    for code, s, was in rfix:
        report.append(dict(country='TR', code=code, name=next(r['name'] for r in rrows if r['code'] == code),
                           kind='STARS: IMPORT ERROR CORRECTED',
                           detail=f"2026 row holds {was}; MICHELIN gives {s} in both the 2025 edition (article of "
                                  f"6 Dec 2024 lists it among the One Stars) and 2026 (page, dateAwarded 2026)"))
    kevid = {'hotel_307': "MICHELIN's Poland Key article of 9 Oct 2025 (2025 edition): '(1 MICHELIN Key)'; 2026 page: One Key",
             'hotel_311': "MICHELIN's Poland Key article of 9 Oct 2025 (2025 edition): '(1 MICHELIN Key)'; 2026 page: One Key",
             'hotel_306': "2026 page: Two Keys. No MICHELIN source for its 2025 Key found (no 2025 Poland Key list; "
                          "Internet Archive captures are of the 2024 edition and the archive was offline) -- DECISION",
             'hotel_313': "2026 page: One Key. No MICHELIN source for its 2025 Key found (as hotel_306) -- DECISION"}
    for code, k, was in kfix:
        report.append(dict(country='PL', code=code, name=next(r['name'] for r in hrows if r['code'] == code),
                           kind='KEYS: 2026 ROW CORRECTED IN PLACE', detail=f"stored {was} -> {k}. {kevid[code]}"))

    # ================= outputs =================
    def wcsv(name, rows, cols):
        with open(os.path.join(HERE, name), 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=cols, extrasaction='ignore')
            w.writeheader(); w.writerows(rows)
    wcsv('pl_tr_restaurants_2026.csv', rrows,
         ['country', 'code', 'action', 'name', 'stars', 'stored_stars', 'michelin_id', 'michelin_url', 'town', 'listing_city',
          'address', 'lat', 'lon', 'phone', 'phone_source', 'michelin_phone', 'website', 'website_source', 'place_id',
          'place_note', 'hotel_code', 'property_name', 'note'])
    wcsv('pl_tr_key_hotels_2026.csv', hrows,
         ['country', 'code', 'action', 'name', 'keys', 'stored_keys', 'stored_row', 'card', 'michelin_id', 'michelin_url',
          'town', 'address', 'lat', 'lon', 'michelin_phone', 'note'])
    wcsv('match_report.csv', report, ['country', 'code', 'name', 'kind', 'detail'])

    towns = sorted(newtowns)
    mig = f"""-- MICHELIN Poland 2026 / Türkiye 2026 + 2026 Key hotels: city-only prerequisite for
-- supabase/data/enrichment/michelin_pl_tr_2026/prepared_pl_tr_2026.sql.
-- Written 2026-11-01 by build_pl_tr.py from production's read-only export of that day.
-- Filename timestamp is a sequence number only (next after 20261031170000).
-- Restaurant towns are MICHELIN's English listing names; hotel towns the hotel page's
-- locality with diacritics restored. None exists in production's export, compared
-- accent- and case-insensitively. region and postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('{c}', {q(t)}, NULL)" for c, t in towns) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
"""
    open(os.path.join(MIG_DIR, MIGRATION), 'w').write(mig)

    S = []
    exp_r = {cc: collections.Counter(r['stars'] for r in rrows if r['country'] == cc) for cc in ('PL', 'TR')}
    exp_h = {cc: collections.Counter(r['keys'] for r in hrows if r['country'] == cc) for cc in ('PL', 'TR')}
    S.append(f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Poland 2026 (announced 27 May 2026) and Türkiye 2026 (announced 4 Dec 2025),
-- plus the 2026 MICHELIN Key hotels of both (global Key article, 18 Sep 2026: Poland 14,
-- Türkiye 23). Brings every PL/TR restaurant's stars and every PL/TR Key hotel's Key in
-- line with MICHELIN's live selection, adds what the catalogue lacks, and completes the
-- existing rows (fill-only). Generated by build_pl_tr.py; evidence per row in
-- pl_tr_restaurants_2026.csv, pl_tr_key_hotels_2026.csv and match_report.csv.
--
-- Restaurants: {len(rnew)} added ({rnew[0]['code']}..{rnew[-1]['code']}), {len(rfix)} star import error corrected in place,
--   {len(rfill)} existing rows filled, {len(urlfix)} michelin_url moved to MICHELIN's current page.
-- Hotels: {len(newh)} Key hotels added ({newh[0]['code']}..{newh[-1]['code']}), {len(kfix)} Keys corrected in place.
-- Locations: {len(locfix)} existing restaurants moved to MICHELIN's pin and address.
-- Links: {len(links)}; property_name: {sum(1 for r in rrows if r['property_name'])}.
-- No Google Place ID is written (no Google access in this pass).
--
-- PREREQUISITE: supabase/migrations/{MIGRATION}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

-- 0. production is still the export of {X['exported_at'][:16]} UTC
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code in ('PL', 'TR');
  if n <> {len(stored_r)} then raise exception 'expected {len(stored_r)} PL/TR restaurants (export), found % -- production changed', n; end if;
  select count(*) into n from public.hotels where country_code in ('PL', 'TR');
  if n <> {len(X['hotels'])} then raise exception 'expected {len(X['hotels'])} PL/TR hotels (export), found % -- production changed', n; end if;
  select count(*) into n from (values {', '.join(f"({q(e['code'])}, {q(e['name'])}, {q(e['country'])})" for e in stored_r + X['hotels'])}) e(code, name, cc)
   where not exists (select 1 from public.restaurants r where r.restaurant_code = e.code and r.name = e.name and r.country_code = e.cc)
     and not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = e.cc);
  if n <> 0 then raise exception '% exported codes no longer carry their exported name', n; end if;
  if exists (select 1 from public.restaurants where restaurant_code = any(array[{', '.join(q(r['code']) for r in rnew)}]))
  then raise exception 'restaurant codes {rnew[0]['code']}..{rnew[-1]['code']} are no longer free'; end if;
  if exists (select 1 from public.hotels where hotel_code = any(array[{', '.join(q(r['code']) for r in newh)}]))
  then raise exception 'hotel codes {newh[0]['code']}..{newh[-1]['code']} are no longer free'; end if;
end $$;""")

    S.append(f"""-- 1. Key import errors: a 2026 launch row (announced_on NULL) whose value MICHELIN's 2026 page
--    contradicts; corrected in place to 2026 (QA-384 shape). No 2025 value is asserted.
create temp table _kfix (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kfix values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {w})" for c, k, w in kfix)};
do $$
declare n int;
begin
  select count(*) into n from _kfix k join public.hotels h on h.hotel_code = k.code and h.michelin_keys = k.was
    join public.award_history a on a.entity_type = 'hotel' and a.entity_id = h.id and a.award_type = 'michelin_keys'
   where a.is_current and a.guide_year = 2026 and a.award_value = k.was and a.announced_on is null;
  if n <> {len(kfix)} then raise exception '% of {len(kfix)} Key launch rows found as exported -- has this file run?', n; end if;
end $$;
update public.award_history a set award_value = k.keys
  from _kfix k, public.hotels h
 where h.hotel_code = k.code and a.entity_type = 'hotel' and a.entity_id = h.id and a.award_type = 'michelin_keys'
   and a.is_current and a.guide_year = 2026 and a.award_value = k.was;
update public.hotels h set michelin_keys = k.keys, updated_at = now()
  from _kfix k where h.hotel_code = k.code and h.michelin_keys = k.was;""")

    S.append(f"""-- 2. Key hotels missing from the catalogue, each with a current 2026 Key row.
--    Name = page h1; address and pin = page JSON-LD. Phone, website and Place ID left
--    NULL: none confirmable outside MICHELIN in this pass (QA).
create temp table _newh (code text, cc text, name text, keys smallint, city text, address text, lon float8, lat float8,
                        michelin_url text) on commit drop;
insert into _newh values
{(','+chr(10)).join(f"    ({q(r['code'])}, {q(r['country'])}, {q(r['name'])}, {r['keys']}, {q(r['town'])}, {q(r['address'])}, {r['lon']}, {r['lat']}, {q(r['michelin_url'])})" for r in newh)};
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _newh x
   where (select count(*) from public.cities c where c.country_code = x.cc and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _newh x join public.hotels h
    on substring(h.michelin_url from '-([0-9]+)/?$') = substring(x.michelin_url from '-([0-9]+)/?$');
  if bad is not null then raise exception 'hotel already present (MICHELIN id): %', bad; end if;
end $$;
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url)
select x.code, x.name, x.keys,
       (select c.id from public.cities c where c.country_code = x.cc and c.name = x.city), x.cc,
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography, x.michelin_url
  from _newh x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '{KEY_ANNOUNCED}'
  from public.hotels h join _newh x on x.code = h.hotel_code;""")

    S.append(f"""-- 3. star import errors: a 2026 row whose value MICHELIN's 2025 and 2026 editions both contradict
create temp table _rfix (code text primary key, stars smallint, was smallint) on commit drop;
insert into _rfix values
{(','+chr(10)).join(f"    ({q(c)}, {s}, {w})" for c, s, w in rfix)};
do $$
declare n int;
begin
  select count(*) into n from _rfix f join public.restaurants r on r.restaurant_code = f.code and r.michelin_stars = f.was
    join public.award_history a on a.entity_type = 'restaurant' and a.entity_id = r.id and a.award_type = 'michelin_stars'
   where a.is_current and a.guide_year = 2026 and a.award_value = f.was;
  if n <> {len(rfix)} then raise exception '% of {len(rfix)} star rows found as exported -- has this file run?', n; end if;
end $$;
update public.award_history a set award_value = f.stars
  from _rfix f, public.restaurants r
 where r.restaurant_code = f.code and a.entity_type = 'restaurant' and a.entity_id = r.id
   and a.award_type = 'michelin_stars' and a.is_current and a.guide_year = 2026 and a.award_value = f.was;
update public.restaurants r set michelin_stars = f.stars, updated_at = now()
  from _rfix f where r.restaurant_code = f.code and r.michelin_stars = f.was;""")

    S.append(f"""-- 4. starred restaurants missing from the catalogue, each with a current 2026 row
create temp table _newr (code text, cc text, name text, stars smallint, city text, address text, lon float8, lat float8,
                        michelin_url text, website_url text, phone text, property_name text, announced date) on commit drop;
insert into _newr values
{(','+chr(10)).join(f"    ({q(r['code'])}, {q(r['country'])}, {q(r['name'])}, {r['stars']}, {q(r['town'])}, {q(r['address'])}, {r['lon']}, {r['lat']}, {q(r['michelin_url'])}, {q(r['website'])}, {q(r['phone'])}, {q(r['property_name'])}, date '{ANNOUNCED[r['country']]}')" for r in rnew)};
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _newr x
   where (select count(*) from public.cities c where c.country_code = x.cc and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _newr x join public.restaurants r on r.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'already present (michelin_url): %', bad; end if;
end $$;
insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
                                address, location, michelin_url, website_url, phone, property_name)
select x.code, x.name, x.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = x.cc and c.name = x.city), x.cc,
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone, x.property_name
  from _newr x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', x.stars, true, x.announced
  from _newr x join public.restaurants r on r.restaurant_code = x.code;""")

    S.append(f"""-- 5. existing restaurants: fill-only phone/website (each confirmed on the venue's own site), and
--    michelin_url moved from the old nl/nl page to MICHELIN's current page (same slug; guarded on the old value)
create temp table _fill (code text primary key, phone text, website_url text) on commit drop;
insert into _fill values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])})" for f in rfill)};
update public.restaurants r set phone = f.phone, updated_at = now() from _fill f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set website_url = f.website_url, updated_at = now() from _fill f where r.restaurant_code = f.code and f.website_url is not null and r.website_url is null;
create temp table _url (code text primary key, was text, url text) on commit drop;
insert into _url values
{(','+chr(10)).join(f"    ({q(c)}, {q(w)}, {q(u)})" for c, w, u in urlfix)};
do $$
declare n int;
begin
  select count(*) into n from _url u join public.restaurants r on r.restaurant_code = u.code and r.michelin_url = u.was;
  if n <> {len(urlfix)} then raise exception '% of {len(urlfix)} stored michelin_url values found as exported', n; end if;
  if exists (select 1 from _url u join public.restaurants r on r.michelin_url = u.url) then
    raise exception 'a current MICHELIN url is already used by another row'; end if;
end $$;
update public.restaurants r set michelin_url = u.url, updated_at = now()
  from _url u where r.restaurant_code = u.code and r.michelin_url = u.was;""")

    S.append(f"""-- 5b. location and address: stored point more than 500 m from MICHELIN's pin (three Istanbul
--    restaurants that moved, per their old stored address; Bottiglieria's point mis-geocoded with the
--    right address). Guarded on the old point within 5 m and the old address.
create temp table _loc (code text primary key, old_lat float8, old_lon float8, old_address text,
                       lat float8, lon float8, address text) on commit drop;
insert into _loc values
{(','+chr(10)).join(f"    ({q(c)}, {ola}, {olo}, {q(oa)}, {la}, {lo}, {q(na)})" for c, ola, olo, oa, la, lo, na in locfix)};
do $$
declare n int;
begin
  select count(*) into n from _loc l join public.restaurants r on r.restaurant_code = l.code
   where r.address = l.old_address
     and ST_DWithin(r.location, ST_SetSRID(ST_MakePoint(l.old_lon, l.old_lat), 4326)::geography, 5);
  if n <> {len(locfix)} then raise exception '% of {len(locfix)} stored locations found as exported -- has this file run?', n; end if;
end $$;
update public.restaurants r set location = ST_SetSRID(ST_MakePoint(l.lon, l.lat), 4326)::geography,
       address = l.address, updated_at = now()
  from _loc l where r.restaurant_code = l.code and r.address = l.old_address;""")

    S.append(f"""-- 6. links to hotels in `hotels`, each from MICHELIN's own pages (evidence column)
create temp table _links (hotel_code text, restaurant_code text, confidence text, evidence text) on commit drop;
insert into _links values
{(','+chr(10)).join(f"    ({q(h)}, {q(r)}, {q(c)}, {q(ev)})" for h, r, c, ev in links)};
do $$
declare n int;
begin
  select count(*) into n from _links l join public.hotels h on h.hotel_code = l.hotel_code
    join public.restaurants r on r.restaurant_code = l.restaurant_code
   where r.property_name is null;
  if n <> {len(links)} then raise exception 'links: % of {len(links)} hotel/restaurant pairs resolve', n; end if;
end $$;
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, l.confidence, l.evidence, now()
  from _links l join public.hotels h on h.hotel_code = l.hotel_code join public.restaurants r on r.restaurant_code = l.restaurant_code
on conflict (hotel_id, restaurant_id) do nothing;""")

    post = []
    for cc in ('PL', 'TR'):
        for k in (3, 2, 1):
            post.append(f"""  select count(*) into n from public.restaurants where country_code = '{cc}' and michelin_stars = {k};
  if n <> {exp_r[cc][k]} then raise exception '{cc}: expected {exp_r[cc][k]} {k}-star, found %', n; end if;""")
        for k in (3, 2, 1):
            post.append(f"""  select count(*) into n from public.hotels where country_code = '{cc}' and michelin_keys = {k};
  if n <> {exp_h[cc][k]} then raise exception '{cc}: expected {exp_h[cc][k]} {k}-Key hotels, found %', n; end if;""")
    S.append("""-- 7. post-conditions: MICHELIN's live 2026 selection exactly
do $$
declare n int;
begin
""" + '\n'.join(post) + """
  select count(*) into n from public.restaurants r where r.country_code in ('PL', 'TR')
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current and ah.award_value is not distinct from r.michelin_stars) <> 1;
  if n <> 0 then raise exception '% PL/TR restaurants without exactly one current star row equal to michelin_stars', n; end if;
  select count(*) into n from public.hotels h where h.country_code in ('PL', 'TR') and h.michelin_keys is not null
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% PL/TR Key hotels without exactly one current Key row equal to michelin_keys', n; end if;
  select count(*) into n from public.restaurants r where r.country_code in ('PL', 'TR') and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '% restaurants have both a hotel link and a property_name', n; end if;
end $$;

commit;
""")
    open(os.path.join(HERE, 'prepared_pl_tr_2026.sql'), 'w').write('\n\n'.join(S))

    print('restaurants:', {cc: dict(exp_r[cc]) for cc in exp_r}, 'new', len(rnew), 'fix', rfix, 'fills', len(rfill), 'urls', len(urlfix), 'loc', len(locfix))
    print('hotels:', {cc: dict(exp_h[cc]) for cc in exp_h}, 'new', len(newh), 'fix', kfix)
    print('links', links and [(h, r) for h, r, *_ in links], '| towns', towns)
    print('phones on new', sum(1 for r in rnew if r['phone']), '/', len(rnew), '| websites', sum(1 for r in rnew if r['website']))
    print('report', collections.Counter(r['kind'] for r in report))


if __name__ == '__main__':
    main()
