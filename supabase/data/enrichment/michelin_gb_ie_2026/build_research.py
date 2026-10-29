#!/usr/bin/env python3
"""Build {gb,ie}_research_2026.csv from the saved MICHELIN pages (research 2026-10-29).

Usage:
  python3 build_research_gb.py gb <phone_check.json> [phone_confirmations.csv]
  python3 build_research_gb.py ie <phone_check.json> [phone_confirmations.csv]

Reads the country's saved MICHELIN restaurant pages and listing
(gb: _source/michelin_gb_restaurant_pages_20261029.jsonl, 198 pages, MICHELIN's
United Kingdom listing 10/23/165; ie: _source/michelin_ie_restaurant_pages_20261029.jsonl,
23 pages, 0/5/18), the automated phone check (each MICHELIN number searched
for on the venue's own website, home page plus up to four contact/booking/about
pages on the same host, fetched 2026-10-29) and, optionally, the by-hand
confirmations for the rows that check missed (_source/research_brief_uk_restaurant_phones.md).

Writes <cc>_research_2026.csv with the same columns as
../michelin_de_stars/de_research_2026.csv, so build_prepared_gb.py can follow
build_prepared_de_it.py. Place ID columns are left blank: this session had no
Places API access (see README.md, QA ids there).
"""
import csv, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STARS = {'Three': 3, 'Two': 2, 'One': 1}
# MICHELIN's addressLocality for two cities is the council area, not the town.
TOWN_FIX = {'Glasgow City': 'Glasgow', 'City of Bristol': 'Bristol', 'Dublin City': 'Dublin', 'Galway City': 'Galway'}
# Confirmed on the official site, but a switchboard / building line rather than
# the restaurant's own (the Germany/Italy rule: hotel switchboards are left out).
HOLD = {
    'https://guide.michelin.com/en/kildare/maynooth/restaurant/the-morrison-room': 'the Carton House hotel switchboard, which the restaurant page gives for reservations',
    'https://guide.michelin.com/en/greater-london/london/restaurant/cycene': "printed only on Blue Mountain School's about page as the building's general number",
}
FILES = {'gb': ('_source/michelin_gb_restaurant_pages_20261029.jsonl', '_source/michelin_gb_listing_20261029.json'),
         'ie': ('_source/michelin_ie_restaurant_pages_20261029.jsonl', '_source/michelin_ie_listing_20261029.json')}
# Crown Dependencies MICHELIN files under its United Kingdom listing; they are
# not part of the UK and production has no GG/JE country row.
CROWN_DEPENDENCY_REGIONS = {'Guernsey': 'GG', 'Saint Helier': 'JE'}


def main():
    cc = sys.argv[1]
    phones = json.load(open(sys.argv[2]))
    byhand = {r['michelin_url']: r for r in csv.DictReader(open(sys.argv[3]))} if len(sys.argv) > 3 else {}
    pages = [json.loads(l) for l in open(os.path.join(HERE, FILES[cc][0]))]
    ids = {r[0]: r[1] for r in json.load(open(os.path.join(HERE, FILES[cc][1])))['rows']}
    cols = ['name', 'stars', 'city', 'region', 'address', 'lat', 'lon', 'michelin_url', 'michelin_id', 'website', 'cuisine',
            'phone', 'phone_source', 'michelin_phone', 'google_phone', 'place_id', 'place_certainty', 'google_name',
            'distance_m', 'record_type', 'business_status', 'place_note', 'stay_hotel_url', 'stay_hotel_name',
            'stay_hotel_key', 'stay_hotel_lat', 'stay_hotel_lon', 'country_override']
    rows = []
    for p in pages:
        ld, a = p['ld'], p['ld']['address']
        town = TOWN_FIX.get(a['addressLocality'], a['addressLocality'])
        addr = ', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in (town, a.get('postalCode')) if y)) if x) or None
        mp = ld.get('telephone')
        chk = phones.get(p['url'], {})
        bh = byhand.get(p['url'], {})
        if p['url'] in HOLD:
            phone, src = None, 'MICHELIN number on official site, but ' + HOLD[p['url']] + ' -- held back'
        elif mp and chk.get('hit'):
            phone, src = mp, 'MICHELIN, on official site'
        elif bh.get('certainty') == 'confirmed' and bh.get('phone'):
            phone, src = bh['phone'], 'MICHELIN, on official site (checked by hand: ' + (bh.get('phone_source_url') or '') + ')'
        elif bh.get('certainty') == 'site_only' and bh.get('phone') and not mp:
            phone, src = bh['phone'], 'MICHELIN prints none; official site (' + (bh.get('phone_source_url') or '') + ')'
        elif bh.get('certainty') == 'differs':
            phone, src = None, f"official site prints {bh.get('phone')}, MICHELIN {mp} -- held back for a decision"
        elif mp:
            phone, src = None, ('MICHELIN only; official site unreachable' if not chk.get('bytes') else 'MICHELIN only; not found on official site') + ' -- held back'
        else:
            phone, src = None, 'MICHELIN prints no phone'
        rows.append(dict(name=ld['name'], stars=STARS[ld['starRating'].split()[0]], city=town, region=a.get('addressRegion'),
                         address=addr, lat=ld['latitude'], lon=ld['longitude'], michelin_url=p['url'],
                         michelin_id=ids[p['url']], website=p.get('website'), cuisine=ld.get('servesCuisine'),
                         phone=phone, phone_source=src, michelin_phone=mp, google_phone=None, place_id=None,
                         place_certainty='not searched', google_name=None, distance_m=None, record_type=None,
                         business_status=None, place_note='no Places API access in this session (QA, README)',
                         stay_hotel_url=p.get('stay_hotel_url'), stay_hotel_name=p.get('stay_hotel_name'),
                         stay_hotel_key=None, stay_hotel_lat=None, stay_hotel_lon=None,
                         country_override=CROWN_DEPENDENCY_REGIONS.get(a.get('addressRegion'))))
    rows.sort(key=lambda r: (-r['stars'], r['name'].lower()))
    with open(os.path.join(HERE, f'{cc}_research_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
    print(len(rows), 'rows')


if __name__ == '__main__':
    main()
