#!/usr/bin/env python3
"""Extract what each fetched MICHELIN page says (name, address, telephone,
website link, linked hotel) and check that the page is the exported row's own
venue: same country, and the street address or postcode agrees.

  python3 parse_michelin.py <export.json> <raw_dir> <out.json>"""
import gzip, html, json, os, re, sys, unicodedata

ISO3 = {'USA': 'US', 'JPN': 'JP', 'CHN': 'CN', 'MEX': 'MX', 'ITA': 'IT', 'TWN': 'TW', 'DEU': 'DE', 'FRA': 'FR', 'HKG': 'HK',
        'TUR': 'TR', 'CAN': 'CA', 'GBR': 'GB', 'BEL': 'BE', 'ESP': 'ES', 'AUT': 'AT', 'CZE': 'CZ', 'EGY': 'EG', 'NOR': 'NO',
        'SGP': 'SG', 'CHE': 'CH', 'ARE': 'AE', 'PRT': 'PT', 'THA': 'TH', 'PER': 'PE', 'HRV': 'HR', 'MAC': 'MO', 'POL': 'PL',
        'SVN': 'SI', 'BRA': 'BR', 'DNK': 'DK', 'HUN': 'HU', 'LVA': 'LV', 'MNE': 'ME', 'NLD': 'NL', 'SWE': 'SE', 'AUS': 'AU',
        'EST': 'EE', 'IND': 'IN', 'KOR': 'KR', 'LTU': 'LT', 'SRB': 'RS', 'AND': 'AD', 'ARG': 'AR', 'ABW': 'AW', 'BLM': 'BL',
        'CHL': 'CL', 'COL': 'CO', 'FIN': 'FI', 'IDN': 'ID', 'IRL': 'IE', 'ISL': 'IS', 'MLT': 'MT', 'MDV': 'MV', 'GRC': 'GR',
        'LUX': 'LU', 'MCO': 'MC', 'SWE ': 'SE', 'VNM': 'VN', 'MYS': 'MY', 'PHL': 'PH', 'ZAF': 'ZA', 'QAT': 'QA', 'SAU': 'SA'}


def fold(s):
    s = unicodedata.normalize('NFKD', s or '')
    return re.sub(r'\s+', ' ', re.sub(r'[^\w]+', ' ', ''.join(c for c in s if not unicodedata.combining(c)).lower())).strip()


def lds(body):
    out = []
    for m in re.finditer(r'<script type="application/ld\+json">(.*?)</script>', body, re.S):
        try:
            d = json.loads(m.group(1))
        except ValueError:
            continue
        out += d if isinstance(d, list) else [d]
    return [x for x in out if isinstance(x, dict)]


def addr_agrees(row_addr, ld_addr):
    """MICHELIN's postcode appears in the exported address, or every number of
    MICHELIN's street line does and at least half of its words (compared without
    spaces, so "Yuyuan Road" meets "Yu Yuan Lu")."""
    ra = fold(row_addr)
    ra_flat = ra.replace(' ', '')
    ra_nums = set(re.findall(r'\d+', ra))
    street = fold(ld_addr.get('streetAddress'))
    pc = fold(ld_addr.get('postalCode'))
    why = []
    if pc and len(pc.replace(' ', '')) >= 4 and pc.replace(' ', '') in ra_flat:
        why.append('postcode')
    nums = re.findall(r'\d+', street)
    words = [w for w in re.sub(r'\d+', ' ', street).split() if len(w) > 2]
    if nums and all(n in ra_nums for n in nums) and words and sum(w in ra_flat for w in words) >= len(words) / 2:
        why.append('street')
    return why


EXP, RAW, OUT = sys.argv[1:4]
idx = json.load(open(os.path.join(RAW, 'index.json')))
res = {}
for r in json.load(open(EXP))['gaps']:
    c = r['code']
    if c not in idx:
        continue
    i = idx[c]
    body = gzip.open(os.path.join(RAW, c + '.html.gz'), 'rt').read()
    L = lds(body)
    want = ('Restaurant',) if r['kind'] == 'restaurant' else ('Hotel', 'LodgingBusiness', 'Resort')
    ld = next((x for x in L if x.get('@type') in want), None)
    canon = re.search(r'<link rel="canonical" href="([^"]+)"', body)
    web = re.search(r'href="(https?://[^"]+)"[^>]*\n?[^>]*\n?[^>]*data-event="CTA_website"', body)
    stay = []
    for p in re.split(r'<h2 class="section__heading section__heading_title">', body)[1:]:
        head = fold(html.unescape(re.sub(r'<[^>]+>', '', p.split('</h2>')[0])))
        if head.startswith('stay at'):
            stay = sorted(set(re.findall(r'href="(/en/hotels-stays/[^"?#]+)"', p)))
    d = dict(status=i['status'], final=i['final'], canonical=canon.group(1) if canon else None, found=bool(ld))
    if ld:
        a = ld.get('address') or {}
        cc = ISO3.get(a.get('addressCountry'), a.get('addressCountry'))
        d.update(name=html.unescape(ld.get('name') or ''), telephone=ld.get('telephone'), address=a,
                 page_country=cc, website=html.unescape(web.group(1)) if web else None, stay_hotels=stay)
        agree = addr_agrees(r['address'], a)
        d['address_agrees'] = agree
        d['identity_ok'] = cc == r['country'] and bool(agree)
        d['identity_note'] = ('country ' + str(cc) + ' != ' + r['country']) if cc != r['country'] else \
            ('address agrees: ' + '+'.join(agree) if agree else 'address does not agree: ' + json.dumps(a, ensure_ascii=False))
    else:
        d.update(identity_ok=False, identity_note='no venue on the page (status %s, final %s)' % (i['status'], i['final']))
    res[c] = d
json.dump(res, open(OUT, 'w'), ensure_ascii=False, indent=1)
print(len(res), 'ok', sum(v['identity_ok'] for v in res.values()))
for c, v in res.items():
    if not v['identity_ok']:
        print(c, v['identity_note'][:160])
