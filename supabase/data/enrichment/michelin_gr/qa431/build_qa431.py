#!/usr/bin/env python3
"""QA-431 (Greece): decide Place ID, phone and website per row and write

  gr_qa431_control.csv  one row per venue: every value with source and evidence,
                        including each value held back and why
  gr_qa431_fill.csv     input for ../../europe_gaps/build_gap_fill_sql.py

Inputs (all in this folder): places_raw_20261103.json (Text Search),
places_followup_20261103.json (lodging-only searches), sites_20261103.json
(official-site check). Manual findings from reading the sites are in the
tables below, each with the quote it rests on.

Rules (europe_gaps/README.md, find-place-id, michelin_key_hotel_contacts):
- Place ID: the venue's own record (restaurant record for a restaurant, a
  lodging record for a hotel; a combined same-name listing is allowed).
  < 100 m accepted; 100-500 m only when the record's website is the venue's
  official domain, verified by loading it; > 500 m rejected. Permanently
  closed held back; temporarily closed (seasonal islands in November) noted.
- Phone: the number in the venue's own site's visible contact block. A local
  property line wins over a head-office or reservations line. Where the site
  is unreachable or prints no number, MICHELIN and Google must agree. Sources
  that disagree with nothing to settle them: held back.
- Website: loads and names the venue (own site or the property's page on the
  brand's site). Booking engines, deal sites and social links never.
"""
import csv, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
GR = os.path.join(HERE, '..')
P = json.load(open(os.path.join(HERE, 'places_raw_20261103.json')))
S = json.load(open(os.path.join(HERE, 'sites_20261103.json')))
C = {r['code']: r for r in csv.DictReader(open(os.path.join(GR, 'gr_control.csv'))) if r['kind'] in ('restaurant', 'hotel')}
X = json.load(open(os.path.join(GR, '_source', 'production_after_apply_20261104.json')))
PROD = {r['code']: r['name'] for r in X['restaurants'] + X['hotels']}
TODAY = '2026-11-03'

# Already filled on production (prepared_gr_2027.sql / europe_gaps): never touched.
HAS_PHONE = {c for c, r in C.items() if r['kind'] == 'restaurant' and r['phone']}
HAS_WEB = {c for c, r in C.items() if r['kind'] == 'restaurant'} | {'hotel_716'}
HAS_PLACE = {'hotel_716'}

# ---- Place ID: rows that are not the plain first candidate -----------------
PLACE_HOLD = {
    'hotel_3024': 'Google record "Elix, Mar-Bella Collection" (marbella.gr, MICHELIN phone) is 615 m from the stored point: over 500 m, rejected. Stored point vs record: QA-472',
    'hotel_3058': 'Google record "Olea All Suite Hotel, Member of Design Hotels" (oleaallsuitehotel.com, MICHELIN phone) is 715 m from the stored point: over 500 m, rejected. QA-472',
    'hotel_3061': 'Google record "Palladium Boutique Hotel" (hotelpalladium.gr, MICHELIN phone) is 646 m from the stored point: over 500 m, rejected. QA-472',
    'hotel_3026': 'Only record is "Erosantorini" typed wedding_venue/event_venue, no lodging type; a lodging-only search returns Argento Nero 588 m away. No hotel record',
    'hotel_3041': 'Only record is "Leeda\'s Village" typed apartment_complex, not lodging; the lodging-only search returns a different property (The Farm Cottage) 1,572 m away',
    'hotel_3062': 'Two records: "Perivolas Lifestyle Houses" (lodging, 924 m, website a deal site) and "Perivolas Hotel" (hotel, 125 m, perivolas.gr). perivolas.gr answers 403, so the domain cannot be verified; two candidates: held back',
    'hotel_3060': 'Record "One&Only Aesthesis" is 197 m away; its domain oneandonlyresorts.com timed out twice, so the 100-500 m domain check could not be made',
}
PLACE_NOTE = {
    'rest_4007': 'Seasonal: Google shows CLOSED_TEMPORARILY (November). The record also carries lodging types but is named for the restaurant and links laudarestaurant.com; Andronis Boutique Hotel is not in hotels',
    'rest_4008': 'Seasonal: Google shows CLOSED_TEMPORARILY (November). Restaurant record, not Andronis Luxury Suites',
    'rest_4010': 'Restaurant record "Patio at The Margi", not the hotel',
    'rest_4011': '161 m: accepted because the record links pelagosathens.com, MICHELIN\'s own link. Restaurant record, not Four Seasons Astir Palace (hotel_716 keeps its own)',
    'rest_4013': '220 m: accepted because the record links selene.gr, MICHELIN\'s own link; Google address "Old catholic monastery, Fira"',
    'rest_4014': 'Restaurant record "Sense Rooftop Restaurant", not AthensWas',
    'rest_4018': 'Restaurant record, not the hotel The Zillers',
    'rest_4012': 'Google name "Seeds Restaurant"; links seedsrestaurant.gr, MICHELIN\'s link',
    'hotel_3006': '153 m: record links andronis.com/hotels/andronis-concept, which loads and names the hotel',
    'hotel_3014': '326 m: record links calimykonos.com, which loads and names the hotel',
    'hotel_3018': '212 m: record links coveparos.gr, which loads and names the hotel',
    'hotel_3021': '102 m: record links domesresorts.com/domeswhitecoastmilos, which loads and names the hotel. Seasonal: CLOSED_TEMPORARILY',
    'hotel_3025': 'Combined same-name listing: one record for ERGON House Athens, typed both greek_restaurant and hotel/lodging. Accepted under the combined-listing rule',
    'hotel_3027': '114 m: record links ethereummykonos.com, which loads and names the hotel',
    'hotel_3030': 'Google name "Istoria Beach, a Member of Design Hotels" (4 m). istoriahotel.gr lists two properties, Istoria Beach (Perivolos) and Istoria Cliff (Firostefani); the stored point is the beach one',
    'hotel_3032': 'Google name "KAMARES Historic Boutique Hotel & Spa | Ioannina"',
    'hotel_3036': '138 m: record links katikies.com/katikieshotelsantorini, which loaded and names Pelagos House',
    'hotel_3037': '165 m: record links kinsternahotel.gr, which loads and names the hotel',
    'hotel_3045': 'Google name "Minos Palace Hotel & Suites"; its link minospalace.com is titled "Minos Palace Resort", MICHELIN\'s name',
    'hotel_3048': '162 m: record links omyconian.gr, which loads and names the hotel',
    'hotel_3049': 'Google name "Panoptis Escape, an SLH Hotel"',
    'hotel_3063': '343 m: record links pnoe-breathinglife.com, which loads and names the hotel',
}

# ---- Phones ------------------------------------------------------------------
# value digits (national, 10) + where it was read. Only rows not settled by the
# generic rule (site prints MICHELIN's or Google's number, or the two agree
# with no other number on a reachable site).
PHONE_MANUAL = {
    'rest_4004': ('6986657553', 'deltarestaurant.gr/portfolio/contact: "Tel: 6986657553 (Monday to Friday: 12.00-19.00)". Equal to MICHELIN and Google'),
    'rest_4007': ('2286186696', 'laudarestaurant.com: "Reserve a table (+30) 2286186696", equal to Google. MICHELIN\'s +30 2286 072182 is not on the site'),
    'rest_4016': ('2107513505', 'soilrestaurant.gr: "+30 210 75 13 505 (landline)", equal to MICHELIN and Google'),
    'hotel_3056': ('2289071420', 'numomykonos.com contact block: "Kalafatis Mykonos 84600 - Greece T: +30 22890 71420". MICHELIN and Google give +30 2834 055000 (a Crete prefix), which the site carries only in its JSON-LD'),
    'hotel_3064': ('2695065100', 'portozante.com: "Reservations tel: (+30) 210 8218640 - (+30) 26950 65100". The 210 line (MICHELIN and Google) is the Athens reservations team; the 26950 line is the Zakynthos property'),
    'hotel_3066': ('6973007006', 'tainaron-blue.com: "T. +30-2108080049 M. +30-6973007006". The 210 line (MICHELIN) is Athens; the mobile is also Google\'s number'),
    'hotel_3069': ('2289028543', 'mykonostownhousehotel.com contact block: "Manto Square, Mykonos Town, 84600 ... +30 22890 28543", equal to Google. MICHELIN\'s +30 211 198 9344 is the site\'s JSON-LD "Reservations" line'),
    'hotel_3018': ('2284052300', 'coveparos.gr: "Agioi Anargyroi - Naoussa 84401, Paros ... P: (0030) 22840 52300". MICHELIN and Google give +30 2284 028576, which the site does not print'),
    'hotel_3016': ('2286072238', 'canaves.com/canaves-sunday (the property page): "CONTACT US Tel: +302286072238", equal to Google. MICHELIN\'s +30 22860 71453 is the group number on the canaves.com home page (also MICHELIN\'s second number for Canaves Epitome)'),
    'hotel_3065': ('2651075700', 'hotelstoes.gr: "ΧΡΗΣΤΟΥ ΕΥΘΥΜΙΟΥ 11, 454 44 ΙΩΑΝΝΙΝΑ +30 2651 075700", equal to MICHELIN and Google'),
    'hotel_3013': ('2289023300', 'bohememykonos.com header: "H: +302289023300 / +306980424768". MICHELIN\'s +30 22894 40360 (also MICHELIN\'s number for NOMAD) appears elsewhere on the site; Google gives +30 2289 077722'),
}
PHONE_HOLD = {
    'rest_4011': 'pelagosathens.com prints no phone; MICHELIN +30 21 0890 1190 and Google +30 21 0890 1192 differ',
    'hotel_716': 'fourseasons.com answers 403; MICHELIN +30 21 0890 1040 and Google +30 21 0890 1000 differ',
    'hotel_3022': 'domesresorts.com/domeszeenchania prints only central reservations "+30 2312 317000"; MICHELIN +30 2310 810624 (Thessaloniki) and Google +30 2821 607000 (Chania) differ',
    'hotel_3054': 'nomadsmykonos.com (Google\'s link) does not resolve; MICHELIN +30 22894 40360 is Boheme\'s number and Google gives +30 2289 072800',
    'hotel_3004': 'MICHELIN and Google agree on +30 2289 077205, but amythhotels.com prints only "+30 21112 19975" (Athens): sources disagree',
    'hotel_3035': 'MICHELIN and Google agree on +30 2286 071214, but the shared Katikies Santorini page prints +30 2286 071129 and Pelagos House\'s +30 2286 072382: sources disagree',
    'hotel_3062': 'perivolas.gr answers 403 and the matching Google record has no phone; only MICHELIN\'s number',
}

# ---- Websites ----------------------------------------------------------------
WEB_MANUAL = {
    'hotel_3022': ('https://www.domesresorts.com/domeszeenchania/', 'operator\'s property page, titled "Luxury Family Resort in Chania Crete, Greece | Domes Zeen". Google links marriott.com, which answers 403'),
    'hotel_3065': ('https://www.hotelstoes.gr/', 'stoeshotel.gr redirects here; titled "Stoes Hotel Ioannina", prints the address in Ioannina and +30 2651 075700. Google links a booking engine (stoeshotel.reserve-online.net), not used'),
    'hotel_3016': ('https://canaves.com/canaves-sunday/', 'the property page on the brand\'s site, titled "Boutique hotel Santorini | Suites | Canaves Sunday". Google links only the canaves.com home page'),
    'hotel_3055': ('https://not-hotel.com/', 'titled "NOT Hotel Athens", prints Voutadon 16 and +30 216 0002 310'),
    'hotel_3030': ('https://istoriahotel.gr/', 'titled "ISTORIA Hotel Santorini"'),
    'hotel_3045': ('https://www.minospalace.com/', 'titled "Minos Palace Resort | 5 Star Adults-Only Hotel Agios Nikolaos, Crete"'),
}
WEB_HOLD = {
    'hotel_3010': 'aristi.eu (Google\'s link) does not resolve from here',
    'hotel_3029': 'Google links marriott.com (403); grandebretagne.gr fails TLS (hostname mismatch)',
    'hotel_3032': 'hotelkamares.gr (Google\'s link) does not resolve from here',
    'hotel_3054': 'nomadsmykonos.com (Google\'s link) does not resolve',
    'hotel_3057': 'okuhotels.com answers 403',
    'hotel_3060': 'oneandonlyresorts.com timed out twice',
    'hotel_3062': 'Google\'s link is a deal site (deals.vio.com); perivolas.gr answers 403',
    'hotel_3035': 'The Katikies Santorini page Google links is shared by Pelagos House and Gea House; that it names Gea House was not checked',
    'hotel_716': None,
}


def fmt(d):
    """Greek national number (10 digits) in the +30 grouping Google uses."""
    if d.startswith('69'):
        return f'+30 {d[:3]} {d[3:6]} {d[6:]}'
    if d.startswith('21'):
        return f'+30 21 {d[2:6]} {d[6:]}'
    if d[:3] in ('231', '261', '281'):
        return f'+30 {d[:3]} {d[3:6]} {d[6:]}'
    return f'+30 {d[:4]} {d[4:]}'


def digits(s):
    return re.sub(r'^(00)?30', '', re.sub(r'\D', '', s or ''))


def clean_url(u):
    u = re.sub(r'^http://', 'https://', u.split('?')[0])
    return u if u.count('/') > 2 else u + '/'


out, fill = [], []
for code, raw in P.items():
    r = C[code]; cand = raw['candidates'][0] if raw['candidates'] else {}
    s = S.get(code, {})
    row = {'kind': r['kind'], 'code': code, 'name': PROD[code], 'town': r['town'], 'lat': r['lat'], 'lon': r['lon']}

    # Place ID
    gname = cand.get('displayName', {}).get('text', '')
    row.update(google_name=gname, google_id=cand.get('id', ''), distance_m=cand.get('distance_m', ''),
               record_type=cand.get('primaryType', ''), business_status=cand.get('businessStatus', ''),
               google_phone=cand.get('internationalPhoneNumber', ''), google_website=cand.get('websiteUri', ''))
    if code in HAS_PLACE:
        pid, pst = '', 'not needed: already set on production'
    elif code in PLACE_HOLD:
        pid, pst = '', 'held back: ' + PLACE_HOLD[code]
    else:
        d = cand['distance_m']; types = cand['types']
        ok_type = ('lodging' in types) if r['kind'] == 'hotel' else ('restaurant' in types)
        assert ok_type, code
        assert cand['businessStatus'] != 'CLOSED_PERMANENTLY', code
        assert d < 100 or (d <= 500 and code in PLACE_NOTE), (code, d)
        pid = cand['id']
        pst = f'confirmed: own record, {d} m' + ('; ' + PLACE_NOTE[code] if code in PLACE_NOTE else '')
    row.update(place_id=pid, place_status=pst)

    # Phone
    mich = [digits(x) for x in r['michelin_phone'].split('/') if x.strip()]
    goog = digits(cand.get('internationalPhoneNumber', ''))
    on_site_m = s.get('michelin_on_site', []); on_site_g = s.get('google_on_site', '')
    site_ok = isinstance(s.get('pages', [[0, 0]])[0][1], int) and s['pages'][0][1] == 200 if s.get('pages') else False
    if code in HAS_PHONE:
        ph, pst = '', 'not needed: already set on production'
    elif code in PHONE_HOLD:
        ph, pst = '', 'held back: ' + PHONE_HOLD[code]
    elif code in PHONE_MANUAL:
        dd, why = PHONE_MANUAL[code]; ph, pst = fmt(dd), 'confirmed: ' + why
    elif on_site_m:
        ph = fmt(on_site_m[0])
        pst = f'confirmed: MICHELIN\'s number printed on {s["url"]}' + (' and equal to Google' if on_site_m[0] == goog else f'; Google gives {cand.get("internationalPhoneNumber") or "none"}')
    elif on_site_g:
        ph = fmt(on_site_g)
        pst = f'confirmed: Google\'s number printed on {s["url"]}; MICHELIN\'s {r["michelin_phone"]} is not on the site'
    elif goog and goog in mich:
        ph = fmt(goog)
        why = 'site unreachable' if not site_ok else 'site prints no number we could read'
        pst = f'confirmed: MICHELIN and Google agree ({why}: {s.get("url") or "no link"})'
        if site_ok:
            print('CHECK agreement on reachable site', code, s.get('phones_on_site'))
    else:
        raise SystemExit(f'undecided phone {code}')
    row.update(michelin_phone=r['michelin_phone'], phone=ph, phone_status=pst)

    # Website
    if code in HAS_WEB:
        web, wst = '', 'not needed: already set on production'
    elif code in WEB_HOLD:
        web, wst = '', 'held back: ' + WEB_HOLD[code]
    elif code in WEB_MANUAL:
        web, why = WEB_MANUAL[code]; wst = 'confirmed: ' + why
    else:
        assert s['pages'][0][1] == 200 and s['name_tokens'] and all(s['name_tokens'].values()), (code, s.get('pages'), s.get('name_tokens'))
        assert not re.search(r'booking|reserve-online|vio\.com|facebook|instagram', s['url']), code
        web = clean_url(cand['websiteUri'])
        wst = f'confirmed: Google\'s link loads (HTTP 200) and names the hotel ({", ".join(s["name_tokens"])})'
    row.update(website=web, website_status=wst)
    row.update(evidence_source=f'Places API Text Search {TODAY} (places_raw_20261103.json); site check {TODAY} (sites_20261103.json)',
               confidence='high' if (pid or ph or web) else '', status='proposed')
    out.append(row)
    if pid or ph or web:
        fill.append({'kind': r['kind'], 'code': code, 'name': PROD[code], 'place_id': pid, 'phone': ph, 'website': web})

ids = [r['place_id'] for r in out if r['place_id']]
assert len(ids) == len(set(ids)), 'duplicate Place ID among proposals'
for f, rows in (('gr_qa431_control.csv', out), ('gr_qa431_fill.csv', fill)):
    with open(os.path.join(HERE, f), 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
n = lambda k, kind: sum(1 for r in out if r['kind'] == kind and r[k])
for kind in ('restaurant', 'hotel'):
    print(kind, 'place', n('place_id', kind), 'phone', n('phone', kind), 'web', n('website', kind))

# ---- SQL: the shared generator, plus a header note for this pass ---------------
import subprocess
SQL = os.path.join(HERE, 'prepared_gr_qa431_fill.sql')
subprocess.run(['python3', os.path.join(HERE, '..', '..', 'europe_gaps', 'build_gap_fill_sql.py'), 'GR',
                os.path.join(HERE, 'gr_qa431_fill.csv'), SQL, '2026-11-04'], check=True)
note = """-- QA-431, Greece (written 2026-11-03, generated by michelin_gr/qa431/build_qa431.py).
-- Evidence and the reason for every value, and every value held back, are in
-- gr_qa431_control.csv. For hotel phones this pass reads the venue's own site
-- first: the number in its contact block, a local property line ahead of a
-- head-office line; MICHELIN and Google agreeing only where the site could not
-- be read. Applies on top of prepared_gr_2027.sql (applied 2026-11-04).
--
"""
s = open(SQL).read()
open(SQL, 'w').write(note + s)
