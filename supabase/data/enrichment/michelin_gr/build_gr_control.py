#!/usr/bin/env python3
"""Build the Greece pass (research 2026-11-04, SQL approved by the product owner that day).
Reads only _source/. Writes gr_control.csv, gr_new_cities.csv, prepared_gr_2027.sql and
supabase/migrations/<MIGRATION>.

Rules (README.md): identity is MICHELIN's numeric id, never a name; the page's JSON-LD
award decides and must equal the listing card; a hotel page's restaurant list is proximity,
never evidence of a link; phone only when printed on the venue's own site; no Place ID
(no Google access in this session).
"""
import csv, json, math, os, re, collections

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '_source')
MIG_DIR = os.path.normpath(os.path.join(HERE, '../../../migrations'))
MIGRATION = '20261101290000_add_gr_cities.sql'
FIRST_REST, FIRST_HOTEL = 4000, 3000
D = '20261104'
STAR_ANNOUNCED, STAR_YEAR = '2026-10-23', 2027     # MICHELIN press release; pages say dateAwarded 2027
KEY_ANNOUNCED, KEY_YEAR = '2026-09-18', 2026       # global Key article; production's convention
PRESS = 'https://www.michelin.com/en/publications/products-and-services/the-michelin-guide-athens-thessaloniki-santorini-2027'
KEYS_ART = 'https://guide.michelin.com/us/en/article/travel/all-the-key-hotels-in-the-world-michelin-guide'
NEW_STARS = {'Aleria', "Botrini's Santorini", 'Lauda', 'see|ds', 'Selene', 'SENSE', 'Simul', 'Lycabettus'}
CARD = {'ONE_KEY': 1, 'TWO_KEYS': 2, 'THREE_KEYS': 3}
WORD = {'One': 1, 'Two': 2, 'Three': 3}

# restaurant MICHELIN id -> (host hotel's MICHELIN id, evidence). The host holds no Key
# (listing card SELECTED), so rule 3 applies: property_name, no hotel row, no link.
PROPERTY = {
    '1205741': ('13682', "press release: 'Located within the Andronis Luxury Suites'; review: 'part of the Andronis Luxury Suite hotel'"),
    '1205739': ('14635', "review: 'on the elegant terrace of the Andronis Boutique Hotel'; restaurant and hotel page give the same phone"),
    '1206642': ('4121', "review: 'the inner courtyard of the luxurious Margi hotel'; restaurant and hotel page give Litous 11"),
    '569492': ('7925', "review: 'on the rooftop of the AthensWas boutique hotel'; restaurant and hotel page give Dionysiou Areopagitou 5"),
    '1202282': ('12765', "restaurant and hotel page give Mitropoleos 54 and the same phone; the review does not name the hotel"),
}
LINK = {'1196439': ('12274', "review: 'Head to the Four Seasons Astir Palace (three MICHELIN Keys) ... and make a reservation at Pelagos'; "
                             "restaurant and hotel page give Apollonos 40, Vouliagmeni")}
PROPERTY_SITE = {'1185923': ('King George', "tudorhall.gr: 'On the 7th Floor of King George'. MICHELIN's review says only 'a hotel', and King George "
                                            "is not among MICHELIN's 279 Greek hotel cards. Rests on the venue's own site: decision")}
UNRESOLVED = {
    '1205654': "botrinissantorini.com runs under 'Katikies Hotels'; same street as Katikies Santorini - Pelagos House (Key). MICHELIN "
               "does not say the restaurant is in that hotel: no link until confirmed",
    '1205782': "Same address on MICHELIN as Katikies Garden Santorini (Key), 'Old Catholic Monastery'; selene.gr lists Katikies hotels. "
               "MICHELIN does not say the restaurant is in that hotel: no link until confirmed",
}
# Town: MICHELIN's locality, except where it is a region and the address names the place.
TOWN = {'Peloponnese': ('Kastri', "MICHELIN's locality is the region 'Peloponnese'; the address says Kastri"),
        'Thessaly': ('Mouzaki', "MICHELIN's locality is the region 'Thessaly'; the address says Mouzaki")}
HOTEL_NOTE = {
    '13193': '', '14500': "No street on MICHELIN's page: address is postcode and town only. Phone prefix 2834 belongs to Crete, not Mykonos: check",
    '9526': 'Phone prefix 2310 is Thessaloniki, not Chania: probably a head office, check',
    '8780': 'Phone prefix 21 is Athens: probably a head office, check',
    '8244': 'Phone prefix 210 is Athens: probably a head office, check',
    '11958': 'Same phone as Boheme Mykonos Town: check',
    '7577': 'Same phone as NOMAD Mykonos: check',
    '17565': "Postcode 87400 on MICHELIN's page; Santorini is 847xx: probable typo, check",
    '12273': "MICHELIN's street line ends in 'S.A.', a company suffix: check",
    '14513': 'Street is in Greek only on MICHELIN (Κήπος): Latin form to confirm',
    '12613': "Street partly in Greek on MICHELIN. Perdika here is the one in Epirus (pin + postcode 46100), not the one on Aegina",
    '13987': "Street line on MICHELIN only repeats the hotel's name",
    '13403': "Named Andronis Minois by MICHELIN; the page address still ends in 'minois-hotel'",
    '12274': "MICHELIN phone +30 21 0890 1040 differs from the Google record's +30 21 0890 1000 (europe_gaps): held back",
    '14469': 'Same address as Selene (star): see that row',
    '7037': "Same street as Botrini's Santorini (star): see that row",
}


def dist(a, b, c, d):
    p = math.pi / 180
    x = math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2
    return round(12742000 * math.asin(math.sqrt(x)))


def load(n):
    return json.load(open(os.path.join(SRC, n)))


def hid(u):
    return re.search(r'-(\d+)/?$', u.split('?')[0]).group(1)


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


def addr(a):
    a = json.loads(a) if isinstance(a, str) else (a or {})
    street = re.sub(r'\s+', ' ', a.get('streetAddress') or '').strip().rstrip(',')
    pc = (a.get('postalCode') or '').strip()
    loc = (a.get('addressLocality') or '').strip()
    tail = ' '.join(x for x in (pc, loc) if x and x != 'None')
    return ', '.join(x for x in (street, tail) if x), loc, a.get('addressRegion')


def main():
    X = load(f'production_export_{D}.json')
    scards = [r for r in load(f'michelin_star_listing_{D}.json')['rows'] if r['restaurant_country'] == 'gr']
    rpages = {p['url']: p for p in load(f'michelin_restaurant_pages_{D}.json')['pages']}
    sites = {s['url']: s for s in load(f'restaurant_site_checks_{D}.json')}
    hall = [r for r in load(f'michelin_hotel_listing_{D}.json')['rows'] if r['hotel_country'] == 'gr']
    hcards = {r['pid']: r for r in hall if r['distinction'] in CARD}
    hpages = {hid(p['url']): p for p in load(f'michelin_hotel_pages_{D}.json')['pages']}
    ppages = {hid(p['url']): p for p in load(f'michelin_property_hotel_pages_{D}.json')['pages']}
    stored = {hid(h['michelin_url']): h for h in X['hotels']}
    assert len(scards) == 20 and len(hcards) == 74 and not X['restaurants']
    rows, towns = [], collections.Counter()

    hotelrows = []
    for pid, card in sorted(hcards.items(), key=lambda kv: kv[1]['name'].lower()):
        p = hpages[pid]
        ld = p['ld']
        aw = ld['award'] if isinstance(ld['award'], dict) else json.loads(ld['award'])
        keys = WORD[aw['awardFor'].split()[0]]
        assert keys == CARD[card['distinction']], pid
        a, loc, region = addr(ld['address'])
        town, tnote = TOWN.get(loc, (loc, ''))
        town = stored[pid]['city'] if pid in stored else town
        towns[town] += 1
        h = stored.get(pid)
        notes = [x for x in (tnote, HOTEL_NOTE.get(pid, '')) if x]
        if loc == 'Crete':
            notes.append("MICHELIN's locality is the island, kept as the town: decision")
        lat, lon = float(ld['geo']['latitude']), float(ld['geo']['longitude'])
        row = dict(kind='hotel', action='new', name=p['h1'].strip(), award=f'{keys} Key', award_year=KEY_YEAR,
                   announced_on=KEY_ANNOUNCED, michelin_id=pid, michelin_url=p['url'], town=town, michelin_locality=loc,
                   region=region, address=a, lat=lat, lon=lon, michelin_phone=(ld.get('telephone') or '').strip(),
                   phone_status='not written: hotel phones are not checked against an official site in this pass',
                   website_status='MICHELIN hotel pages carry no website link',
                   place_id_status='blank: no Google access (QA-431)',
                   finding=f"{card['distinction']} on the listing, equal to the award on the hotel page; country 'gr'",
                   evidence_source=f'{p["url"]} and /en/hotels-stays/greece, read 2026-11-04; {KEYS_ART} (18 Sep 2026: Greece 74)',
                   confidence='high', match_method='none_new_row', status='proposed')
        if h:
            d = dist(h['lat'], h['lon'], lat, lon)
            assert h['keys'] == keys and h['country'] == 'GR'
            row.update(code=h['code'], action='existing: add missing award row', stored_value=f"{h['keys']} Key",
                       match_method='code_plus_country', google_place_id=h['google_place_id'],
                       place_id_status='stored', website=h['website_url'], website_status='stored',
                       finding=row['finding'] + f"; MICHELIN id equals the stored URL; stored point {d} m from MICHELIN's pin. "
                                                "Stored Keys correct. It has no award_history row at all")
        else:
            near = [c for c, o in hcards.items() if c != pid and o is not None
                    and dist(lat, lon, float(hpages[c]['ld']['geo']['latitude']), float(hpages[c]['ld']['geo']['longitude'])) <= 150]
            if near:
                notes.append('Within 150 m of ' + ', '.join(hpages[c]['h1'].strip() for c in near) + ': separate MICHELIN ids, not a duplicate')
        row['uncertain'] = ' | '.join(notes)
        hotelrows.append(row)
    assert collections.Counter(int(r['award'][0]) for r in hotelrows) == {3: 1, 2: 9, 1: 64}

    for r in hotelrows:
        if not r.get('code'):
            r['code'] = f'hotel_{FIRST_HOTEL + sum(1 for x in hotelrows if x.get("code") and x["action"] == "new")}'

    restrows = []
    for c in sorted(scards, key=lambda r: r['name'].lower()):
        p = rpages[c['url']]
        ld = p['ld']
        aw = ld['award']
        stars = WORD[aw['awardFor'].split()[0]]
        assert str(aw['dateAwarded']) == str(STAR_YEAR) and stars == int(c['distinction'][0]), c['name']
        s = sites[c['url']]
        a, loc, region = addr(ld['address'])
        phone_ok = bool(s.get('phone_on_site') or s.get('phone_on_contact'))
        web_ok = s.get('status') == '200' and s.get('names_venue')
        web = (p['website'] or '').split('?')[0]
        mid = c['michelin_id']
        notes, hotel, prop = [], '', ''
        towns[c['city']] += 1
        lat, lon = float(ld['latitude']), float(ld['longitude'])
        if mid in PROPERTY:
            hp, ev = PROPERTY[mid]
            assert hall and not next(x for x in hall if x['pid'] == hp)['distinction'] in CARD, mid
            g = ppages[hp]['ld']['geo']
            prop = ppages[hp]['h1'].strip()
            notes.append(f"Host hotel holds no Key (MICHELIN card SELECTED, id {hp}), so property_name, no link. {ev}; "
                         f"pins {dist(lat, lon, float(g['latitude']), float(g['longitude']))} m apart")
        elif mid in PROPERTY_SITE:
            prop, ev = PROPERTY_SITE[mid]
            notes.append(ev)
        elif mid in LINK:
            hp, ev = LINK[mid]
            hotel = stored[hp]['code']
            g = hpages[hp]['ld']['geo']
            notes.append(f"Link to {hotel}: {ev}; pins {dist(lat, lon, float(g['latitude']), float(g['longitude']))} m apart")
        elif mid in UNRESOLVED:
            notes.append(UNRESOLVED[mid])
        if not phone_ok:
            notes.append("MICHELIN's phone is not on the venue's own site: left blank")
        if p['website'] != web:
            notes.append('Tracking parameters removed from MICHELIN\'s website link')
        if ld['name'] == 'SENSE':
            notes.append("Not 'Sense' in Vught (NL), which shares the slug in production: different country, id and pin")
        restrows.append(dict(kind='restaurant', code=f'rest_{FIRST_REST + len(restrows)}', action='new', name=ld['name'], award=f'{stars} star', award_year=STAR_YEAR,
                             announced_on=STAR_ANNOUNCED, michelin_id=mid, michelin_url=c['url'], town=c['city'],
                             michelin_locality=loc, region=c['region'], address=a, lat=lat, lon=lon,
                             michelin_cuisine=ld.get('servesCuisine'), michelin_phone=ld.get('telephone'),
                             phone=ld.get('telephone') if phone_ok else '',
                             phone_status='printed on the venue\'s own site' if phone_ok else 'not on the venue\'s own site',
                             website=web if web_ok else '',
                             website_status='MICHELIN link loads and names the restaurant' if web_ok else 'not confirmed',
                             place_id_status='blank: no Google access (QA-431)', hotel_code=hotel, property_name=prop,
                             finding=f"{c['distinction']} on the listing, equal to the page's award (dateAwarded {STAR_YEAR})"
                                     + ('; named as new in the press release' if ld['name'] in NEW_STARS else ''),
                             uncertain=' | '.join(notes),
                             evidence_source=f"{c['url']} and /en/gr/restaurants/all-starred, read 2026-11-04; {PRESS} (23 Oct 2026: 1 two-star, 19 one-star)",
                             confidence='medium' if mid in PROPERTY_SITE or mid in UNRESOLVED else 'high',
                             match_method='none_new_row', status='proposed'))
    assert collections.Counter(int(r['award'][0]) for r in restrows) == {2: 1, 1: 19}
    named = {r['name'] for r in restrows if 'named as new' in r['finding']}
    assert named == NEW_STARS

    held = [
        dict(kind="worlds_50_best_restaurant", action='none', name='(no Greek restaurant)', finding="No Greek city on ranks 1-100 of The World's 50 Best Restaurants as shown on the50.com; the page's captions say 2025",
             uncertain="The page carries no edition heading. Production's latest restaurant year is also 2025. Whether a 2026 list exists was not settled here", evidence_source='https://www.the50.com/restaurants/best-in-the-world/list/1-50, read 2026-11-04',
             confidence='medium', match_method='none_new_row', status='rejected'),
        dict(kind="worlds_50_best_hotel", code='hotel_716', action='verified, unchanged', name='Four Seasons Astir Palace', award='rank 27', award_year=2026,
             finding="The only Greek hotel on ranks 1-100 of the 2026 list. Production holds 2026 rank 27, top_50: correct. No other Greek hotel is in scope through this list",
             uncertain="Production's 2023 rank 35 rests on a secondary aggregator (worlds_50_best_hotels_raw.csv): not re-verified here", evidence_source='https://www.the50.com/hotels/best-in-the-world/list/1-50, read 2026-11-04',
             confidence='high', match_method='code_plus_country', status='proposed'),
        dict(kind='worlds_50_best_history', action='held back', name='Spondi', award='rank 97', award_year=2013,
             finding="An earlier pass parked Spondi 2013 rank 97 as unmatched because Greece had no restaurants (worlds_50_best_history/worlds_50_best_review.csv)",
             uncertain='Source of that row not reopened; add only after checking the 2013 list', evidence_source='worlds_50_best_history/worlds_50_best_review.csv',
             confidence='low', match_method='name_proposed_unconfirmed', status='unresolved'),
    ]
    cols = ['kind', 'code', 'action', 'name', 'award', 'stored_value', 'award_year', 'announced_on', 'michelin_id', 'michelin_url', 'town',
            'michelin_locality', 'region', 'address', 'lat', 'lon', 'michelin_cuisine', 'michelin_phone', 'phone', 'phone_status', 'website',
            'website_status', 'google_place_id', 'place_id_status', 'hotel_code', 'property_name', 'finding', 'uncertain',
            'evidence_source', 'confidence', 'match_method', 'status']
    with open(os.path.join(HERE, 'gr_control.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(restrows + hotelrows + held)
    existing = {c['name'] for c in X['cities']}
    with open(os.path.join(HERE, 'gr_new_cities.csv'), 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['country', 'town', 'rows', 'status'])
        for t, n in sorted(towns.items()):
            w.writerow(['GR', t, n, 'exists' if t in existing else 'new'])
    write_sql(X, restrows, hotelrows, sorted(t for t in towns if t not in existing))
    print('restaurants', len(restrows), 'phones', sum(1 for r in restrows if r['phone']), 'sites', sum(1 for r in restrows if r['website']))
    print('hotels', len(hotelrows), 'towns', len(towns), 'new towns', sum(1 for t in towns if t not in existing))
    print('notes', sum(1 for r in hotelrows if r['uncertain']))
    for r in restrows:
        print(r['name'], '|', r['hotel_code'], '|', r['property_name'], '|', r['uncertain'][:150])


def write_sql(X, rests, hotels, newtowns):
    newh = [r for r in hotels if r['action'] == 'new']
    astir = next(r for r in hotels if r['action'] != 'new')
    links = [(r['hotel_code'], r['code'], next(n for n in r['uncertain'].split(' | ') if n.startswith('Link to')).split(': ', 1)[1]) for r in rests if r['hotel_code']]
    assert len(newh) == 73 and astir['code'] == 'hotel_716' and len(links) == 1
    open(os.path.join(MIG_DIR, MIGRATION), 'w').write(f"""-- MICHELIN Greece: city-only prerequisite for
-- supabase/data/enrichment/michelin_gr/prepared_gr_2027.sql.
-- Written 2026-11-04 by build_gr_control.py from production's read-only export of that day.
-- Filename timestamp is a sequence number only (next after 20261101280000).
-- Towns are MICHELIN's localities, with Kastri and Mouzaki taken from the address where the
-- locality is a region (QA-432). None exists in production's export. region and
-- postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('GR', {q(t)}, NULL)" for t in newtowns) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    S = [f"""-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide Athens, Thessaloniki, Santorini 2027 (announced 23 Oct 2026) and the 2026
-- MICHELIN Key hotels of Greece (global Key article, 18 Sep 2026: Greece 74). Generated by
-- build_gr_control.py; evidence per row in gr_control.csv. QA-430..QA-435.
--
-- Restaurants: {len(rests)} added ({rests[0]['code']}..{rests[-1]['code']}), {sum(1 for r in rests if r['property_name'])} with property_name.
-- Hotels: {len(newh)} Key hotels added ({newh[0]['code']}..{newh[-1]['code']}); {astir['code']} gets its missing Key row.
-- Links: {len(links)}. No Google Place ID is written (no Google access in this pass, QA-431).
--
-- PREREQUISITE: supabase/migrations/{MIGRATION}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

-- 0. production is still the export of {X['exported_at'][:16]} UTC
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'GR';
  if n <> 0 then raise exception 'expected 0 GR restaurants (export), found % -- has this file run?', n; end if;
  select count(*) into n from public.hotels where country_code = 'GR';
  if n <> 1 then raise exception 'expected 1 GR hotel (export), found % -- has this file run?', n; end if;
  if not exists (select 1 from public.hotels where hotel_code = {q(astir['code'])} and name = {q(astir['name'])}
                  and country_code = 'GR' and michelin_keys = 3) then
    raise exception '{astir['code']} no longer matches the export';
  end if;
  if exists (select 1 from public.award_history a join public.hotels h on h.id = a.entity_id
              where a.entity_type = 'hotel' and h.hotel_code = {q(astir['code'])}) then
    raise exception '{astir['code']} has award rows now, the export had none';
  end if;
  if exists (select 1 from public.restaurants where restaurant_code = any(array[{', '.join(q(r['code']) for r in rests)}]))
  then raise exception 'restaurant codes {rests[0]['code']}..{rests[-1]['code']} are no longer free'; end if;
  if exists (select 1 from public.hotels where hotel_code = any(array[{', '.join(q(r['code']) for r in newh)}]))
  then raise exception 'hotel codes {newh[0]['code']}..{newh[-1]['code']} are no longer free'; end if;
end $$;"""]
    S.append(f"""-- 1. Key hotels, each with a current 2026 Key row. Name = page h1; address and pin = page
--    JSON-LD. Phone, website and Place ID left NULL: not confirmed outside MICHELIN (QA-431).
create temp table _newh (code text, name text, keys smallint, city text, address text, lon float8, lat float8,
                        michelin_url text) on commit drop;
insert into _newh values
""" + ',\n'.join(f"    ({q(r['code'])}, {q(r['name'])}, {r['award'][0]}, {q(r['town'])}, {q(r['address'])}, {r['lon']}, {r['lat']}, {q(r['michelin_url'])})" for r in newh) + f""";
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _newh x
   where (select count(*) from public.cities c where c.country_code = 'GR' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _newh x join public.hotels h
    on substring(h.michelin_url from '-([0-9]+)/?$') = substring(x.michelin_url from '-([0-9]+)/?$');
  if bad is not null then raise exception 'hotel already present (MICHELIN id): %', bad; end if;
end $$;
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url)
select x.code, x.name, x.keys,
       (select c.id from public.cities c where c.country_code = 'GR' and c.name = x.city), 'GR',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography, x.michelin_url
  from _newh x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, {KEY_YEAR}, 'michelin_keys', h.michelin_keys, true, date '{KEY_ANNOUNCED}'
  from public.hotels h join _newh x on x.code = h.hotel_code;

-- 2. {astir['code']}: stored Keys are right, but it has no award row (QA-434)
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, {KEY_YEAR}, 'michelin_keys', 3, true, date '{KEY_ANNOUNCED}'
  from public.hotels h where h.hotel_code = {q(astir['code'])};""")
    S.append(f"""-- 3. starred restaurants, each with a current {STAR_YEAR} row. Website = MICHELIN's link, which
--    loads and names the restaurant; phone only when printed on the venue's own site.
create temp table _newr (code text, name text, stars smallint, city text, address text, lon float8, lat float8,
                        michelin_url text, website_url text, phone text, property_name text) on commit drop;
insert into _newr values
""" + ',\n'.join(f"    ({q(r['code'])}, {q(r['name'])}, {r['award'][0]}, {q(r['town'])}, {q(r['address'])}, {r['lon']}, {r['lat']}, {q(r['michelin_url'])}, {q(r['website'])}, {q(r['phone'])}, {q(r['property_name'])})" for r in rests) + f""";
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _newr x
   where (select count(*) from public.cities c where c.country_code = 'GR' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _newr x join public.restaurants r on r.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'already present (michelin_url): %', bad; end if;
end $$;
insert into public.restaurants (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
                                address, location, michelin_url, website_url, phone, property_name)
select x.code, x.name, x.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = 'GR' and c.name = x.city), 'GR',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone, x.property_name
  from _newr x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, {STAR_YEAR}, 'michelin_stars', x.stars, true, date '{STAR_ANNOUNCED}'
  from _newr x join public.restaurants r on r.restaurant_code = x.code;""")
    S.append("""-- 4. link to a hotel in `hotels`, from MICHELIN's own pages
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, 'exact', e.evidence, now()
  from (values """ + ', '.join(f"({q(h)}, {q(r)}, {q(ev)})" for h, r, ev in links) + """) e(hotel_code, restaurant_code, evidence)
  join public.hotels h on h.hotel_code = e.hotel_code
  join public.restaurants r on r.restaurant_code = e.restaurant_code and r.property_name is null;""")
    S.append(f"""-- 5. post-conditions: MICHELIN's live selection exactly
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'GR' and michelin_stars = 3;
  if n <> 0 then raise exception 'expected 0 3-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'GR' and michelin_stars = 2;
  if n <> 1 then raise exception 'expected 1 2-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'GR' and michelin_stars = 1;
  if n <> 19 then raise exception 'expected 19 1-star, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'GR' and michelin_keys = 3;
  if n <> 1 then raise exception 'expected 1 3-Key hotel, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'GR' and michelin_keys = 2;
  if n <> 9 then raise exception 'expected 9 2-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'GR' and michelin_keys = 1;
  if n <> 64 then raise exception 'expected 64 1-Key hotels, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = 'GR'
     and (select count(*) from public.award_history ah where ah.entity_type = 'restaurant' and ah.entity_id = r.id
           and ah.award_type = 'michelin_stars' and ah.is_current and ah.guide_year = {STAR_YEAR}
           and ah.award_value = r.michelin_stars) <> 1;
  if n <> 0 then raise exception '% GR restaurants without exactly one current star row equal to michelin_stars', n; end if;
  select count(*) into n from public.hotels h where h.country_code = 'GR'
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.guide_year = {KEY_YEAR}
           and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% GR hotels without exactly one current Key row equal to michelin_keys', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.restaurants r on r.id = hr.restaurant_id where r.country_code = 'GR';
  if n <> {len(links)} then raise exception 'expected {len(links)} GR link, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = 'GR' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '% restaurants have both a hotel link and a property_name', n; end if;
  select count(*) into n from public.restaurants where country_code = 'GR' and property_name is not null;
  if n <> {sum(1 for r in rests if r['property_name'])} then raise exception 'unexpected property_name count %', n; end if;
end $$;

commit;
""")
    open(os.path.join(HERE, 'prepared_gr_2027.sql'), 'w').write('\n\n'.join(S))


if __name__ == '__main__':
    main()
