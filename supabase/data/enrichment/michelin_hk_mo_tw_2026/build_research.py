#!/usr/bin/env python3
"""Build hk_mo_tw_research_2026.csv from the saved MICHELIN pages (research 2026-10-29).

Usage:
  python3 build_research.py _source/hk_mo_tw_restaurant_phone_check_20261029.json [_source/hk_mo_tw_restaurant_phone_confirmations.csv]

Copied from ../michelin_cn_2026/build_research.py for Hong Kong (HK), Macau (MO)
and Taiwan (TW). Reads _source/michelin_hk_mo_tw_restaurant_pages_20261029.jsonl
(159 pages behind MICHELIN's listings guide.michelin.com/en/{hk,mo,tw}/restaurants/
{3-stars,2-stars,1-star}-michelin: HK 7/13/57, MO 2/6/13, TW 3/9/49), the
automated phone check and, optionally, the by-hand confirmations.

No GCJ-02 offset outside mainland China: MICHELIN's pins and production's agree
(README). Host hotel evidence, in order:
  * MICHELIN's restaurant page "Stay at the hotel" (7 pages);
  * MICHELIN's printed restaurant address naming the hotel (HOSTS below).
Place ID columns are left blank: no Places API access (README, QA).
"""
import csv, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STARS = {'Three': 3, 'Two': 2, 'One': 1}
CC = {'hk': 'HK', 'mo': 'MO', 'tw': 'TW'}
# guide, edition, announcement date (article datePublished = the date in its text)
EDITIONS = {'HK': ('Hong Kong & Macau', 2026, '2026-03-19'), 'MO': ('Hong Kong & Macau', 2026, '2026-03-19'),
            'TW': ('Taiwan', 2026, '2026-07-21')}
# MICHELIN's locality is a district for these; the town is the city it belongs to.
TOWN_FIX = {('TW', 'Hsinchu County'): 'Hsinchu County'}
G = 'https://guide.michelin.com/en/'
# MICHELIN's restaurant address names the hotel. ('key', <MICHELIN hotel id>) = a Key hotel whose own
# MICHELIN page must give the same street address (checked in build_prepared.py);
# ('hotel', <hotel_code>) = a non-Key hotel already in `hotels` (World's 50 Best), checked by street;
# ('property', <name>) = a hotel not in `hotels`, written as MICHELIN's address prints it.
HOSTS = {
    # Hong Kong
    'sushi-shikon': ('key', '6201'), 'kappo-rin': ('key', '6201'),
    'caprice': ('key', '7373'), 'lung-king-heen': ('key', '7373'), 'noi-1204599': ('key', '7373'),
    'tin-lung-heen': ('key', '10469'), 'tosca352519': ('key', '10469'),
    'run': ('key', '11783'), 'l-envol': ('key', '11783'),
    'gaddi-s': ('key', '5650'), 'spring-moon': ('key', '5650'),
    'chaat': ('key', '9412'), 'the-legacy-house': ('key', '9412'),
    'man-wah': ('key', '6202'),
    'ta-vie': ('property', 'The Pottinger Hotel'), 't-ang-court': ('property', 'The Langham Hotel'),
    'lai-ching-heen': ('property', 'Regent'), 'man-ho': ('property', 'JW Marriott Hotel'),
    'summer-palace': ('property', 'Island Shangri-La Hotel'), 'petrus': ('property', 'Island Shangri-La Hotel'),
    'seventh-son': ('property', 'The Wharney Hotel'), 'shang-palace': ('property', 'Kowloon Shangri-La Hotel'),
    'yat-tung-heen-jordan': ('property', 'Eaton Hotel'),
    # Macau
    'alain-ducasse-at-morpheus': ('key', '10491'), 'the-huaiyang-garden': ('key', '13340'),
    'lai-heen': ('key', '10482'), 'don-alfonso-1890-1212351': ('key', '14369'), 'zi-yat-heen': ('key', '7351'),
    'zuicho-1214683': ('key', '13285'), 'palace-garden': ('key', '13287'),
    'chef-tam-s-seasons': ('hotel', 'hotel_798'), 'mizumi-1215974': ('hotel', 'hotel_798'),
    'robuchon-au-dome': ('property', 'Grand Lisboa Hotel'), 'the-eight': ('property', 'Grand Lisboa Hotel'),
    'feng-wei-ju': ('property', 'StarWorld Hotel'), 'wing-lei': ('property', 'Wynn Hotel'),
    'ying': ('property', 'Altira Hotel'), 'sushi-kissho-by-miyakawa': ('property', 'Raffles'),
    'sushi-kinetsu': ('property', 'Nüwa'),
    # Taiwan
    'mizue': ('key', '15366'),
    'circum': ('property', 'Regent Hotel'), 'molino-de-urdaniz': ('property', 'Hotel MVSA'),
    'mipon': ('property', 'Grand Mayfull Hotel'),
}
# Confirmed by hand on the official site, but not clearly the restaurant's own single line.
HOLD = {
    'https://guide.michelin.com/en/hong-kong-region/hong-kong/restaurant/sushi-wadatsumi-1197866': "the site prints MICHELIN's number beside the address and a different one (+852 2619 0119) as its 'inquiries by phone' link",
    'https://guide.michelin.com/en/taipei-region/taipei/restaurant/tien-hsiang-lo': "the Shangri-La's Far Eastern Plaza Hotel switchboard (the Germany/Italy rule: switchboards are left out)",
}
# MICHELIN "Stay at the hotel" for a non-Key hotel -> property_name as MICHELIN names it.
STAY_KEY = {'7573', '6201'}   # Mandarin Oriental Taipei, Mandarin Oriental The Landmark: Key hotels


def main():
    phones = json.load(open(sys.argv[1]))
    byhand = {r['michelin_url']: r for r in csv.DictReader(open(sys.argv[2]))} if len(sys.argv) > 2 else {}
    pages = [json.loads(l) for l in open(os.path.join(HERE, '_source/michelin_hk_mo_tw_restaurant_pages_20261029.jsonl'))]
    cols = ['country', 'name', 'stars', 'city', 'selection', 'guide_year', 'announced_on', 'address', 'lat', 'lon', 'coord_note',
            'michelin_url', 'michelin_id', 'website', 'cuisine', 'phone', 'phone_source', 'michelin_phone',
            'place_id', 'place_certainty', 'place_note', 'host_kind', 'host', 'host_evidence', 'date_awarded']
    rows, used_hosts = [], set()
    for p in pages:
        ld, a = p['ld'], p['ld']['address']
        cc = CC[p['listing'][9]]
        sel, year, ann = EDITIONS[cc]
        assert str(year) == ld['award']['dateAwarded'], (p['url'], ld['award'])
        town = TOWN_FIX.get((cc, a['addressLocality']), a['addressLocality'])
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
        elif mp and not p.get('website'):
            phone, src = None, 'MICHELIN only; MICHELIN links no official site -- held back'
        elif mp:
            phone, src = None, ('MICHELIN only; official site unreachable' if not chk.get('bytes') else 'MICHELIN only; not found on official site') + ' -- held back'
        else:
            phone, src = None, 'MICHELIN prints no phone'
        slug = p['url'].split('/restaurant/')[1]
        host = HOSTS.get(slug)
        ev = None
        if p.get('stay') and p['stay'].get('url'):
            sid = p['stay']['url'].rsplit('-', 1)[1]
            if sid in STAY_KEY:
                host, ev = ('key', sid), f"MICHELIN restaurant page 'Stay at the hotel' -> {p['stay']['url']}"
            else:
                host, ev = ('property', p['stay']['name']), f"MICHELIN restaurant page 'Stay at the hotel' -> {p['stay']['url']} (no Key)"
        if host and not ev:
            ev = 'MICHELIN restaurant address'
            used_hosts.add(slug)
        rows.append(dict(country=cc, name=ld['name'], stars=STARS[ld['starRating'].split()[0]], city=town, selection=sel,
                         guide_year=year, announced_on=ann, address=addr, lat=ld['latitude'], lon=ld['longitude'], coord_note=None,
                         michelin_url=p['url'], michelin_id=p['listing'][0], website=p.get('website'),
                         cuisine=ld.get('servesCuisine'), phone=phone, phone_source=src, michelin_phone=mp,
                         place_id=None, place_certainty='not searched',
                         place_note='no Places API access in this session (QA, README)',
                         host_kind=host and host[0], host=host and host[1], host_evidence=ev, date_awarded=ld['award']['dateAwarded']))
    missing = set(HOSTS) - used_hosts
    assert not missing, missing
    rows.sort(key=lambda r: (r['country'], -r['stars'], r['name'].lower()))
    with open(os.path.join(HERE, 'hk_mo_tw_research_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
    print(len(rows), 'rows;', sum(1 for r in rows if r['phone']), 'phones;', sum(1 for r in rows if r['host_kind']), 'hosts')


if __name__ == '__main__':
    main()
