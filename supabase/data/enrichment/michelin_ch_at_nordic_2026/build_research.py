#!/usr/bin/env python3
"""Build <cc>_research.csv from the saved MICHELIN pages (research 2026-10-30).

Usage:
  python3 build_research.py <phone_check.json> [phone_confirmations.csv]

Reads _source/michelin_restaurant_pages_20261030.jsonl (every restaurant page
behind MICHELIN's Switzerland, Austria, Denmark, Sweden, Norway, Finland and
Iceland star listings, _source/michelin_listing_20261030.json), the automated
phone check (each MICHELIN number searched for on the venue's own website, home
page plus up to four contact/booking/about pages on the same host, fetched
2026-10-30) and, optionally, by-hand confirmations for the rows that check
missed.

Writes one <cc>_research.csv per country (ch, at, dk, fo, se, no, fi, is) with
the columns of ../michelin_gb_ie_2026/gb_research_2026.csv, so build_prepared.py
can follow ../michelin_gb_ie_2026/build_prepared.py. The country is the page's
JSON-LD addressCountry, not the listing it was found in: MICHELIN files PAZ
(Torshavn, Faroe Islands) under its Denmark listing. Place ID columns are left
blank: no Places API access in this session (README).
"""
import csv, json, os, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
STARS = {'Three': 3, 'Two': 2, 'One': 1}
ISO3 = {'CHE': 'ch', 'AUT': 'at', 'DNK': 'dk', 'FRO': 'fo', 'SWE': 'se', 'NOR': 'no', 'FIN': 'fi', 'ISL': 'is'}
# MICHELIN's addressRegion when addressCountry is absent or the parent state's.
REGION_COUNTRY = {'Faroe Islands': 'fo'}
# Confirmed on the official site, but a switchboard / building line rather than
# the restaurant's own (the Germany/Italy rule: hotel switchboards are left out).
HOLD = {
    'https://guide.michelin.com/en/karnten/weissensee_1047660/restaurant/rouge-noir': 'printed only in the /kontakt page\'s meta description, not on the visible page (by-hand check 2026-10-30)',
}
# MICHELIN listing town -> the spelling production already holds for the same
# municipality (compared with the 2026-10-30 export). Every other new town keeps
# MICHELIN's listing name. Maria Alm's municipality is Maria Alm am Steinernen Meer.
TOWN_FIX = {'Berne': 'Bern', 'Saint Moritz': 'St. Moritz', 'Sankt Gallen': 'St. Gallen',
            'Sankt Anton am Arlberg': 'St. Anton am Arlberg', 'Sankt Veit im Pongau': 'St. Veit im Pongau',
            'Maria Alm': 'Maria Alm am Steinernen Meer'}
COLS = ['name', 'stars', 'city', 'region', 'address', 'lat', 'lon', 'michelin_url', 'michelin_id', 'website', 'cuisine',
        'phone', 'phone_source', 'michelin_phone', 'google_phone', 'place_id', 'place_certainty', 'google_name',
        'distance_m', 'record_type', 'business_status', 'place_note', 'stay_hotel_url', 'stay_hotel_name',
        'stay_hotel_key', 'stay_hotel_lat', 'stay_hotel_lon', 'country_override', 'date_awarded', 'listing_country']


def main():
    phones = json.load(open(sys.argv[1]))
    byhand = {r['michelin_url']: r for r in csv.DictReader(open(sys.argv[2]))} if len(sys.argv) > 2 else {}
    pages = [json.loads(l) for l in open(os.path.join(HERE, '_source/michelin_restaurant_pages_20261030.jsonl'))]
    listing = {r[0]: r for r in json.load(open(os.path.join(HERE, '_source/michelin_listing_20261030.json')))['rows']}
    out = collections.defaultdict(list)
    for p in pages:
        ld, a = p['ld'], p['ld']['address']
        lr = listing[p['url']]
        cc = REGION_COUNTRY.get(a.get('addressRegion')) or ISO3.get(a.get('addressCountry')) or lr[11]
        # Town: MICHELIN's English listing name (Zurich, Geneva, Vienna, Copenhagen), as
        # production writes towns and as Germany/Italy did; the address keeps the
        # page's own locality (Zürich, Wien, København), as production's addresses do.
        town = TOWN_FIX.get(lr[4], lr[4])
        addr = ', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in (a.get('postalCode'), a.get('addressLocality')) if y)) if x) or None
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
        out[cc].append(dict(name=ld['name'], stars=STARS[ld['starRating'].split()[0]], city=town, region=a.get('addressRegion'),
                            address=addr, lat=ld['latitude'], lon=ld['longitude'], michelin_url=p['url'],
                            michelin_id=lr[1], website=p.get('website'), cuisine=ld.get('servesCuisine'),
                            phone=phone, phone_source=src, michelin_phone=mp, google_phone=None, place_id=None,
                            place_certainty='not searched', google_name=None, distance_m=None, record_type=None,
                            business_status=None, place_note='no Places API access in this session (README)',
                            stay_hotel_url=p.get('stay_hotel_url'), stay_hotel_name=p.get('stay_hotel_name'),
                            stay_hotel_key=None, stay_hotel_lat=None, stay_hotel_lon=None, country_override=None,
                            date_awarded=(ld.get('award') or {}).get('dateAwarded'), listing_country=lr[11]))
    for cc, rows in sorted(out.items()):
        rows.sort(key=lambda r: (-r['stars'], r['name'].lower()))
        with open(os.path.join(HERE, f'{cc}_research.csv'), 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=COLS); w.writeheader(); w.writerows(rows)
        print(cc, len(rows), dict(collections.Counter(r['stars'] for r in rows)), 'phones', sum(1 for r in rows if r['phone']),
              'years', dict(collections.Counter(r['date_awarded'] for r in rows)))


if __name__ == '__main__':
    main()
