#!/usr/bin/env python3
"""Build hk_mo_tw_key_hotels_2026.csv: every Hong Kong, Macau and Taiwan MICHELIN Key hotel (research 2026-10-29).

Usage:
  python3 build_key_hotels.py

Copied from ../michelin_cn_2026/build_key_hotels.py. Reads
_source/michelin_hk_mo_tw_hotel_pages_20261029.json: the pages behind
guide.michelin.com/en/hotels-stays/{hong-kong,macau,taiwan}?distinction=all-keys
(HK "and surroundings" 16, of which 6 are Shenzhen and belong to the CN pass;
MO 9; TW 8), JSON-LD read in a browser, and keeps the non-mainland pages
whose structured data carries a Key: HK 1/4/5, MO 1/4/4, TW 0/1/7.
MICHELIN's 2026 global Key article (18 Sep 2026) gives HK 9, MO 9, TW 8;
the live HK listing has 10 (README, QA).

No coordinate conversion: outside mainland China MICHELIN's hotel pins agree
with production's points (2-133 m for the 5 existing HK hotels).

hk_mo_tw_key_hotel_contacts_research.csv: website/phone research for every Key
hotel not yet in production (rules: _source/research_brief_hk_mo_tw_hotels.md).
Only `confirmed` values are carried; a `group` line is not.
"""
import csv, json, os, re, collections

HERE = os.path.dirname(os.path.abspath(__file__))
K = {'One': 1, 'Two': 2, 'Three': 3}
ISO = {'HKG': 'HK', 'MAC': 'MO', 'TWN': 'TW'}
# Listing a hotel page came from decides the country where its JSON-LD omits addressCountry.
LISTING = {'hk': 'HK', 'mo': 'MO', 'tw': 'TW'}
# MICHELIN's hotel locality is sometimes a district or an island/peninsula; the town is the one
# MICHELIN's restaurant pages use for the same place (Hong Kong, Macau) or the city the
# district belongs to (addressRegion Taipei; "Kaohsiung City" / "Taichung City").
TOWN_FIX = {('HK', 'Hong Kong Island'): 'Hong Kong', ('HK', 'Kowloon'): 'Hong Kong', ('MO', 'Cotai'): 'Macau',
            ('TW', 'Da’an District'): 'Taipei', ('TW', 'Songshan District'): 'Taipei',
            ('TW', 'Kaohsiung City'): 'Kaohsiung', ('TW', 'Taichung City'): 'Taichung'}
HOLD = {  # confirmed on the site, but not clearly the hotel's own general line
    'new_11207': "Hoshinoya Guguan: the site's only local number is labelled 'Night/Emergency'; bookings go through Hoshino Resorts' Japanese reservation centre",
}
EXPECT = {'HK': (1, 4, 5), 'MO': (1, 4, 4), 'TW': (0, 1, 7)}


def main():
    src = json.load(open(os.path.join(HERE, '_source/michelin_hk_mo_tw_hotel_pages_20261029.json')))
    origin = {u: LISTING[cc] for cc, us in src['listings'].items() for u in us}
    cpath = os.path.join(HERE, 'hk_mo_tw_key_hotel_contacts_research.csv')
    contacts = {}
    if os.path.exists(cpath):
        for r in csv.DictReader(open(cpath)):
            contacts[r['ref'].replace('new_', '')] = r   # ref: new_<MICHELIN hotel id>
    rows = []
    for p in src['pages']:
        ld = p['ld']
        if not (ld and ld.get('award')):
            continue
        a = ld['address']
        cc = ISO.get(a.get('addressCountry')) or origin[p['url'].replace('https://guide.michelin.com', '')]
        if a.get('addressCountry') == 'CHN':
            continue   # Shenzhen, in "Hong Kong SAR and surroundings": the CN pass
        mid = re.search(r'-(\d+)$', p['url']).group(1)
        c = contacts.get(mid, {})
        web = c.get('website_url') if c.get('website_certainty') == 'confirmed' else None
        phone = c.get('phone') if c.get('phone_certainty') == 'confirmed' and c.get('line_type') != 'group' and c.get('ref') not in HOLD else None
        loc = a.get('addressLocality')
        town = TOWN_FIX.get((cc, loc), loc)
        street = (a.get('streetAddress') or '').strip().rstrip(',')
        rows.append(dict(
            country=cc, name=p['h1'], keys=K[ld['award']['awardFor'].split()[0]], city=town, michelin_locality=loc,
            address=', '.join(x for x in (street, ' '.join(y for y in (town, (a.get('postalCode') or '').strip()) if y)) if x),
            street=street, lat=ld['geo']['latitude'], lon=ld['geo']['longitude'], michelin_url=p['url'], michelin_id=mid,
            michelin_phone=ld.get('telephone'), website_url=web, phone=phone,
            website_certainty=c.get('website_certainty') or 'not researched',
            phone_certainty=c.get('phone_certainty') or 'not researched',
            line_type=c.get('line_type'), website_source_url=c.get('website_source_url'),
            phone_source_url=c.get('phone_source_url'), notes=' | '.join(x for x in (HOLD.get(c.get('ref')), c.get('notes')) if x)))
    rows.sort(key=lambda r: (r['country'], -r['keys'], r['name'].lower()))
    for cc, exp in EXPECT.items():
        cnt = collections.Counter(r['keys'] for r in rows if r['country'] == cc)
        assert (cnt[3], cnt[2], cnt[1]) == exp, (cc, cnt)
    with open(os.path.join(HERE, 'hk_mo_tw_key_hotels_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    print(len(rows), {cc: dict(collections.Counter(r['keys'] for r in rows if r['country'] == cc)) for cc in EXPECT},
          'websites', sum(1 for r in rows if r['website_url']), 'phones', sum(1 for r in rows if r['phone']))


if __name__ == '__main__':
    main()
