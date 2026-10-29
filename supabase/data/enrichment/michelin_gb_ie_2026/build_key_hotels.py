#!/usr/bin/env python3
"""Build {gb,ie}_key_hotels_2026.csv: every UK / Irish MICHELIN Key hotel (research 2026-10-29).

Usage:
  python3 build_key_hotels.py gb
  python3 build_key_hotels.py ie

ie reads _source/michelin_ie_hotel_pages_20261029.json (the Ireland listing's 59
pages plus the Irish Keys linked from the Key article) instead, keeps
addressCountry IRL, and checks 2 / 5 / 12 against the article.

Reads _source/michelin_uk_hotel_pages_20261029.json (all 462 hotel pages behind
guide.michelin.com/en/hotels-stays/uk, JSON-LD read in a browser) and keeps the
pages whose structured data carries a Key and whose address is in Great Britain
or Northern Ireland (the two Channel Islands Keys are excluded: not UK).
The result is checked against MICHELIN's 2026 UK & Ireland Key article
(_source/michelin_article_keys_uki_2026.json): 9 / 42 / 78.

gb_key_hotel_contacts_research.csv: the website/phone research for every Key
hotel not yet in production plus the existing GB rows missing a field (rules:
_source/research_brief_uk_hotels.md). Only `confirmed` values are carried; a
`group` line and the numbers in HOLD are not; anything else stays NULL.
"""
import csv, json, os, re, sys, collections

HERE = os.path.dirname(os.path.abspath(__file__))
K = {'One': 1, 'Two': 2, 'Three': 3}
from build_research import TOWN_FIX  # same council-area fix as the restaurant towns
HOLD = {  # confirmed on the site, but not clearly this hotel's own line
    'new_10035': "Padstow Townhouse: the site prints only 01841 532093, beside the group email info@paul-ainsworth.co.uk -- may be the Paul Ainsworth group line",
}


CFG = {'gb': ('_source/michelin_uk_hotel_pages_20261029.json', 'GBR', (9, 42, 78)),
       'ie': ('_source/michelin_ie_hotel_pages_20261029.json', 'IRL', (2, 5, 12))}


def main():
    cc = sys.argv[1]
    src, iso3, expect = CFG[cc]
    pages = json.load(open(os.path.join(HERE, src)))['pages']
    contacts = {r['michelin_url']: r for r in csv.DictReader(open(os.path.join(HERE, f'{cc}_key_hotel_contacts_research.csv')))}
    rows = []
    for p in pages:
        ld = p['ld']
        if not (ld and ld.get('award') and ld['address'].get('addressCountry') == iso3
                and ld['address'].get('addressRegion') != 'Channel Islands'):
            continue
        a = ld['address']
        c = contacts.get(p['url'], {})
        web = c.get('website_url') if c.get('website_certainty') == 'confirmed' else None
        phone = c.get('phone') if c.get('phone_certainty') == 'confirmed' and c.get('line_type') != 'group' and c.get('ref') not in HOLD else None
        rows.append(dict(
            name=p['h1'], keys=K[ld['award']['awardFor'].split()[0]], city=TOWN_FIX.get(a.get('addressLocality'), a.get('addressLocality')),
            address=', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in (a.get('addressLocality'), (a.get('postalCode') or '').strip()) if y)) if x and x.strip()),
            lat=ld['geo']['latitude'], lon=ld['geo']['longitude'], michelin_url=p['url'],
            michelin_phone=ld.get('telephone'), website_url=web, phone=phone,
            website_certainty=c.get('website_certainty') or 'not researched',
            phone_certainty=c.get('phone_certainty') or 'not researched',
            line_type=c.get('line_type'), website_source_url=c.get('website_source_url'),
            phone_source_url=c.get('phone_source_url'), notes=' | '.join(x for x in (HOLD.get(c.get('ref')), c.get('notes')) if x)))
    rows.sort(key=lambda r: (-r['keys'], r['name'].lower()))
    cnt = collections.Counter(r['keys'] for r in rows)
    assert (cnt[3], cnt[2], cnt[1]) == expect, cnt
    with open(os.path.join(HERE, f'{cc}_key_hotels_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    print(len(rows), dict(cnt), 'websites', sum(1 for r in rows if r['website_url']), 'phones', sum(1 for r in rows if r['phone']))


if __name__ == '__main__':
    main()
