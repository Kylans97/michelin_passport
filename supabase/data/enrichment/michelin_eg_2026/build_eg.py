#!/usr/bin/env python3
"""Build the Egypt Key hotel pass (research 2026-11-04): writes eg_key_hotels_2026.csv,
prepared_eg_2026.sql and the migration from _source/. Egypt has no MICHELIN star listing
(/en/eg/restaurants/all-starred gives 404); production held no Egyptian row of any kind.
The global Key article of 18 Sep 2026 gives "Egypt – 13 Key hotels".
"""
import csv, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '_source')
MIGRATION = '20261101370000_add_eg_2026_country_and_cities.sql'
MIG = os.path.normpath(os.path.join(HERE, '../../../migrations', MIGRATION))
FIRST = 3121
CARD = {'ONE_KEY': 1, 'TWO_KEYS': 2, 'THREE_KEYS': 3}
ANNOUNCED = '2026-09-18'


def q(v):
    return 'NULL' if v in (None, '') else "'" + str(v).replace("'", "''") + "'"


def hid(u):
    return re.search(r'-(\d+)/?$', u).group(1)


def main():
    cards = [r for r in json.load(open(os.path.join(SRC, 'michelin_hotel_listing_20261104.json')))['rows']
             if r['hotel_country'] == 'eg' and r['distinction'] in CARD]
    pages = {hid(p['url']): p for p in json.load(open(os.path.join(SRC, 'michelin_hotel_pages_20261104.json')))['pages']}
    assert len(cards) == 13 and len(pages) == 13
    rows = []
    for i, c in enumerate(sorted(cards, key=lambda c: c['name'].lower())):
        p = pages[c['pid']]
        ld = p['ld']
        aw = json.loads(ld['award']) if isinstance(ld['award'], str) else ld['award']
        keys = {'One': 1, 'Two': 2, 'Three': 3}[aw['awardFor'].split()[0]]
        assert p['status'] == 200 and keys == CARD[c['distinction']], c
        a = json.loads(ld['address']) if isinstance(ld['address'], str) else ld['address']
        pc = (a.get('postalCode') or '').strip()
        pc = '' if pc in ('None', '99999') else pc      # 99999 on the St. Regis is a placeholder
        loc = a['addressLocality'].strip()
        street = re.sub(r'\s+', ' ', a['streetAddress']).strip().rstrip(',')
        tel = ld.get('telephone') or ''
        note = []
        if tel.startswith('http'):
            note.append("MICHELIN's telephone field holds a URL")
            tel = ''
        if (a.get('postalCode') or '') == '99999':
            note.append("MICHELIN's postal code 99999 is a placeholder, left out")
        rows.append(dict(country='EG', code=f'hotel_{FIRST + i}', action='new', name=p['h1'], keys=keys, card=c['distinction'], michelin_id=c['pid'],
                         michelin_url=p['url'], town=loc, address=', '.join(x for x in (street, ' '.join(y for y in (pc, loc) if y)) if x),
                         lat=ld['geo']['latitude'], lon=ld['geo']['longitude'], michelin_phone=tel, guide_year=2026, announced_on=ANNOUNCED,
                         note='; '.join(note)))
    with open(os.path.join(HERE, 'eg_key_hotels_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    towns = sorted({r['town'] for r in rows})
    open(MIG, 'w').write(f"""-- MICHELIN Key hotels in Egypt: country and city prerequisite for
-- supabase/data/enrichment/michelin_eg_2026/prepared_eg_2026.sql.
-- Written 2026-11-04 by build_eg.py from MICHELIN's hotel pages of that day.
-- Filename timestamp is a sequence number only (next after 20261101360000).
-- Production has no `countries` row for EG and no EG city (read 2026-11-04). Africa/Cairo is in
-- production's pg_timezone_names (read that day). Towns are the hotel page's locality, MICHELIN's
-- spelling. region and postal_municipality NULL, as the existing rows.
-- Idempotent: ON CONFLICT targets countries_pkey and cities_unique_key.

begin;

insert into public.countries (country_code, name, flag_emoji, timezones)
values ('EG', 'Egypt', '🇪🇬', array['Africa/Cairo'])
on conflict (country_code) do nothing;

insert into public.cities (country_code, name, region)
values
""" + ',\n'.join(f"  ('EG', {q(t)}, NULL)" for t in towns) + """
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
""")
    vals = ',\n'.join(f"    ({q(r['code'])}, {q(r['name'])}, {r['keys']}, {q(r['town'])}, {q(r['address'])}, {r['lon']}, {r['lat']}, {q(r['michelin_url'])})" for r in rows)
    open(os.path.join(HERE, 'prepared_eg_2026.sql'), 'w').write(f"""-- MICHELIN Key hotels in Egypt, read 2026-11-04: 13 hotels ({rows[0]['code']}..{rows[-1]['code']}), each with a current
-- 2026 Key row, announced 2026-09-18 (global Key article: "Egypt – 13 Key hotels"). Evidence in eg_key_hotels_2026.csv.
-- Name = page h1; address and pin = page JSON-LD. Phone, website and Place ID NULL: none confirmable outside
-- MICHELIN in this pass (QA-460). No restaurant, link or property_name is written.
-- PREREQUISITE: supabase/migrations/{MIGRATION}.
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

create temp table _newh (code text, name text, keys smallint, city text, address text, lon float8, lat float8, michelin_url text) on commit drop;
insert into _newh values
{vals};

do $$
declare n int; bad text;
begin
  select count(*) into n from public.countries where country_code = 'EG';
  if n <> 1 then raise exception 'no EG country (run the migration first?)'; end if;
  select count(*) into n from public.hotels where country_code = 'EG';
  if n <> 0 then raise exception 'expected no EG hotels, found % -- production changed or this file has run', n; end if;
  select string_agg(x.code, ', ') into bad from _newh x join public.hotels h on h.hotel_code = x.code;
  if bad is not null then raise exception 'hotel codes no longer free: %', bad; end if;
  select string_agg(x.name, ', ') into bad from _newh x join public.hotels h
    on substring(h.michelin_url from '-([0-9]+)/?$') = substring(x.michelin_url from '-([0-9]+)/?$');
  if bad is not null then raise exception 'hotel already present (MICHELIN id): %', bad; end if;
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _newh x
   where (select count(*) from public.cities c where c.country_code = 'EG' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one row: %', bad; end if;
end $$;

insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url)
select x.code, x.name, x.keys, (select c.id from public.cities c where c.country_code = 'EG' and c.name = x.city), 'EG',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography, x.michelin_url
  from _newh x;
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED}'
  from public.hotels h join _newh x on x.code = h.hotel_code;

do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = 'EG' and michelin_keys = 2;
  if n <> 2 then raise exception 'expected 2 two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'EG' and michelin_keys = 1;
  if n <> 11 then raise exception 'expected 11 one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = 'EG'
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% hotels without exactly one current Key row', n; end if;
end $$;

commit;
""")
    print(len(rows), rows[0]['code'], rows[-1]['code'], towns)


if __name__ == '__main__':
    main()
