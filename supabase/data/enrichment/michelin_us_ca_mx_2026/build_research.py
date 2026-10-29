#!/usr/bin/env python3
"""Build {us,ca,mx}_research_2026.csv from the saved MICHELIN pages (research 2026-10-29).

Usage:
  python3 build_research.py <phone_check.json> [phone_confirmations.csv]

Copied from ../michelin_gb_ie_2026/build_research.py. Differences:
  * one pages file for all three countries
    (_source/michelin_restaurant_pages_20261029.jsonl, every restaurant in
    MICHELIN's USA, Canada and Mexico 1-3 star listings, read 2026-10-29);
  * MICHELIN publishes several guides here, at different times. Each row's
    guide year is the page's own JSON-LD `award.dateAwarded`; the guide (and
    so the announcement date) follows from the page's addressRegion and that
    year, through GUIDES below. A region/year pair not in GUIDES stops the
    build, so nothing is dated by default.

Writes <cc>_research_2026.csv with the GB columns plus guide, guide_year,
announced_on. Place ID columns are left blank: no Places API (QA, README).
"""
import csv, json, os, re, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
STARS = {'Three': 3, 'Two': 2, 'One': 1}
ISO = {'USA': 'us', 'CAN': 'ca', 'MEX': 'mx'}

# (country, guide year, addressRegion) -> (guide, announced_on). Every date is
# from MICHELIN's own article (README "Sources"; saved in _source/).
NORTHEAST = ('New York State', 'Illinois', 'District of Columbia', 'Virginia', 'Maryland', 'Massachusetts', 'Pennsylvania')
SOUTH = ('Georgia', 'Louisiana', 'North Carolina', 'South Carolina', 'Tennessee', 'Alabama', 'Mississippi', 'Kentucky', 'Arkansas')
SOUTHWEST = ('Arizona', 'Nevada', 'New Mexico', 'Utah')
GUIDES = {}
for r in NORTHEAST:
    GUIDES[('us', 2025, r)] = ('MICHELIN Guide Northeast Cities 2025 (New York, Chicago, Washington DC, Boston, Philadelphia)', '2025-11-18')
GUIDES[('us', 2026, 'California')] = ('MICHELIN Guide California 2026', '2026-06-24')
GUIDES[('us', 2026, 'Florida')] = ('MICHELIN Guide Florida 2026', '2026-05-28')
GUIDES[('us', 2026, 'Texas')] = ('MICHELIN Guide Texas 2026', '2026-10-08')
GUIDES[('us', 2026, 'Colorado')] = ('MICHELIN Guide Colorado 2026', '2026-09-14')
for r in SOUTHWEST:
    GUIDES[('us', 2026, r)] = ('MICHELIN Guide American Southwest 2026', '2026-08-26')
for r in SOUTH:
    GUIDES[('us', 2026, r)] = ('MICHELIN Guide American South 2026', '2026-10-21')
GUIDES[('ca', 2026, 'Ontario')] = ('MICHELIN Guide Toronto & Region 2026', '2026-09-22')
GUIDES[('ca', 2026, 'British Columbia')] = ('MICHELIN Guide Vancouver 2026', '2026-10-06')
GUIDES[('ca', 2026, 'Quebec')] = ('MICHELIN Guide Québec 2026', '2026-05-06')
GUIDES[('mx', 2026, None)] = ('MICHELIN Guide Mexico 2026', '2026-05-20')

TOWN_FIX = {}
HOLD = {  # url -> reason: MICHELIN's number confirmed on the site, but not the restaurant's own line
    'https://guide.michelin.com/en/quintana-roo/playa-del-carmen_2068368/restaurant/cocina-de-autor-riviera-maya':
        "the Grand Velas Riviera Maya resort/concierge line (resort FAQ page), not the restaurant's own (the Germany/Italy rule: hotel switchboards are left out)",
}


def guide_of(cc, year, region):
    g = GUIDES.get((cc, year, region)) or GUIDES.get((cc, year, None))
    if not g:
        raise SystemExit(f'no guide for {cc} {year} {region!r} -- add it to GUIDES from MICHELIN\'s own article')
    return g


def main():
    phones = json.load(open(sys.argv[1]))
    byhand = {r['michelin_url']: r for r in csv.DictReader(open(sys.argv[2]))} if len(sys.argv) > 2 else {}
    pages = [json.loads(l) for l in open(os.path.join(HERE, '_source/michelin_restaurant_pages_20261029.jsonl'))]
    cols = ['name', 'stars', 'city', 'region', 'address', 'lat', 'lon', 'michelin_url', 'michelin_id', 'website', 'cuisine',
            'phone', 'phone_source', 'michelin_phone', 'google_phone', 'place_id', 'place_certainty', 'google_name',
            'distance_m', 'record_type', 'business_status', 'place_note', 'stay_hotel_url', 'stay_hotel_name',
            'stay_hotel_key', 'stay_hotel_lat', 'stay_hotel_lon', 'country_override', 'guide', 'guide_year', 'announced_on']
    out = collections.defaultdict(list)
    for p in pages:
        ld, a = p['ld'], p['ld']['address']
        cc = ISO[a['addressCountry']]
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
        year = int(ld['award']['dateAwarded'])
        guide, announced = guide_of(cc, year, a.get('addressRegion'))
        out[cc].append(dict(name=ld['name'], stars=STARS[ld['starRating'].split()[0]], city=town, region=a.get('addressRegion'),
                            address=addr, lat=ld['latitude'], lon=ld['longitude'], michelin_url=p['url'],
                            michelin_id=p['listing']['id'], website=p.get('website'), cuisine=ld.get('servesCuisine'),
                            phone=phone, phone_source=src, michelin_phone=mp, google_phone=None, place_id=None,
                            place_certainty='not searched', google_name=None, distance_m=None, record_type=None,
                            business_status=None, place_note='no Places API access in this session (QA, README)',
                            stay_hotel_url=p.get('stay_hotel_url'), stay_hotel_name=re.sub(r'^Open ', '', p.get('stay_hotel_name') or '') or None,  # aria-label "Open <hotel>"
                            stay_hotel_key=None, stay_hotel_lat=None, stay_hotel_lon=None, country_override=None,
                            guide=guide, guide_year=year, announced_on=announced))
    for cc, rows in out.items():
        rows.sort(key=lambda r: (-r['stars'], r['name'].lower()))
        with open(os.path.join(HERE, f'{cc}_research_2026.csv'), 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
        print(cc, len(rows), 'rows', dict(collections.Counter((r['guide'], r['guide_year'], r['stars']) for r in rows)))


if __name__ == '__main__':
    main()
