#!/usr/bin/env python3
"""Build {us,ca,mx}_key_hotels_2026.csv: every US / Canadian / Mexican MICHELIN Key hotel (research 2026-10-29).

Usage:
  python3 build_key_hotels.py

Copied from ../michelin_gb_ie_2026/build_key_hotels.py. Reads
_source/michelin_hotel_listing_20261029.json (every card of
guide.michelin.com/en/hotels-stays/{usa,canada,mexico}: 1,311 + 126 + 222
hotels, each card's `data-distinction`) and
_source/michelin_key_hotel_pages_20261029.json (the page of every card the
listing marks with a Key, JSON-LD read in a browser). The Key, address and
coordinates come from the page's own JSON-LD; the country from its
addressCountry, so a card filed under another country's listing still lands
in the right one. Counts are checked against MICHELIN's 2026 Key articles
(18 September 2026; _source/michelin_article_keys_*_2026.txt): EXPECT below.

{cc}_key_hotel_contacts_research.csv: the website/phone research for every Key
hotel not yet in production plus the existing rows missing a field (rules:
_source/research_brief_hotels.md). Only `confirmed` values are carried; a
`group` line and the numbers in HOLD are not; anything else stays NULL.
"""
import csv, json, os, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
K = {'One': 1, 'Two': 2, 'Three': 3}
ISO = {'USA': 'us', 'CAN': 'ca', 'MEX': 'mx'}
EXPECT = {'us': (15, 78, 266), 'ca': (2, 8, 32), 'mx': (3, 21, 73)}  # MICHELIN's articles; mx: 98 there, Diez Diez Collection has no page (README)
TOWN_FIX = {}
COORD_FIX = {}
HOLD = {}  # ref -> reason: confirmed on the site, but not clearly this hotel's own line


def main():
    pages = json.load(open(os.path.join(HERE, '_source/michelin_key_hotel_pages_20261029.json')))['pages']
    rows = collections.defaultdict(list)
    for p in pages:
        ld = p['ld']
        if not (ld and ld.get('award')):
            print('NO KEY ON PAGE', p['url'])
            continue
        a = ld['address']
        cc = ISO.get(a.get('addressCountry'))
        if not cc:
            print('OTHER COUNTRY', a.get('addressCountry'), p['url'])
            continue
        rows[cc].append(dict(
            name=p['h1'], keys=K[ld['award']['awardFor'].split()[0]], city=TOWN_FIX.get(a.get('addressLocality'), a.get('addressLocality')),
            region=a.get('addressRegion'),
            address=', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in (a.get('addressLocality'), (a.get('postalCode') or '').strip()) if y)) if x and x.strip()),
            lat=ld['geo']['latitude'], lon=ld['geo']['longitude'], michelin_url=p['url'], michelin_phone=ld.get('telephone')))
    # a number the research gives to more than one hotel is a group or shared line
    # (Benjamin Hotels' Belvedere and The Smith; Lark's Blind Tiger Portland pair), not
    # either hotel's own: held back like a `group` line
    allc = [r for cc in ('us', 'ca', 'mx') if os.path.exists(os.path.join(HERE, f'{cc}_key_hotel_contacts_research.csv'))
            for r in csv.DictReader(open(os.path.join(HERE, f'{cc}_key_hotel_contacts_research.csv')))]
    digits = lambda p: ''.join(ch for ch in p or '' if ch.isdigit())
    shared = {d for d, k in collections.Counter(digits(r['phone']) for r in allc if r.get('phone_certainty') == 'confirmed' and r.get('phone')).items() if k > 1}
    for cc in ('us', 'ca', 'mx'):
        path = os.path.join(HERE, f'{cc}_key_hotel_contacts_research.csv')
        contacts = {r['michelin_url']: r for r in csv.DictReader(open(path))} if os.path.exists(path) else {}
        out = []
        for r in rows[cc]:
            c = contacts.get(r['michelin_url'], {})
            # a website is carried only when the site itself showed name, town and address
            # (the brief's full match); a name+city match stays out, however plausible
            web = c.get('website_url') if c.get('website_certainty') == 'confirmed' and c.get('website_match_basis') == 'name+city+address' else None
            phone = c.get('phone') if c.get('phone_certainty') == 'confirmed' and c.get('line_type') != 'group' and c.get('ref') not in HOLD \
                and digits(c.get('phone')) not in shared else None
            fix = COORD_FIX.get(r['michelin_url'])
            if fix:
                r['lat'], r['lon'] = fix[0], fix[1]
            out.append(dict(r, website_url=web, phone=phone,
                            website_certainty=c.get('website_certainty') or 'not researched',
                            phone_certainty=c.get('phone_certainty') or 'not researched',
                            line_type=c.get('line_type'), website_source_url=c.get('website_source_url'),
                            phone_source_url=c.get('phone_source_url'),
                            notes=' | '.join(x for x in (fix and fix[2], HOLD.get(c.get('ref')),
                                                         'phone shared with another hotel in this research: held back' if c.get('phone') and digits(c.get('phone')) in shared else None,
                                                         c.get('notes')) if x)))
        out.sort(key=lambda r: (-r['keys'], r['name'].lower()))
        cnt = collections.Counter(r['keys'] for r in out)
        if EXPECT[cc]:
            assert (cnt[3], cnt[2], cnt[1]) == EXPECT[cc], (cc, cnt)
        with open(os.path.join(HERE, f'{cc}_key_hotels_2026.csv'), 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=list(out[0])); w.writeheader(); w.writerows(out)
        print(cc, len(out), dict(cnt), 'websites', sum(1 for r in out if r['website_url']), 'phones', sum(1 for r in out if r['phone']))


if __name__ == '__main__':
    main()
