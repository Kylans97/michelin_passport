#!/usr/bin/env python3
"""Build the nine-country Europe pass (research 2026-11-04): CZ HR SI HU MT LT LV EE RS.

  python3 build_europe9.py

Reads only committed files in _source/. Writes controle/<CC>.csv, rapporten/<CC>.md and
match_report.csv. It writes no SQL and no migration: this pass stops at the review.

Rules (README.md):
  * identity: MICHELIN's id when a stored row has its URL, else the stored point within
    500 m of MICHELIN's pin in the same country, never a name;
  * the live listing and each page's JSON-LD decide; the global Key article of 18 Sep 2026
    gives each country's Key total;
  * a stored value that differs from MICHELIN is held back and logged, never corrected here;
  * phone only when printed on the venue's own site; website = MICHELIN's link when it
    loads and either names the venue or prints its phone; no Place ID (no Google access).
"""
import collections, csv, json, math, os, re, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '_source')
FIRST_REST, FIRST_HOTEL = 4100, 3100
CCS = ['CZ', 'HR', 'SI', 'HU', 'MT', 'LT', 'LV', 'EE', 'RS']
NAMES = {'CZ': 'Tsjechië', 'HR': 'Kroatië', 'SI': 'Slovenië', 'HU': 'Hongarije', 'MT': 'Malta', 'LT': 'Litouwen',
         'LV': 'Letland', 'EE': 'Estland', 'RS': 'Servië'}
NEW_COUNTRIES = {'CZ': ('Czechia', '🇨🇿', 'Europe/Prague'), 'LT': ('Lithuania', '🇱🇹', 'Europe/Vilnius'),
                 'LV': ('Latvia', '🇱🇻', 'Europe/Riga'), 'EE': ('Estonia', '🇪🇪', 'Europe/Tallinn')}
# MICHELIN's own edition articles (_source/articles/)
ANNOUNCED = {'CZ': '2025-12-11', 'HR': '2026-06-25', 'SI': '2026-06-16', 'HU': '2025-10-09', 'MT': '2026-02-17',
             'LT': '2026-06-05', 'LV': '2025-10-22', 'EE': '2026-05-19', 'RS': '2025-12-10'}
KEY_ANNOUNCED = '2026-09-18'
KEY_ARTICLE = {'CZ': 11, 'HR': 12, 'SI': 5, 'HU': 12, 'MT': 6, 'LT': 2, 'LV': 3, 'EE': 2, 'RS': 4}  # 18 Sep 2026
STAR_ARTICLE = {'CZ': (0, 1, 8), 'HR': (0, 1, 13), 'SI': (1, 1, 8), 'HU': (0, 2, 8), 'MT': (0, 1, 6), 'LT': (0, 0, 5),
                'LV': (0, 0, 2), 'EE': (0, 1, 1), 'RS': (0, 0, 2)}
CARD = {'ONE_KEY': 1, 'TWO_KEYS': 2, 'THREE_KEYS': 3}
PIN = {'ONE_STAR': 1, 'TWO_STARS': 2, 'THREE_STARS': 3}
QA = dict(platan='QA-450', parisi='QA-451', bristol='QA-452', slovenia='QA-453', croatia='QA-454', edition='QA-455',
          demo='QA-456', blanks='QA-457', towns='QA-458', hotels='QA-459')

# Hotel Key rows held back. Nothing here is applied; `proposal` is the question for the product owner.
HELD_HOTELS = {
    'hotel_277': (QA['parisi'], "stored 2 matches no edition: MICHELIN's Hungary Key article of 8 Oct 2025 names only Gresham "
                                "Palace and Matild Palace as Two-Key and calls Párisi Udvar One-Key; the 2026 page says One",
                  'correct the 2026 row in place to 1 (QA-384 shape)'),
    'hotel_280': (QA['bristol'], "real change: 1 Key on MICHELIN's listing archived 16 Oct 2025 and in its article of 3 Jul 2026, "
                                 "2 Keys on the live 2026 page",
                  'relabel the launch row 2025 and close it; new current 2026 row of 2 (QA-383 shape)'),
    'hotel_260': (QA['croatia'], "real change: 1 Key on MICHELIN's listing archived 17 Oct 2025, 2 Keys on the live 2026 page",
                  'relabel the launch row 2025 and close it; new current 2026 row of 2 (QA-383 shape)'),
    'hotel_267': (QA['croatia'], "real change: 2 Keys on MICHELIN's listing archived 17 Oct 2025, 1 Key on the live 2026 page",
                  'relabel the launch row 2025 and close it; new current 2026 row of 1 (QA-383 shape)'),
    'hotel_301': (QA['slovenia'], "lost its Key: 1 Key on MICHELIN's listing archived 22 Oct 2025; the live page (14033) has no "
                                  "award and the hotel is no longer on the Slovenia listing",
                  'keep the hotel, michelin_keys NULL, launch row relabelled 2025 and closed, current 2026 row NULL (QA-387)'),
    'hotel_305': (QA['slovenia'], "lost its Key: 1 Key on MICHELIN's listing archived 22 Oct 2025 and its page archived 14 Jan 2026; "
                                  "the live card and page (15390) carry no Key",
                  'keep the hotel, michelin_keys NULL, launch row relabelled 2025 and closed, current 2026 row NULL (QA-387)'),
}
# Hotel links and property_name: only where MICHELIN's own review names the hotel.
LINKS = {  # restaurant slug -> (hotel key: stored code or new hotel's MICHELIN id, evidence)
    'under-grain': ('hotel_288', "MICHELIN's review: 'Housed within the stylish Rosselli Hotel'; pins 9 m apart"),
    'de-mondion': ('hotel_292', "MICHELIN's review: 'occupies the top floor of the charming Xara Palace hotel'; pins 40 m apart"),
    'john-chef-s-hall': ('12532', "MICHELIN's review: 'Situated within the A22 Hotel'; pins 9 m apart"),
}
PROPERTY = {  # restaurant slug -> (property_name, evidence); the hotel is not in `hotels` and has no Key
    'entree': ('The Theatre Hotel', "MICHELIN's review: 'The Theatre Hotel not only wows overnight guests'"),
    'essens': ('Chateau de Frontiere', "MICHELIN's review: 'The Classical building of the Chateau de Frontiere'"),
    'nebo': ('Hilton Rijeka Costabella', "MICHELIN's review: 'On the fifth floor of the Hilton Rijeka Costabella'"),
    'le-gv': ('Le Soleil Hotel', "MICHELIN's review: 'on the eleventh floor of the 1926 Le Soleil Hotel'"),
}
NOT_PLACED = {  # logged, nothing written
    'alfred-keller': "review: 'The town's most luxurious hotel', not named",
    'harry-s-piccolo-porec': "review: 'within a new five-star hotel', not named",
    'salt-1196768': "review: 'Within a boutique hotel', not named",
    'boskinac': "review: 'a refined country house with a boutique hotel', same name; no separate MICHELIN hotel page read",
    'milka': "review: 'refined hotel rooms are available'; a MICHELIN card 'Milka Boutique Hotel' exists without a Key, but "
             "no page was read that ties the two, so no property_name",
    'cap-aureo': "pin 10 m from hotel_266 Grand Park Hotel Rovinj, but the review does not say so: no link on distance alone",
}
COUNTRY_NOTES = {
    'CZ': ["**Land ontbreekt.** `countries` heeft nog geen `CZ` (Czechia, 🇨🇿, Europe/Prague).",
           f"**Editie-etiket ({QA['edition']}).** MICHELIN's artikel van 11 dec 2025 noemt dit \"Czechia 2025\", terwijl alle pagina's "
           "`dateAwarded 2026` en \"2026 MICHELIN Guide\" zeggen. Voorstel: `guide_year` 2026 volgens de pagina, `announced_on` 2025-12-11.",
           f"**Carlsbad ({QA['towns']}).** MICHELIN's hotelpagina schrijft Carlsbad; de stad heet ook Karlovy Vary. Voorstel: MICHELIN's schrijfwijze."],
    'HR': [f"**Plaatsnamen ({QA['towns']}).** MICHELIN's lijst schrijft Sibenik, Porec en Korcula zonder diakrieten; zo staan ze nu voorgesteld.",
           f"**Twee Key-wijzigingen apart behandeld ({QA['croatia']}).** Dit stond niet in de telling: de verdeling klopt toevallig wel, "
           "doordat de twee elkaar opheffen. Villa Dubrovnik ging van 1 naar 2 Keys, Palace Elisabeth Hvar van 2 naar 1. "
           "Productie heeft beide nog op de waarde van 2025.",
           f"**Twee sites zonder bevestiging ({QA['blanks']}).** Cap Aureo heeft geen link bij MICHELIN; Alfred Keller alleen een boekingslink. Beide blijven leeg."],
    'SI': [f"**Plaatsnaam ({QA['towns']}).** MICHELIN's lijst schrijft Lasko zonder diakriet; zo staat het nu voorgesteld.",
           f"**Het \"ene hotel te veel\" zijn er twee ({QA['slovenia']}).** Peterc Vineyard Estate en Nebesa Chalets verloren in 2026 hun Key, "
           "Vila Muhr kwam erbij. Zo komt het verschil op -1. Beide hotels bleven op de nieuwste archiefkopie op 1 Key staan.",
           "**Voorstel volgens QA-387:** de hotels blijven staan, met `michelin_keys` NULL en een lege huidige 2026-rij; 1 Key blijft als geschiedenis bewaard."],
    'HU': [f"**Platán Gourmet is gesloten ({QA['platan']}).** Productie heeft 2 sterren. In de 2025-editie van 9 okt 2025 had het die nog, "
           "maar de MICHELIN-pagina geeft nu 404, het staat niet in de sterrenlijst, en de pagina van Platán Manor noemt alleen nog Platán Bisztró. "
           "De eigen site meldt: \"a Platán Gourmet befejezte működését\" (is gestopt). De sluitingsdatum staat er niet bij.",
           f"**Daardoor wijkt de sterrenverdeling af.** MICHELIN 0/1/8; productie 0/2/0. Stand heeft wel 2 sterren.",
           f"**Párisi Udvar-Key ({QA['parisi']}).** Productie 2, MICHELIN 1 in zowel 2025 als 2026: een importfout, geen wijziging.",
           f"**Editiejaar ({QA['edition']}).** Hongarije zit nog op de 2025-editie (`dateAwarded 2025`); er is geen 2026-artikel gevonden. "
           "Stand staat in productie als `guide_year` 2026. Voorstel: nieuwe rijen krijgen 2025; Stand blijft ongewijzigd (besloten 2026-11-04).",
           f"**Babel ({QA['blanks']}).** MICHELIN's link laadt, maar de pagina noemt in de opgehaalde HTML naam noch telefoon. Website en telefoon blijven leeg."],
    'MT': [f"**Keys kloppen.** Alle 6 hotels komen overeen; alleen `michelin_url` ontbreekt nog.",
           f"**Le GV ({QA['hotels']}).** `property_name` Le Soleil Hotel, zoals MICHELIN's tekst het noemt."],
    'LT': ["**Land ontbreekt.** `countries` heeft nog geen `LT` (Lithuania, 🇱🇹, Europe/Vilnius).",
           f"**Demo is niet meegenomen ({QA['demo']}).** MICHELIN's artikel van 5 juni 2026 telt vijf sterren, met Demo in Vilnius. "
           "De live lijst telt er vier en de Demo-pagina geeft 404. De live selectie is gevolgd; de reden van het verdwijnen is niet gevonden."],
    'LV': ["**Land ontbreekt.** `countries` heeft nog geen `LV` (Latvia, 🇱🇻, Europe/Riga).",
           "**Hotelkoppeling.** JOHN Chef's Hall komt aan het nieuwe A22 Hotel; MICHELIN's tekst noemt dat hotel."],
    'EE': ["**Land ontbreekt.** `countries` heeft nog geen `EE` (Estonia, 🇪🇪, Europe/Tallinn)."],
    'RS': [f"**The Bristol Belgrade ({QA['bristol']}).** Dit is de afwijkende verdeling: echt van 1 naar 2 Keys in 2026. "
           "MICHELIN schreef op 3 juli 2026 nog One-Key; de live pagina zegt Two Keys. Besloten: volgens voorstel.",
           "**Editie.** MICHELIN's artikel heet \"Belgrade 2026\", maar noemt ook Fleur de Sel in Novi Slankamen; beide sterren staan in de live Servische lijst."],
}


def fold(s):
    s = unicodedata.normalize('NFKD', (s or ''))
    return ''.join(c for c in s if not unicodedata.combining(c)).lower().strip()


def dist(a, b, c, d):
    p = math.pi / 180
    x = (math.sin((c - a) * p / 2) ** 2 + math.cos(a * p) * math.cos(c * p) * math.sin((d - b) * p / 2) ** 2)
    return round(12742000 * math.asin(math.sqrt(x)))


def hid(u):
    m = re.search(r'-(\d+)/?$', (u or '').split('?')[0])
    return m.group(1) if m else None


def slug(u):
    return u.rstrip('/').split('/restaurant/')[1]


def addr(a):
    if isinstance(a, str):
        a = json.loads(a)
    a = a or {}
    street = re.sub(r'\s+', ' ', (a.get('streetAddress') or '')).strip().rstrip(',')
    pc = (a.get('postalCode') or '').strip()
    loc = (a.get('addressLocality') or '').strip()
    tail = ' '.join(x for x in (pc if pc != 'None' else '', loc) if x)
    return ', '.join(x for x in (street, tail) if x), loc


def load(name):
    return json.load(open(os.path.join(SRC, name)))


def tiers(values):
    c = collections.Counter(values)
    return f"{c[3]}/{c[2]}/{c[1]}"


def main():
    X = load('production_export_20261104.json')
    lower = {c.lower() for c in CCS}
    listing = [r for r in load('michelin_star_listing_20261104.json')['rows'] if r['restaurant_country'] in lower]
    rpages = {p['url']: p for p in load('michelin_restaurant_pages_20261104.json')['pages']}
    sites = {s['url']: s for s in load('restaurant_site_checks_20261104.json')}
    hcards = [r for r in load('michelin_hotel_listing_20261104.json')['rows'] if r['hotel_country'] in lower]
    hpages = {hid(p['url']): p for p in load('michelin_hotel_pages_20261104.json')['pages']}
    peterc = dict(lat=46.010389, lon=13.57384, url='https://guide.michelin.com/en/hotels-stays/kojsko/peterc-vineyard-estate-14033')
    cities = {(c['country'], fold(c['name'])): c['name'] for c in X['cities']}
    hotel_urls = {hid(u) for u in (X['hotel_michelin_urls_in_use'] or [])}
    rest_urls = set(X['michelin_urls_in_use'] or [])
    rows, report, newtowns = {cc: [] for cc in CCS}, [], {}

    def town(cc, name):
        t = cities.get((cc, fold(name)))
        if t:
            return t, ''
        newtowns.setdefault((cc, name), 1)
        return name, 'new'

    # ================= hotels =================
    keycards = {r['pid']: r for r in hcards if r['distinction'] in CARD}
    stored_hotels = X['hotels']
    used_h = {}
    for h in stored_hotels:          # identity: MICHELIN id, else point within 500 m
        pid = hid(h['michelin_url'])
        if pid:
            used_h[pid] = (h, 'MICHELIN id')
            continue
        cand = []
        for k, p in hpages.items():
            g = (p['ld'] or {}).get('geo') or {}
            cc = (keycards.get(k) or {}).get('hotel_country') or (hcards and next((c['hotel_country'] for c in hcards if c['pid'] == k), None))
            if g.get('latitude') and cc == h['country'].lower():
                d = dist(h['lat'], h['lon'], float(g['latitude']), float(g['longitude']))
                if d <= 500:
                    cand.append((d, k))
        if h['code'] == 'hotel_301':     # no Key now, so not among the fetched Key pages
            cand = [(dist(h['lat'], h['lon'], peterc['lat'], peterc['lon']), '14033')]
        cand.sort()
        # Valletta's hotels sit within 500 m of each other: the nearest pin must be within 150 m and clearly the nearest
        assert cand[0][0] <= 150 and (len(cand) == 1 or cand[1][0] >= max(cand[0][0] * 3, cand[0][0] + 50)), (h['code'], cand)
        used_h[cand[0][1]] = (h, f'pin {cand[0][0]} m')

    hcode = FIRST_HOTEL
    hotel_key = {}
    for pid, card in sorted(keycards.items(), key=lambda kv: (CCS.index(kv[1]['hotel_country'].upper()), fold(kv[1]['name']))):
        p = hpages[pid]
        ld = p['ld'] or {}
        aw = ld.get('award') or {}
        if isinstance(aw, str):
            aw = json.loads(aw)
        m = re.match(r'(One|Two|Three) MICHELIN Key', aw.get('awardFor') or '')
        keys = {'One': 1, 'Two': 2, 'Three': 3}[m.group(1)]
        assert keys == CARD[card['distinction']], (pid, keys, card)
        cc = card['hotel_country'].upper()
        a, loc = addr(ld.get('address'))
        geo = ld['geo']
        base = dict(country=cc, kind='hotel', name=p['h1'], award=keys, guide_year=2026, announced_on=KEY_ANNOUNCED, michelin_id=pid,
                    michelin_url=p['url'], address=a, lat=geo['latitude'], lon=geo['longitude'], michelin_phone=ld.get('telephone'))
        if pid in used_h:
            h, how = used_h[pid]
            d = dist(h['lat'], h['lon'], float(geo['latitude']), float(geo['longitude']))
            base.update(code=h['code'], town=h['city'], stored_award=h['keys'], stored_distance_m=d, note=f'identity: {how}')
            hotel_key[h['code']] = h['code']
            if not h['michelin_url']:
                base['proposed_fill'] = 'michelin_url'
            if h['code'] in HELD_HOTELS:
                q, why, prop = HELD_HOTELS[h['code']]
                base.update(action='HELD BACK', qa=q, note=f"{why}. Proposal: {prop}")
                report.append(dict(country=cc, code=h['code'], name=p['h1'], kind='KEY HELD BACK', qa=q, detail=f"stored {h['keys']}, MICHELIN {keys}. {why}. Proposal: {prop}"))
            else:
                assert h['keys'] == keys, (h['code'], h['keys'], keys)
                base['action'] = 'verified, unchanged'
        else:
            assert pid not in hotel_urls, pid
            t, new = town(cc, loc)
            base.update(code=f'hotel_{hcode}', action='new', town=t, town_is_new=new, stored_award='', qa=QA['blanks'],
                        note='no phone, website or Place ID proposed: MICHELIN only')
            hcode += 1
            near = [(dist(float(geo['latitude']), float(geo['longitude']), h['lat'], h['lon']), h['code']) for h in stored_hotels]
            assert not [x for x in near if x[0] <= 150], (pid, near)
        hotel_key[pid] = base['code']
        rows[cc].append(base)
    # stored hotels with no Key now (HELD_HOTELS, lost Key)
    for pid, (h, how) in used_h.items():
        if pid in keycards:
            continue
        q, why, prop = HELD_HOTELS[h['code']]
        url = peterc['url'] if pid == '14033' else hpages[pid]['url']
        if pid == '15390':
            g = hpages[pid]['ld']['geo']
            d = dist(h['lat'], h['lon'], float(g['latitude']), float(g['longitude']))
        else:
            d = dist(h['lat'], h['lon'], peterc['lat'], peterc['lon'])
        rows[h['country']].append(dict(country=h['country'], kind='hotel', code=h['code'], action='HELD BACK', name=h['name'], award='',
                                       stored_award=h['keys'], guide_year=2026, announced_on=KEY_ANNOUNCED, michelin_id=pid, michelin_url=url,
                                       town=h['city'], address=h['address'], lat=h['lat'], lon=h['lon'], stored_distance_m=d, qa=q,
                                       proposed_fill='michelin_url' if not h['michelin_url'] else '', note=f"identity: {how}. {why}. Proposal: {prop}"))
        report.append(dict(country=h['country'], code=h['code'], name=h['name'], kind='KEY LOST, HELD BACK', qa=q,
                           detail=f"stored {h['keys']}, MICHELIN none. {why}. Proposal: {prop}"))

    # ================= restaurants =================
    stored_r = list(X['restaurants'])
    used_r = set()
    nearest = {}       # stored restaurant -> its one nearest starred card, never by name
    for r in stored_r:
        cand = sorted((dist(r['lat'], r['lon'], rpages[c['url']]['ld']['latitude'], rpages[c['url']]['ld']['longitude']), c['url'])
                      for c in listing if c['restaurant_country'].upper() == r['country'])
        if cand[0][0] <= 150 and (len(cand) == 1 or cand[1][0] >= max(cand[0][0] * 3, cand[0][0] + 50)):
            nearest[cand[0][1]] = r
    rcode = FIRST_REST
    for c in sorted(listing, key=lambda r: (CCS.index(r['restaurant_country'].upper()), -PIN[r['pin']], fold(r['name']))):
        cc = c['restaurant_country'].upper()
        p = rpages[c['url']]
        ld = p['ld']
        aw = ld['award']
        stars = {'One': 1, 'Two': 2, 'Three': 3}[aw['awardFor'].split()[0]]
        assert stars == PIN[c['pin']], c
        s = sites.get(c['url'], {})
        a, _ = addr(ld.get('address'))
        phone_ok = bool(s.get('phone_on_site') or s.get('phone_on_contact'))
        web_ok = s.get('status') == '200' and (s.get('names_venue') or phone_ok)
        sl = slug(c['url'])
        row = dict(country=cc, kind='restaurant', name=ld['name'], award=stars, guide_year=aw['dateAwarded'], announced_on=ANNOUNCED[cc],
                   michelin_id=c['michelin_id'], michelin_url=c['url'], address=a, lat=ld['latitude'], lon=ld['longitude'],
                   michelin_phone=ld.get('telephone'), phone=ld.get('telephone') if phone_ok else '',
                   phone_source='on official site' if phone_ok else 'not found on official site -- left blank',
                   website=p['website'] if web_ok else '',
                   website_source=('MICHELIN link loads and names the venue' if s.get('names_venue') else 'MICHELIN link loads and prints its phone')
                   if web_ok else 'not confirmed -- left blank')
        cand = [nearest[c['url']]] if c['url'] in nearest else []
        if cand:
            e = cand[0]
            used_r.add(e['code'])
            d = dist(e['lat'], e['lon'], ld['latitude'], ld['longitude'])
            assert e['stars'] == stars, e
            fills = ['michelin_url'] if not e['michelin_url'] else []
            if not e['phone'] and row['phone']:
                fills.append('phone')
            if not e['website_url'] and row['website']:
                fills.append('website_url')
            row.update(code=e['code'], action='verified, unchanged', town=e['city'], stored_award=e['stars'], stored_distance_m=d,
                       proposed_fill=' + '.join(fills), note=f'identity: pin {d} m')
            if e['phone'] and row['phone'] and re.sub(r'\D', '', e['phone']) != re.sub(r'\D', '', row['phone']):
                report.append(dict(country=cc, code=e['code'], name=e['name'], kind='STORED PHONE DIFFERS', qa=QA['blanks'],
                                   detail=f"stored {e['phone']} vs MICHELIN and its site {row['phone']}; stored kept"))
            if e['code'] == 'rest_0425':
                report.append(dict(country=cc, code=e['code'], name=e['name'], kind='WEBSITE NOT FILLED', qa=QA['blanks'],
                                   detail=f"stored website empty; MICHELIN's link {p['website']} answered HTTP {s.get('status')} on the check, so it is not proposed"))
            if str(aw['dateAwarded']) != '2026':
                row['qa'] = QA['edition']
                report.append(dict(country=cc, code=e['code'], name=e['name'], kind='EDITION YEAR', qa=QA['edition'],
                                   detail=f"stored current row is guide_year 2026; MICHELIN's page says dateAwarded {aw['dateAwarded']}, announced {ANNOUNCED[cc]}. Not changed"))
        else:
            assert c['url'] not in rest_urls, c['url']
            t, new = town(cc, c['city'])
            row.update(code=f'rest_{rcode}', action='new', town=t, town_is_new=new, stored_award='', note='', qa=QA['blanks'] if not (row['phone'] and row['website']) else '')
            rcode += 1
        if sl in LINKS:
            key, ev = LINKS[sl]
            row['hotel_code'] = hotel_key[key]
            row['note'] = (row['note'] + ' ' + ev).strip()
            report.append(dict(country=cc, code=row['code'], name=row['name'], kind='LINK PROPOSED', qa=QA['hotels'], detail=f"-> {row['hotel_code']}. {ev}"))
        elif sl in PROPERTY:
            row['property_name'] = PROPERTY[sl][0]
            row['note'] = (row['note'] + ' ' + PROPERTY[sl][1]).strip()
            report.append(dict(country=cc, code=row['code'], name=row['name'], kind='property_name PROPOSED', qa=QA['hotels'], detail=f"{PROPERTY[sl][0]}. {PROPERTY[sl][1]}"))
        elif sl in NOT_PLACED:
            report.append(dict(country=cc, code=row['code'], name=row['name'], kind='HOTEL NOT PLACED', qa=QA['hotels'], detail=NOT_PLACED[sl]))
        if not row['phone'] or not row['website']:
            missing = [f for f, v in (('phone', row['phone']), ('website', row['website'])) if not v]
            report.append(dict(country=cc, code=row['code'], name=row['name'], kind='LEFT BLANK', qa=QA['blanks'],
                               detail=f"{' and '.join(missing)}: site status {s.get('status')}, MICHELIN link {p['website']}"))
        rows[cc].append(row)
    # the one stored restaurant MICHELIN no longer lists
    held = [r for r in stored_r if r['code'] not in used_r]
    assert [r['code'] for r in held] == ['rest_0427'], held
    e = held[0]
    why = ("MICHELIN page gives 404 and the restaurant is off the live star list; the 2025 edition (9 Oct 2025) still gave it 2 stars; MICHELIN's "
           "Platán Manor page lists only Platán Bisztró; the venue's own site platangourmet.com says it has stopped trading")
    prop = "keep the row for visits and the Passport, stars NULL, 2 stars kept as history, status closed; keep the link to hotel_268. Closing date unknown"
    rows['HU'].append(dict(country='HU', kind='restaurant', code=e['code'], action='HELD BACK', name=e['name'], award='', stored_award=e['stars'],
                           town=e['city'], address=e['address'], lat=e['lat'], lon=e['lon'], hotel_code='hotel_268', qa=QA['platan'], website=e['website_url'],
                           note=f"{why}. Proposal: {prop}"))
    report.append(dict(country='HU', code=e['code'], name=e['name'], kind='STARS HELD BACK', qa=QA['platan'], detail=f"stored 2, MICHELIN none. {why}. Proposal: {prop}"))
    report.append(dict(country='LT', code='', name='Demo', kind='NOT ADDED', qa=QA['demo'],
                       detail="MICHELIN's article of 5 Jun 2026 counts five One Stars including Demo, Vilnius; the live list has four and the page /restaurant/demo-1210016 gives 404. "
                              "Beware: the slug /restaurant/demo redirects to a different restaurant in Helsinki"))
    report.append(dict(country='CZ', code='', name='', kind='EDITION YEAR', qa=QA['edition'],
                       detail="MICHELIN's articles of 11 Dec 2025 say 'Czechia 2025'; every page says dateAwarded 2026 and '2026 MICHELIN Guide'. Proposed guide_year 2026, announced 2025-12-11"))
    for (cc, t) in sorted(newtowns):
        report.append(dict(country=cc, code='', name=t, kind='NEW TOWN', qa=QA['towns'], detail="spelling as MICHELIN's listing (restaurants) or page locality (hotels)"))

    # ================= checks =================
    for cc in CCS:
        r = rows[cc]
        lv = [x['award'] for x in r if x['kind'] == 'hotel' and x['award'] != '']
        assert len(lv) == KEY_ARTICLE[cc], (cc, len(lv))
        st = [x['award'] for x in r if x['kind'] == 'restaurant' and x['award'] != '']
        art = STAR_ARTICLE[cc]
        if (st.count(3), st.count(2), st.count(1)) != art:
            assert cc in ('HU', 'LT'), (cc, st, art)   # Platán Gourmet, Demo: both logged

    # ================= outputs =================
    cols = ['country', 'kind', 'code', 'action', 'name', 'award', 'stored_award', 'guide_year', 'announced_on', 'michelin_id', 'michelin_url',
            'town', 'town_is_new', 'address', 'lat', 'lon', 'stored_distance_m', 'phone', 'phone_source', 'michelin_phone', 'website', 'website_source',
            'hotel_code', 'property_name', 'proposed_fill', 'qa', 'note']
    os.makedirs(os.path.join(HERE, 'controle'), exist_ok=True)
    os.makedirs(os.path.join(HERE, 'rapporten'), exist_ok=True)
    for cc in CCS:
        with open(os.path.join(HERE, 'controle', f'{cc}.csv'), 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=cols, extrasaction='ignore')
            w.writeheader()
            w.writerows(sorted(rows[cc], key=lambda x: (x['kind'] != 'restaurant', x['action'] != 'HELD BACK', x['action'] != 'new', x['code'])))
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['country', 'code', 'name', 'kind', 'qa', 'detail'])
        w.writeheader()
        w.writerows(sorted(report, key=lambda x: (CCS.index(x['country']), x['kind'], x['code'])))

    summary = {}
    for cc in CCS:
        r = rows[cc]
        rr = [x for x in r if x['kind'] == 'restaurant']
        hh = [x for x in r if x['kind'] == 'hotel']
        nr = [x for x in rr if x['action'] == 'new']
        nh = [x for x in hh if x['action'] == 'new']
        held_r = [x for x in rr if x['action'] == 'HELD BACK']
        held_h = [x for x in hh if x['action'] == 'HELD BACK']
        towns = sorted({x['town'] for x in r if x.get('town_is_new') == 'new'})
        m_s = tiers(x['award'] for x in rr if x['award'] != '')
        m_k = tiers(x['award'] for x in hh if x['award'] != '')
        p_s = tiers(x['stored_award'] for x in rr if x['stored_award'] != '')
        p_k = tiers(x['stored_award'] for x in hh if x['stored_award'] != '')
        # what production holds once the proposal applies without the held-back rows
        after_s = tiers([x['award'] for x in rr if x['action'] != 'HELD BACK'] + [x['stored_award'] for x in held_r])
        after_k = tiers([x['award'] for x in hh if x['action'] == 'new' or x['action'].startswith('verified')] + [x['stored_award'] for x in held_h])
        summary[cc] = dict(m_s=m_s, p_s=p_s, a_s=after_s, m_k=m_k, p_k=p_k, a_k=after_k, new_r=len(nr), new_h=len(nh), held=len(held_r) + len(held_h), towns=towns,
                           phone=sum(1 for x in nr if x['phone']), web=sum(1 for x in nr if x['website']))
        L = [f"# {NAMES[cc]} ({cc}): MICHELIN-sterren en Keys", "",
             "Status: **getest op een scratch-database, nog niet toegepast op productie.** Gelezen op 2026-11-04 van guide.michelin.com, tegen de productie-export van die dag.", "",
             "| | MICHELIN live (3/2/1) | Productie nu | Na toepassen |", "|---|---|---|---|",
             f"| Sterren | {m_s} | {p_s} | {m_s} |", f"| Keys | {m_k} | {p_k} | {m_k} |", "",
             f"Sterren aangekondigd op {ANNOUNCED[cc]}; Keys op {KEY_ANNOUNCED}. Het Key-totaal klopt met MICHELIN's wereldartikel ({KEY_ARTICLE[cc]}).", "",
             "## Voorstel", "",
             f"- **Nieuwe restaurants:** {len(nr)}" + (f" ({nr[0]['code']}..{nr[-1]['code']})" if len(nr) > 1 else '') + (f"; {sum(1 for x in nr if x['phone'])} met telefoon en {sum(1 for x in nr if x['website'])} met website." if nr else '.'),
             f"- **Nieuwe Key-hotels:** {len(nh)}" + (f" ({nh[0]['code']}" + (f"..{nh[-1]['code']}" if len(nh) > 1 else '') + "), zonder telefoon, website en Place ID." if nh else '.'),
             f"- **Bestaande rijen zonder afwijking:** {sum(1 for x in r if x['action'].startswith('verified'))}."]
        if any(x.get('proposed_fill') for x in r):
            L.append(f"- **Aanvullen, alleen als het veld leeg is:** {sum(1 for x in r if x.get('proposed_fill'))} rijen (`proposed_fill`).")
        if towns:
            L.append(f"- **Nieuwe plaatsen ({QA['towns']}):** {', '.join(towns)}.")
        links = [x for x in rr if x.get('hotel_code') and x['action'] != 'HELD BACK']
        props = [x for x in rr if x.get('property_name')]
        if links:
            L.append("- **Hotelkoppelingen:** " + ', '.join(f"{x['name']} → {x['hotel_code']}" for x in links) + '.')
        if props:
            L.append("- **`property_name`:** " + ', '.join(f"{x['name']} → {x['property_name']}" for x in props) + '.')
        L += ["", "## Aandachtspunten", ""] + [f"- {n}" for n in COUNTRY_NOTES[cc]]
        if held_r or held_h:
            L += ["", "## Apart behandeld", "", "Door de product owner besloten op 2026-11-04, volgens het voorstel in `controle/`.", "", "| Code | Naam | Productie | MICHELIN | Issue |", "|---|---|---|---|---|"]
            for x in held_r + held_h:
                L.append(f"| {x['code']} | {x['name']} | {x['stored_award']} | {x['award'] if x['award'] != '' else 'geen'} | {x['qa']} |")
        L += ["", f"Elke rij met bron staat in [`controle/{cc}.csv`](../controle/{cc}.csv).", ""]
        open(os.path.join(HERE, 'rapporten', f'{cc}.md'), 'w').write('\n'.join(L))
    json.dump(summary, open(os.path.join(HERE, '_source', 'summary_20261104.json'), 'w'), ensure_ascii=False, indent=1)
    for cc, s in summary.items():
        print(cc, s)
    print('towns', sorted(newtowns))
    print(collections.Counter(r['kind'] for r in report))
    print('last codes', rcode - 1, hcode - 1)


if __name__ == '__main__':
    main()
