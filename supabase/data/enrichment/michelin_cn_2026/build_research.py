#!/usr/bin/env python3
"""Build cn_research_2026.csv from the saved MICHELIN pages (research 2026-10-29).

Usage:
  python3 build_research.py _source/cn_restaurant_phone_check_20261029.json [_source/cn_restaurant_phone_confirmations.csv]

Copied from ../michelin_gb_ie_2026/build_research.py for mainland China.
Reads _source/michelin_cn_restaurant_pages_20261029.jsonl (159 pages behind
MICHELIN's "Chinese Mainland" listing, 4/24/131), the automated phone check
(MICHELIN's number searched for on the venue's own site, home page plus up to
four contact-like pages, fetched 2026-10-29) and, optionally, the by-hand
confirmations for the rows that check missed (_source/research_brief_cn_restaurant_phones.md).

China-specific (README "Coordinates"):
  * MICHELIN's restaurant pins are WGS-84 (the datum PostGIS SRID 4326 and the
    app's OpenStreetMap tiles use); they are kept as printed, except
  * COORD_FIX: three restaurants inside a Key hotel whose MICHELIN pin is more
    than 300 m from that hotel, where the hotel's own point is confirmed by
    OpenStreetMap; they take the hotel's point (the Gravetye precedent, QA-285).
  * host: the hotel MICHELIN's own restaurant address places the restaurant in
    (see HOSTS below). MICHELIN's China restaurant pages carry no "Stay at the
    hotel" section and its hotel pages list only "Restaurants near the hotel".
Place ID columns are left blank: no Places API access (README, QA).
"""
import csv, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
STARS = {'Three': 3, 'Two': 2, 'One': 1}
# Confirmed on the official site, but a hotel switchboard rather than the restaurant's own line
# (the Germany/Italy rule: switchboards are left out).
HOLD = {
    'https://guide.michelin.com/en/guangdong-province/guangzhou/restaurant/hongtu-hall': 'the White Swan Hotel switchboard (restaurant extension 30865)',
    'https://guide.michelin.com/en/guangdong-province/guangzhou/restaurant/jade-river': 'the White Swan Hotel switchboard (restaurant extension 30880)',
}
# MICHELIN's guide (selection) per restaurant decides the guide year (README "Editions").
# Announcement date = the article's JSON-LD datePublished: where the article text states the
# ceremony date ("On April 9, 2026"; "On November 21st") it equals datePublished, while the
# date printed above the headline is one day earlier.
EDITIONS = {
    'Beijing': (2027, '2026-10-27'), 'Tianjin': (2027, '2026-10-27'),        # Beijing & Tianjin 2027
    'Chengdu': (2027, '2026-09-03'),                                         # Chengdu 2027
    'Guangzhou': (2026, '2026-08-18'), 'Shenzhen': (2026, '2026-08-18'),     # Guangzhou & Shenzhen 2026
    'Shanghai': (2026, '2026-04-09'), 'Hangzhou': (2026, '2026-04-09'),      # Shanghai, Jiangsu & Zhejiang 2026
    'Taizhou': (2026, '2026-04-09'), 'Nanjing': (2026, '2026-04-09'),
    'Suzhou': (2026, '2026-04-09'), 'Yangzhou': (2026, '2026-04-09'),
    'Fuzhou': (2026, '2025-11-21'), 'Xiamen': (2026, '2025-11-21'), 'Quanzhou': (2026, '2025-11-21'),  # Fujian 2026
}
# MICHELIN's restaurant address names the hotel. key: the restaurant's MICHELIN url.
#   ('key', <MICHELIN hotel id>)  the Key hotel's own MICHELIN page gives the same street
#                                 number and road (checked in build_prepared.py too)
#   ('property', <name>)          a hotel that is not a MICHELIN Key hotel -> property_name,
#                                 written as MICHELIN's address prints it
G = 'https://guide.michelin.com/en/'
HOSTS = {
    G + 'guangdong-province/shenzhen_1030672/restaurant/the-bay-by-chef-fei': ('key', '13280'),
    G + 'guangdong-province/shenzhen_1030672/restaurant/opus-388': ('key', '13280'),
    G + 'guangdong-province/shenzhen_1030672/restaurant/yun-jing': ('key', '14978'),
    G + 'beijing-municipality/beijing/restaurant/fu-chun-ju': ('key', '9032'),
    G + 'beijing-municipality/beijing/restaurant/il-ristorante-niko-romito-1186723': ('key', '12401'),
    G + 'shanghai-municipality/shanghai/restaurant/il-ristorante-niko-romito-563683': ('key', '12400'),
    G + 'shanghai-municipality/shanghai/restaurant/yong-yi-ting': ('key', '6929'),
    G + 'beijing-municipality/beijing/restaurant/zijin-mansion': ('key', '7153'),
    G + 'beijing-municipality/beijing/restaurant/the-house-of-dynasties': ('key', '7249'),
    G + 'chengdu-municipality/chengdu/restaurant/mi-xun-teahouse': ('key', '7876'),
    G + 'guangdong-province/guangzhou/restaurant/lingnan-house': ('key', '11778'),
    G + 'guangdong-province/guangzhou/restaurant/yu-yue-heen': ('key', '7784'),
    G + 'zhe-jiang/hangzhou_1027184/restaurant/jin-sha': ('key', '8860'),
    G + 'shanghai-municipality/shanghai/restaurant/le-comptoir-de-pierre-gagnaire': ('key', '11050'),
    G + 'shanghai-municipality/shanghai/restaurant/yi-long-court': ('key', '5858'),
    G + 'shanghai-municipality/shanghai/restaurant/ling-long-1209951': ('key', '6803'),
    # MICHELIN's restaurant address prints "Amandayun, 22 Fayun Lane"; MICHELIN's own hotel page
    # at 22 Fayun Lane is Amanfayun (hotel id 7273), which carries no Key today (QA, README).
    G + 'zhe-jiang/hangzhou_1027184/restaurant/hangzhou-house': ('property', 'Amanfayun'),
    G + 'shanghai-municipality/shanghai/restaurant/t-ang-court-506725': ('property', 'The Langham Xintiandi'),
    G + 'beijing-municipality/beijing/restaurant/jingji': ('property', 'The Ritz-Carlton Hotel'),
    G + 'beijing-municipality/beijing/restaurant/rong-pao': ('property', 'The Ritz-Carlton Hotel'),
    G + 'guangdong-province/guangzhou/restaurant/jiang-by-chef-fei': ('property', 'Mandarin Oriental Hotel'),
    G + 'guangdong-province/guangzhou/restaurant/taian-table-1195975': ('property', 'LN Garden Hotel'),
    G + 'guangdong-province/guangzhou/restaurant/stiller': ('property', 'LN Garden Hotel'),
    G + 'beijing-municipality/beijing/restaurant/cai-yi-xuan': ('property', 'Four Seasons Hotel'),
    G + 'shanghai-municipality/shanghai/restaurant/ming-court-570629': ('property', 'Cordis Hotel'),
    G + 'beijing-municipality/beijing/restaurant/giada-garden': ('property', 'China World Hotel'),
    G + 'guangdong-province/guangzhou/restaurant/lai-heen-559155': ('property', 'The Ritz-Carlton Hotel'),
    G + 'guangdong-province/guangzhou/restaurant/hongtu-hall': ('property', 'White Swan Hotel'),
    G + 'guangdong-province/guangzhou/restaurant/jade-river': ('property', 'White Swan Hotel'),
    G + 'guangdong-province/shenzhen_1030672/restaurant/ensue': ('property', 'Futian Shangri-La Hotel'),
    G + 'zhe-jiang/hangzhou_1027184/restaurant/l-eclat-19': ('property', 'Vallie Hotel'),
    G + 'shanghai-municipality/shanghai/restaurant/jin-xuan': ('property', 'The Ritz-Carlton Pudong'),
    G + 'shanghai-municipality/shanghai/restaurant/yong-fu': ('property', 'Jin Jiang Hotel'),
    G + 'jiang-su/nanjing_1029511/restaurant/jiangnan-wok-yun': ('property', 'Shangri-La'),
    G + 'jiang-su/nanjing_1029511/restaurant/pin-ning-fu': ('property', 'The Ritz-Carlton'),
    G + 'jiang-su/nanjing_1029511/restaurant/dai-yuet-heen': ('property', 'The Ritz-Carlton'),
    G + 'zhe-jiang/hangzhou_1027184/restaurant/song-1217000': ('property', 'Four Seasons Hotel at Hangzhou Center'),
    G + 'jiang-su/yangzhou_1032329/restaurant/shang-palace-1216419': ('property', 'Shangri La Hotel'),
    G + 'fujian-province/fuzhou_1026814/restaurant/jiangnan-wok%E2%80%A7rong': ('property', 'Shangri-La Hotel'),
    G + 'fujian-province/xiamen_1031934/restaurant/hokklo': ('property', 'Waldorf Astoria Hotel'),
}
# MICHELIN's website link no longer leads to the restaurant; its own page on the host hotel's site
# (found 2026-10-30 in the built-in browser on The Peninsula Shanghai's dining page).
WEBSITE_FIX = {
    G + 'shanghai-municipality/shanghai/restaurant/yi-long-court': 'https://www.peninsula.com/en/shanghai/hotel-fine-dining/yi-long-court',
}
# Restaurant pin more than 300 m from its (OpenStreetMap-confirmed) Key hotel: take the hotel's point.
COORD_FIX = {
    G + 'shanghai-municipality/shanghai/restaurant/yi-long-court': ('5858',
        "MICHELIN's restaurant pin (31.22, 121.46 area) is 2.2 km from The Peninsula Shanghai, which its own address names "
        "(2F, The Peninsula Hotel, 32 Zhongshan Dong Yi Road); the hotel's point (MICHELIN hotel pin, GCJ-02 converted) is 62 m from "
        "OpenStreetMap's The Peninsula (way 177929887). Hotel point used. 2026-10-29."),
    G + 'shanghai-municipality/shanghai/restaurant/le-comptoir-de-pierre-gagnaire': ('11050',
        "MICHELIN's restaurant pin is 2.2 km from Capella Shanghai, Jian Ye Li, which its own address names (480 West Jianguo Road); "
        "the hotel's point (converted) is 57 m from OpenStreetMap's Jian Ye Li. Hotel point used. 2026-10-29."),
    G + 'beijing-municipality/beijing/restaurant/zijin-mansion': ('7153',
        "MICHELIN's restaurant pin is 571 m from OpenStreetMap's Waldorf Astoria Beijing (way 457743832, 5-15 Jinyu Hutong), "
        "which its own address names; the hotel's point (converted) is 144 m from it. Hotel point used. 2026-10-29."),
}


def main():
    phones = json.load(open(sys.argv[1]))
    byhand = {r['michelin_url']: r for r in csv.DictReader(open(sys.argv[2]))} if len(sys.argv) > 2 else {}
    pages = [json.loads(l) for l in open(os.path.join(HERE, '_source/michelin_cn_restaurant_pages_20261029.jsonl'))]
    cols = ['name', 'stars', 'city', 'selection', 'guide_year', 'announced_on', 'address', 'lat', 'lon', 'coord_note',
            'michelin_url', 'michelin_id', 'website', 'cuisine', 'phone', 'phone_source', 'michelin_phone',
            'place_id', 'place_certainty', 'place_note', 'host_kind', 'host', 'date_awarded']
    rows = []
    for p in pages:
        ld, a = p['ld'], p['ld']['address']
        town, sel = a['addressLocality'], p['listing'][6]
        assert town == sel, (town, sel)
        year, ann = EDITIONS[sel]
        assert str(year) == ld['award']['dateAwarded'], (p['url'], ld['award'])
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
        host = HOSTS.get(p['url'])
        rows.append(dict(name=ld['name'], stars=STARS[ld['starRating'].split()[0]], city=town, selection=sel,
                         guide_year=year, announced_on=ann, address=addr, lat=ld['latitude'], lon=ld['longitude'],
                         coord_note=COORD_FIX[p['url']][1] if p['url'] in COORD_FIX else None,
                         michelin_url=p['url'], michelin_id=p['listing'][0], website=WEBSITE_FIX.get(p['url'], p.get('website')),
                         cuisine=ld.get('servesCuisine'), phone=phone, phone_source=src, michelin_phone=mp,
                         place_id=None, place_certainty='not searched',
                         place_note='no Places API access in this session (QA, README)',
                         host_kind=host and host[0], host=host and host[1], date_awarded=ld['award']['dateAwarded']))
    missing = set(HOSTS) - {r['michelin_url'] for r in rows}
    assert not missing, missing
    rows.sort(key=lambda r: (-r['stars'], r['name'].lower()))
    with open(os.path.join(HERE, 'cn_research_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
    print(len(rows), 'rows;', sum(1 for r in rows if r['phone']), 'phones')


if __name__ == '__main__':
    main()
