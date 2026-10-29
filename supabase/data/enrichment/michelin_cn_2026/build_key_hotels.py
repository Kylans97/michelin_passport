#!/usr/bin/env python3
"""Build cn_key_hotels_2026.csv: every mainland China MICHELIN Key hotel (research 2026-10-29).

Usage:
  python3 build_key_hotels.py

Copied from ../michelin_gb_ie_2026/build_key_hotels.py for mainland China.
Reads _source/michelin_cn_hotel_pages_20261029.json (the 54 hotel pages behind
guide.michelin.com/en/hotels-stays/china?distinction=all-keys, JSON-LD read in
a browser; the unfiltered listing has 336) and keeps the pages whose
structured data carries a Key. Checked against 2 / 11 / 41: MICHELIN's 2026
global Key article (18 Sep 2026) gives "Mainland China – 55 Key hotels"
without a split; the 55th is not found (README, QA).

Coordinates: MICHELIN's China hotel pins are GCJ-02 ("Mars coordinates", the
offset datum Chinese map providers are required to use), not WGS-84. Converted
back with the standard inverse (gcj02.py), 18 of 21 Key hotels OpenStreetMap
names land 15-237 m from OSM's point (_source/osm_nominatim_key_hotels_20261029.json;
README "Coordinates"). The raw pin is kept in michelin_lat / michelin_lon.

cn_key_hotel_contacts_research.csv: website/phone research for every Key hotel
not yet in production (rules: _source/research_brief_cn_hotels.md). Only
`confirmed` values are carried; a `group` line (including 400/800 national
hotlines) is not; anything else stays NULL.
"""
import csv, json, os, re, collections
from gcj02 import gcj2wgs

HERE = os.path.dirname(os.path.abspath(__file__))
K = {'One': 1, 'Two': 2, 'Three': 3}
# MICHELIN gives a district as the locality for five hotels; its own addressRegion
# names the municipality the district belongs to (Guangzhou's Tianhe postcode 510623
# is the same as Four Seasons Guangzhou's).
TOWN_FIX = {('Tian He', 'Guangdong Province'): 'Guangzhou', ('Chaoyang', 'Beijing'): 'Beijing',
            ('Dongcheng', 'Beijing'): 'Beijing', ('Pudong', 'Shanghai'): 'Shanghai', ('Huangpu', 'Shanghai'): 'Shanghai'}
HOLD = {}  # confirmed on the site, but not clearly this hotel's own line (filled after review)
EXPECT = (2, 11, 41)


def main():
    pages = json.load(open(os.path.join(HERE, '_source/michelin_cn_hotel_pages_20261029.json')))['pages']
    cpath = os.path.join(HERE, 'cn_key_hotel_contacts_research.csv')
    contacts = {}
    if os.path.exists(cpath):
        for r in csv.DictReader(open(cpath)):
            contacts[r['ref'].replace('new_', '')] = r   # ref: new_<MICHELIN hotel id>
    rows = []
    for p in pages:
        ld = p['ld']
        if not (ld and ld.get('award') and ld['address'].get('addressCountry') == 'CHN'):
            continue
        a = ld['address']
        c = contacts.get(re.search(r'-(\d+)$', p['url']).group(1), {})
        web = c.get('website_url') if c.get('website_certainty') == 'confirmed' else None
        phone = c.get('phone') if c.get('phone_certainty') == 'confirmed' and c.get('line_type') != 'group' and c.get('ref') not in HOLD else None
        glat, glon = ld['geo']['latitude'], ld['geo']['longitude']
        lat, lon = gcj2wgs(glat, glon)
        loc = a.get('addressLocality')
        town = TOWN_FIX.get((loc, a.get('addressRegion')), loc)
        rows.append(dict(
            name=p['h1'], keys=K[ld['award']['awardFor'].split()[0]], city=town, michelin_locality=loc,
            address=', '.join(x for x in (a.get('streetAddress', '').strip(), ' '.join(y for y in (town, (a.get('postalCode') or '').strip()) if y)) if x),
            lat=round(lat, 7), lon=round(lon, 7), michelin_lat=glat, michelin_lon=glon, michelin_url=p['url'],
            michelin_id=re.search(r'-(\d+)$', p['url']).group(1),
            michelin_phone=ld.get('telephone'), website_url=web, phone=phone,
            website_certainty=c.get('website_certainty') or 'not researched',
            phone_certainty=c.get('phone_certainty') or 'not researched',
            line_type=c.get('line_type'), website_source_url=c.get('website_source_url'),
            phone_source_url=c.get('phone_source_url'), notes=' | '.join(x for x in (HOLD.get(c.get('ref')), c.get('notes')) if x)))
    rows.sort(key=lambda r: (-r['keys'], r['name'].lower()))
    cnt = collections.Counter(r['keys'] for r in rows)
    assert (cnt[3], cnt[2], cnt[1]) == EXPECT, cnt
    with open(os.path.join(HERE, 'cn_key_hotels_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    print(len(rows), dict(cnt), 'websites', sum(1 for r in rows if r['website_url']), 'phones', sum(1 for r in rows if r['phone']))


if __name__ == '__main__':
    main()
