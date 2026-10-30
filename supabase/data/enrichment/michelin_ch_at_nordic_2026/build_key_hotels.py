#!/usr/bin/env python3
"""Build <cc>_key_hotels.csv: every MICHELIN Key hotel in Switzerland, Austria and the
Nordic countries (research 2026-10-30).

Usage:
  python3 build_key_hotels.py

Reads _source/michelin_hotel_pages_20261030.json: the page of every hotel whose
card in MICHELIN's country hotel listing (/en/hotels-stays/<country>, every page,
_source/michelin_hotel_listing_20261030.json) carries a Key. Each page's own
JSON-LD `award` decides the Key, not the card. The result is checked against
MICHELIN's 2026 global Key launch article (18 September 2026,
_source/michelin_article_keys_global_2026.txt): Switzerland 89, Austria 72,
Norway 16, Sweden 11, Denmark 9, Iceland 5, Finland 3. MICHELIN files no Key
hotel in the Faroe Islands or Greenland.

Website and phone are NOT researched here (README, QA): MICHELIN's hotel
number is often a booking line, and the Key-hotel contact rules
(../michelin_key_hotel_contacts/) need the hotel's own site, read per hotel.
They stay NULL; michelin_phone is kept in the CSV as a lead only.
"""
import csv, json, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
K = {'One': 1, 'Two': 2, 'Three': 3}
LISTING_CC = {'switzerland': 'ch', 'austria': 'at', 'denmark': 'dk', 'sweden': 'se', 'norway': 'no',
              'finland': 'fi', 'iceland': 'is', 'faroe-islands': 'fo'}
EXPECT = {'ch': 89, 'at': 72, 'no': 16, 'se': 11, 'dk': 9, 'is': 5, 'fi': 3}
# hotel page locality -> production's spelling of the same municipality (export 2026-10-30)
TOWN_FIX = {'Luzern': 'Lucerne', 'Maria Alm': 'Maria Alm am Steinernen Meer'}
# Hotel pages whose locality is a region or the country: the town from MICHELIN's own
# data, where it gives one (QA-367). The rest keep the page's locality, as for Spain
# and the UK (QA-286), and are listed in the README.
TOWN_BY_URL = {
    'https://guide.michelin.com/en/hotels-stays/norway/hotel-continental-7193': ('Oslo',
        "page locality 'Norway'; MICHELIN's 2025 Nordic Key article lists 'Oslo: Hotel Continental'"),
    'https://guide.michelin.com/en/hotels-stays/styria/lieperts-cafe-dinner-rooms-16827': ('Leutschach an der Weinstraße',
        "page locality 'Styria'; same street address (Arnfelser Strasse 2, 8463) as MICHELIN's Lieperts restaurant page, which gives Leutschach an der Weinstraße"),
}


def main():
    pages = {p['url']: p for p in json.load(open(os.path.join(HERE, '_source/michelin_hotel_pages_20261030.json')))['pages']}
    listing = json.load(open(os.path.join(HERE, '_source/michelin_hotel_listing_20261030.json')))['rows']
    out = collections.defaultdict(list)
    for r in listing:
        if 'KEY' not in r[5]:
            continue
        p = pages[r[0]]
        ld = p['ld']
        assert ld and ld.get('award'), r[0]
        a = ld['address']
        keys = K[ld['award']['awardFor'].split()[0]]
        cc = LISTING_CC[r[6]]
        town = TOWN_FIX.get(a.get('addressLocality'), a.get('addressLocality'))
        fix = TOWN_BY_URL.get(r[0])
        if fix:
            town = fix[0]
        out[cc].append(dict(
            name=p['h1'], keys=keys, card_distinction=r[5], city=town,
            address=', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in ((a.get('postalCode') or '').strip(), a.get('addressLocality')) if y)) if x and x.strip()),
            lat=ld['geo']['latitude'], lon=ld['geo']['longitude'], michelin_url=r[0], michelin_id=r[1],
            michelin_phone=ld.get('telephone'), website_url=None, phone=None,
            date_awarded=ld['award'].get('dateAwarded'), address_country=a.get('addressCountry'),
            town_note=fix[1] if fix else None, restaurants=' '.join(p.get('restaurants') or [])))
    for cc, rows in sorted(out.items()):
        rows.sort(key=lambda r: (-r['keys'], r['name'].lower()))
        assert len(rows) == EXPECT[cc], (cc, len(rows))
        with open(os.path.join(HERE, f'{cc}_key_hotels.csv'), 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
        print(cc, len(rows), dict(collections.Counter(r['keys'] for r in rows)),
              'card disagrees:', sum(1 for r in rows if K[{'ONE_KEY': 'One', 'TWO_KEYS': 'Two', 'THREE_KEYS': 'Three'}[r['card_distinction']]] != r['keys']),
              'years', dict(collections.Counter(r['date_awarded'] for r in rows)))


if __name__ == '__main__':
    main()
