#!/usr/bin/env python3
"""Build the France MICHELIN Key hotel files from production's export (research 2026-10-30).

Usage:
  python3 build_fr_key_hotels.py <first_hotel_code> <migration_name>

  first_hotel_code  first hotel code number to use (above production's max AND above
                    every code claimed by any branch or parallel session)
  migration_name    e.g. 20261023190000_add_fr_key_hotel_cities.sql

Follows ../michelin_gb_ie_2026/build_key_hotels.py and build_prepared.py (the Keys
half only: France's starred restaurants are complete and are not touched, except
for hotel links). Reads only committed files in this folder:

  _source/production_fr_export_20261030.json      export_fr_query.sql, read-only
  _source/michelin_fr_key_hotel_pages_20261030.json every Key hotel page's JSON-LD
  _source/michelin_article_keys_fr_2026.json       MICHELIN's 2026 French Key article
  _source/michelin_fr_restaurant_stay_20261030.json every French starred restaurant
                                                    page's "Stay at the hotel" card
  fr_key_hotel_contacts_research.csv               website/phone research (brief:
                                                    _source/research_brief_fr_hotels.md)
Writes: fr_key_hotels_2026.csv, match_report.csv, prepared_fr_key_hotels.sql and
../../../migrations/<migration_name>.

Rules (README.md):
  * Key and tier from each hotel page's JSON-LD `award`, checked against the article;
    addressCountry FRA only (the article's three Monaco hotels are MC, not FR);
  * existing hotels matched by MICHELIN's numeric hotel id, then checked on distance;
    fill-only for their empty contact fields; never a name match;
  * website/phone only when `confirmed` on the hotel's own site; `group` lines and HOLD
    are left out;
  * a link only when MICHELIN's restaurant page says "Stay at the hotel" for a French
    Key hotel (identity by MICHELIN hotel id); `exact` within 100 m, else `campus`;
    over LINK_MAX_M it is held back for review;
  * towns: the commune the hotel stands in. TOWN_FIX where MICHELIN names another commune
    (pin commune from geo.api.gouv.fr, confirmed on the hotel's own site); else the town of the
    restaurant MICHELIN links to the hotel; else the hotel page's locality, in production's
    spelling when it is the same name, or the Key article's spelling for a new town. Checked
    against _source/commune_check_20261030.json; TOWN_KEEP records the three exceptions.
"""
import csv, json, math, os, re, sys, unicodedata, collections

HERE = os.path.dirname(os.path.abspath(__file__))
MIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), 'migrations')
CC = 'FR'
ANNOUNCED_KEYS = '2026-09-18'   # "Clefs MICHELIN 2026 : ... la liste complète ... en France", 18 Sep 2026
EXPECT = (25, 38, 157)          # France (FRA) Key pages, 3/2/1; the article's links less its 3 Monaco hotels
LINK_MAX_M = 1000
K = {'One': 1, 'Two': 2, 'Three': 3}
# Hotels whose MICHELIN town is a different commune from the one they stand in. Each was found by the
# commune at the hotel's MICHELIN pin (geo.api.gouv.fr, _source/commune_check_20261030.json) and confirmed by
# the address printed on the hotel's own site (website_source_url, read 2026-10-30), which is also the address
# stored. id -> (official commune name, address as on the hotel's site)
TOWN_FIX = {
    '15073': ('Anglet', '1 Allée du Château, 64600 Anglet'),                          # MICHELIN: Biarritz
    '9950': ('Flayosc', 'Chemin des Imberts, 83780 Flayosc'),                         # article: Lorgues
    '12454': ('Carquefou', 'Allée de Maubreuil, 44470 Carquefou'),                    # MICHELIN: Nantes
    '9121': ('Sainte-Colombe', '2 lieu-dit Palanquey, 33350 Sainte-Colombe'),         # MICHELIN: Saint-Émilion
    '7945': ('Lavérune', 'Chemin du Mas de Biar, 34880 Lavérune'),                    # MICHELIN: Montpellier
    '211': ('Saint-Saturnin-lès-Apt', 'Les Andéols, 84490 Saint-Saturnin-lès-Apt'),   # MICHELIN: Saint Saturnin
    '6027': ('Castelnau-le-Lez', '1 boulevard Philippe Lamour, 34170 Castelnau-le-Lez'),  # MICHELIN: Montpellier
    '7332': ('Lecci', 'Route de Cala Rossa, 20137 Lecci'),                            # article: Porto-Vecchio
    '9426': ('Vauvenargues', '33 avenue des Maquisards, 13126 Vauvenargues'),         # MICHELIN: Aix-en-Provence
    '10047': ('Le Tholonet', '2250 route Cézanne, 13100 Le Tholonet'),                # MICHELIN: Aix-en-Provence
    '15016': ('Zonza', 'Lieu-dit Pinarello, 20124 Zonza'),                            # MICHELIN: Porto Vecchio
}
# Hotels whose town comes from the linked restaurant or the Key article, where MICHELIN's hotel address
# names another town: the address as printed on the hotel's own site (read 2026-10-30), naming the commune.
ADDRESS_FIX = {
    '11439': '736 Chemin des Crêtes, 83350 Ramatuelle',                                  # MICHELIN: Saint-Tropez
    '6023': 'Chemin de Smith Haut Lafitte, 33650 Martillac',                             # MICHELIN: Bordeaux; site: Bordeaux-Martillac
    '6479': '9 rue de la République, 51160 Champillon',                                  # MICHELIN: Épernay
    '8645': '2750 Route de la Cride, 13610 Le Puy-Sainte-Réparade',                      # MICHELIN: Aix-en-Provence
    '7394': '334 Rue René Vielle, 40320 Eugénie-les-Bains',                              # MICHELIN: Biarritz
    '12201': '23 route de Fougère, 41700 Cheverny',                                      # MICHELIN: Centre-Val de Loire
    '9079': 'Route de Saint-Canadet, 13610 Le Puy-Sainte-Réparade',                      # MICHELIN: Aix-en-Provence
    '7279': 'La Treyne, 46200 Lacave',                                                   # MICHELIN: Souillac
    '16381': '19 rue de la Grenouillère, 62170 La Madelaine-sous-Montreuil',             # MICHELIN: Bp 2, Montreuil-sur-Mer
    '6037': '7 Place du Chapitre, 30400 Villeneuve-lès-Avignon',                         # MICHELIN: Avignon
}
# The pin falls in another commune, but MICHELIN and the hotel's own site agree on the town: kept.
TOWN_KEEP = {
    '9955': "COMO Le Montrachet: pin falls in the neighbouring commune of Chassagne-Montrachet; MICHELIN and comohotels.com both print 10 place du Pasquier de la Fontaine, 21190 Puligny(-Montrachet)",
    '11840': "Domaine de Primard: pin falls in the neighbouring commune of Garennes-sur-Eure (Eure); MICHELIN and the hotel's site both print Route départementale 16, 28260 Guainville",
    '13558': "Cheval Blanc St-Tropez: the pin falls outside every commune polygon (no commune returned for it); MICHELIN and the hotel give Plage de la Bouillabaisse, 83990 Saint-Tropez",
}
# MICHELIN hotel pins shown wrong by two independent sources; the hotel row takes the verified point
COORD_FIX = {
    '11438': (45.4094877, 6.6338696,
              "MICHELIN's Cheval Blanc Courchevel hotel pin (45.29676, 6.57831) is 13.3 km from Courchevel 1850; its address is "
              "'Le Jardin Alpin'. MICHELIN's Le 1947 a Cheval Blanc restaurant pin (same address, 'Cheval Blanc, Le Jardin Alpin') is "
              "19 m from OpenStreetMap's Cheval Blanc hotel (way 206365327, 190 Rue du Jardin Alpin). Restaurant pin used. 2026-10-30."),
}
HOLD = {}   # ref -> reason: confirmed on the site, but not clearly this hotel's own line


def n(s):
    s = unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower()
    s = re.sub(r'\bst\b', 'saint', s)
    return re.sub(r'[^a-z0-9]', '', s)


def dist(a, b, c, d):
    R = 6371000
    p1, p2 = math.radians(a), math.radians(c)
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(d - b) / 2) ** 2
    return round(2 * R * math.asin(math.sqrt(h)))


def hid(u):
    m = re.search(r'(?:/h/|-)(\d+)/?$', (u or '').split('?')[0])
    return m.group(1) if m else None


def q(v):
    return 'NULL' if v is None or v == '' else "'" + str(v).replace("'", "''") + "'"


def rpath(u):
    """MICHELIN restaurant path without host or locale prefix: /<region>/<town>/restaurant/<slug>."""
    m = re.search(r'(/[^/]+/[^/]+/restaurant/[^/?#]+)', u or '')
    return m.group(1).lower() if m else None


def main():
    first_hcode, mig = int(sys.argv[1]), sys.argv[2]
    X = json.load(open(os.path.join(HERE, '_source/production_fr_export_20261030.json')))
    pages = json.load(open(os.path.join(HERE, '_source/michelin_fr_key_hotel_pages_20261030.json')))
    art = json.load(open(os.path.join(HERE, '_source/michelin_article_keys_fr_2026.json')))
    stay = json.load(open(os.path.join(HERE, '_source/michelin_fr_restaurant_stay_20261030.json')))
    contacts = {r['ref']: r for r in csv.DictReader(open(os.path.join(HERE, 'fr_key_hotel_contacts_research.csv')))}

    art_tier = {hid(r['href']): r['tier'] for r in art['rows']}
    art_town = {hid(h): re.sub(r'^(Auvergne-Rhône-Alpes|Bourgogne-Franche-Comté|Bretagne|Corse|Grand Est ?|Haut-de-France|'
                               r"Monaco|Normandie|Nouvelle-Aquitaine|Provence-Alpes-Côte d'Azur)", '', t.strip()).strip()
                for h, t in art['towns']}
    city_by_n = {n(c['name']): c['name'] for c in X['cities'] if c['country'] == CC}
    hotels = [h for h in X['hotels'] if h['country'] == CC]
    ex_h = {hid(h['michelin_url']): h for h in hotels}
    hurl_in_use = set(X.get('hotel_michelin_urls_in_use') or [])
    report, newtowns = [], set()
    _cc = json.load(open(os.path.join(HERE, '_source/commune_check_20261030.json')))['hotels']
    _by_name = {v['name']: v['pin_commune'] for v in _cc.values()}
    pin_commune = {id: _by_name.get(p['h1']) for id, p in pages.items()}

    def town(id, loc):
        at = art_town.get(id, '')
        if id in TOWN_FIX:
            report.append(dict(code='', name=pages[id]['h1'], kind='TOWN CORRECTED TO COMMUNE',
                               detail=f"MICHELIN's hotel page '{loc}'{f', article {at!r}' if at else ''}; the pin is in the commune of {TOWN_FIX[id][0]} (geo.api.gouv.fr) and the hotel's own site prints '{TOWN_FIX[id][1]}' -- {TOWN_FIX[id][0]} used, with that address"))
            loc = TOWN_FIX[id][0]
            if n(loc) in city_by_n:
                return city_by_n[n(loc)]
            city_by_n[n(loc)] = loc
            newtowns.add(loc)
            return loc
        pc = (pin_commune.get(id) or {}).get('nom')
        if at and pc and n(at) != n(loc) and n(at) == n(pc):
            report.append(dict(code='', name=pages[id]['h1'], kind='TOWN FROM ARTICLE',
                               detail=f"hotel page locality '{loc}'; MICHELIN's Key article prints '{at}', the commune the pin is in (geo.api.gouv.fr) -- article town used"))
            loc = city_by_n.get(n(at), at)
            if n(loc) not in city_by_n:
                city_by_n[n(loc)] = loc
                newtowns.add(loc)
            return loc
        if n(loc) in city_by_n:
            if at and n(at) != n(loc) and not at.startswith('Paris') and at not in ('Alsace', 'Centre-Val de Loire'):
                report.append(dict(code='', name=pages[id]['h1'], kind='TOWN DIFFERS FROM ARTICLE',
                                   detail=f"hotel page locality '{loc}' used (existing city); MICHELIN's Key article prints '{at}', not a production city"))
            return city_by_n[n(loc)]
        if at and n(at) == n(loc) and at != loc:
            loc = at   # same name; the article's spelling carries the accents and hyphens
        city_by_n[n(loc)] = loc
        newtowns.add(loc)
        if at and n(at) != n(loc) and not at.startswith('Paris') and at not in ('Alsace', 'Centre-Val de Loire'):
            report.append(dict(code='', name=pages[id]['h1'], kind='TOWN DIFFERS FROM ARTICLE',
                               detail=f"hotel page locality '{loc}' used (new city); MICHELIN's Key article prints '{at}'"))
        return loc

    # ---- the French Key selection, from each page's JSON-LD
    keyh, mc = [], []
    for id, p in pages.items():
        ld = p['ld']
        a = ld['address']
        if not ld.get('award'):
            continue
        keys = K[ld['award']['awardFor'].split()[0]]
        if a['addressCountry'] != 'FRA':
            (mc if a['addressCountry'] == 'MCO' else []).append(p)
            continue
        assert art_tier.get(id) == keys, (id, p['h1'], keys, art_tier.get(id))
        keyh.append(dict(id=id, name=p['h1'], keys=keys, loc=a['addressLocality'], postcode=(a.get('postalCode') or '').strip(),
                         address=TOWN_FIX[id][1] if id in TOWN_FIX else ADDRESS_FIX[id] if id in ADDRESS_FIX else ', '.join(x for x in (a.get('streetAddress'), ' '.join(y for y in ((a.get('postalCode') or '').strip(), a['addressLocality']) if y)) if x and x.strip()),
                         lat=COORD_FIX[id][0] if id in COORD_FIX else float(ld['geo']['latitude']),
                         lon=COORD_FIX[id][1] if id in COORD_FIX else float(ld['geo']['longitude']), michelin_url=ld['url'],
                         michelin_phone=ld.get('telephone')))
    cnt = collections.Counter(h['keys'] for h in keyh)
    assert (cnt[3], cnt[2], cnt[1]) == EXPECT, cnt
    for p in mc:
        report.append(dict(code='', name=p['h1'], kind='EXCLUDED (Monaco)',
                           detail=f"in MICHELIN's French Key article, but addressCountry MCO -- Monaco is its own country (MC); not part of this file"))

    # ---- existing hotels by MICHELIN id; the rest are new
    hotel_by_mid, new_hotels, key_changes, hotel_fills, out = {}, [], [], [], []
    hcode = first_hcode
    for k in sorted(keyh, key=lambda r: (-r['keys'], n(r['name']))):
        c = contacts.get(ex_h[k['id']]['code'] if k['id'] in ex_h else f"new_{k['id']}", {})
        web = c.get('website_url') if c.get('website_certainty') == 'confirmed' else None
        phone = (c.get('phone') if c.get('phone_certainty') == 'confirmed' and c.get('line_type') != 'group'
                 and c.get('ref') not in HOLD else None)
        if k['id'] in ex_h:
            h = ex_h[k['id']]
            d = dist(h['lat'], h['lon'], k['lat'], k['lon'])
            hotel_by_mid[k['id']] = dict(code=h['code'], name=h['name'], lat=h['lat'], lon=h['lon'], keys=k['keys'], new=False)
            report.append(dict(code=h['code'], name=h['name'], kind='EXISTING HOTEL MATCHED',
                               detail=f"MICHELIN id {k['id']} ({h['michelin_url']}); stored point {d} m from MICHELIN's pin; {h['keys']} Key(s) stored, {k['keys']} on MICHELIN"))
            assert d <= 500, (h['code'], d)
            if h['keys'] != k['keys']:
                key_changes.append((h['code'], k['keys'], h['keys']))
                report.append(dict(code=h['code'], name=h['name'], kind='KEY CHANGE', detail=f"{h['keys']} -> {k['keys']} (MICHELIN 2026)"))
            f = dict(code=h['code'], phone=phone if not h.get('phone') else None, website_url=web if not h.get('website_url') else None)
            if f['phone'] or f['website_url']:
                hotel_fills.append(f)
                report.append(dict(code=h['code'], name=h['name'], kind='HOTEL FILL',
                                   detail=', '.join(f'{x} {f[x]}' for x in ('phone', 'website_url') if f[x])))
            if not re.match(r'^https://guide\.michelin\.com/en/hotels-stays/', h['michelin_url'] or ''):
                report.append(dict(code=h['code'], name=h['name'], kind='MICHELIN URL FORM',
                                   detail=f"stored {h['michelin_url']}; MICHELIN's canonical is {k['michelin_url']} -- left as is (fill-only)"))
            code, tw = h['code'], h['city']
        else:
            if k['michelin_url'] in hurl_in_use:
                report.append(dict(code='', name=k['name'], kind='HOTEL URL ALREADY IN USE', detail=k['michelin_url'] + ' -- not added'))
                continue
            code = f'hotel_{hcode}'; hcode += 1
            tw = None   # set after the links, below
            row = dict(mid=k['id'], loc=k['loc'], code=code, name=k['name'], keys=k['keys'], town=tw, address=k['address'], lat=k['lat'], lon=k['lon'],
                       michelin_url=k['michelin_url'], website_url=web, phone=phone)
            new_hotels.append(row)
            hotel_by_mid[k['id']] = dict(code=code, name=k['name'], lat=k['lat'], lon=k['lon'], keys=k['keys'], new=True)
            if not web or not phone:
                report.append(dict(code=code, name=k['name'], kind='HOTEL CONTACT MISSING',
                                   detail=('no website; ' if not web else '') + ('no phone; ' if not phone else '')
                                   + f"website {c.get('website_certainty') or 'not researched'}, phone {c.get('phone_certainty') or 'not researched'}"
                                   + (f", line_type {c.get('line_type')}" if c.get('line_type') == 'group' else '')
                                   + (f" -- {HOLD[c.get('ref')]}" if c.get('ref') in HOLD else '')))
        out.append(dict(code=code, michelin_id=k['id'], name=k['name'], keys=k['keys'], new='yes' if k['id'] not in ex_h else 'no',
                        city=tw, michelin_locality=k['loc'], article_town=art_town.get(k['id'], ''), address=k['address'],
                        lat=k['lat'], lon=k['lon'], michelin_url=k['michelin_url'], michelin_phone=k['michelin_phone'],
                        website_url=web or '', phone=phone or '',
                        website_certainty=c.get('website_certainty') or 'not researched', phone_certainty=c.get('phone_certainty') or 'not researched',
                        line_type=c.get('line_type') or '', website_source_url=c.get('website_source_url') or '',
                        phone_source_url=c.get('phone_source_url') or '',
                        notes=' | '.join(x for x in (COORD_FIX.get(k['id'], (0, 0, None))[2], HOLD.get(c.get('ref')), c.get('notes')) if x)))
    lost = [h for m, h in ex_h.items() if m not in hotel_by_mid and h['keys'] is not None]
    for h in lost:
        report.append(dict(code=h['code'], name=h['name'], kind='KEY NOT IN MICHELIN 2026',
                           detail=f"stored michelin_keys {h['keys']}; MICHELIN's page carries no Key -- left untouched, needs a decision"))
    for h in hotels:
        if hid(h['michelin_url']) not in hotel_by_mid and h['keys'] is None:
            report.append(dict(code=h['code'], name=h['name'], kind='NOT A KEY HOTEL (unchanged)',
                               detail=f"michelin_keys NULL in production and no Key on MICHELIN ({h['michelin_url']}); in `hotels` for another reason (World's 50 Best) -- untouched"))

    # ---- links from MICHELIN's "Stay at the hotel"
    by_path = {}
    for u, s in stay.items():
        if s.get('status') == 200:
            by_path[rpath(s.get('final') or u)] = s
            by_path.setdefault(rpath(u), s)
    # MICHELIN's own restaurant pins, read by the France stars session (2026-10-28)
    mpin = {rpath(m['michelin_url']): (float(m['latitude']), float(m['longitude']))
            for m in csv.DictReader(open(os.path.join(HERE, '../michelin_fr_stars_2026/michelin_fr_pages.csv'))) if m['latitude']}
    existing_links = {(l['hotel_code'], l['restaurant_code']): l['confidence'] for l in (X.get('links') or [])}
    linked_r = {l['restaurant_code'] for l in (X.get('links') or [])}
    new_links, unread = [], []
    for r in X['restaurants']:
        s = by_path.get(rpath(r['michelin_url']))
        if not s:
            unread.append(r)
            continue
        st = s.get('stay')
        if not st or not st.get('href'):
            continue
        sid = hid(st['href'])
        h = hotel_by_mid.get(sid)
        if not h:
            report.append(dict(code=r['code'], name=r['name'], kind='STAY AT A NON-KEY HOTEL',
                               detail=f"MICHELIN 'Stay at the hotel' -> {st['href']} ({st['name']}), {st['keys']} Key icon(s); not a French Key hotel -- no link; property_name not written (production has none for FR; see README)"))
            continue
        g = mpin.get(rpath(r['michelin_url']))
        if not g:
            report.append(dict(code=r['code'], name=r['name'], kind='HOTEL LINK HELD (NO MICHELIN PIN)',
                               detail=f"MICHELIN 'Stay at the hotel' -> {h['code']} {h['name']}, but no MICHELIN restaurant pin in ../michelin_fr_stars_2026/michelin_fr_pages.csv -- held"))
            continue
        g = dict(latitude=g[0], longitude=g[1])
        d = dist(float(g['latitude']), float(g['longitude']), h['lat'], h['lon'])   # MICHELIN's restaurant pin
        dp = dist(r['lat'], r['lon'], float(g['latitude']), float(g['longitude']))
        if dp > 500:
            report.append(dict(code=r['code'], name=r['name'], kind='STORED RESTAURANT COORDINATES OFF',
                               detail=f"production's point is {dp} m from MICHELIN's restaurant pin ({g['latitude']}, {g['longitude']}) -- not changed here"))
        conf = 'exact' if d <= 100 else 'campus'
        if (h['code'], r['code']) in existing_links:
            report.append(dict(code=r['code'], name=r['name'], kind='HOTEL LINK ALREADY PRESENT',
                               detail=f"{h['code']} {h['name']} ({existing_links[(h['code'], r['code'])]}); MICHELIN agrees; MICHELIN restaurant pin {d} m from the hotel's"))
            continue
        if d > LINK_MAX_M:
            report.append(dict(code=r['code'], name=r['name'], kind='HOTEL LINK HELD (DISTANCE)',
                               detail=f"MICHELIN 'Stay at the hotel' -> {h['code']} {h['name']}, but pins {d} m apart -- held for review"))
            continue
        if r['property_name']:
            report.append(dict(code=r['code'], name=r['name'], kind='PROPERTY NAME TO REVIEW',
                               detail=f"property_name '{r['property_name']}' while MICHELIN links it to Key hotel {h['code']} {h['name']} -- not changed"))
        ev = (f"MICHELIN restaurant page 'Stay at the hotel' -> {st['href']} ({st['name']}), a {h['keys']}-Key hotel; "
              f"MICHELIN's restaurant pin {d} m from the hotel's MICHELIN pin. 2026-10-30.")
        new_links.append((h['code'], r['code'], conf, ev))
        report.append(dict(code=r['code'], name=r['name'], kind=f'HOTEL LINK ({conf})', detail=f"{h['code']} {h['name']}: {ev}"))
    key_pins = [(h['lat'], h['lon']) for h in hotel_by_mid.values()]
    far = 0
    for r in unread:
        near = min(dist(r['lat'], r['lon'], a, b) for a, b in key_pins) if r['lat'] is not None else None
        if near is not None and near > LINK_MAX_M:
            far += 1
            continue
        report.append(dict(code=r['code'], name=r['name'], kind='RESTAURANT PAGE NOT READ',
                           detail=f"{r['michelin_url'] or 'no michelin_url'}: within {LINK_MAX_M} m of a Key hotel pin ({near} m) but not in MICHELIN's live French starred listing (2026-10-30); no link considered"))
    report.append(dict(code='', name=f'{far} restaurants', kind='NOT CHECKED FOR A LINK',
                       detail=f"production point more than {LINK_MAX_M} m from every French Key hotel pin; their MICHELIN pages were not read (MICHELIN rate-limits the crawl)"))

    # ---- towns of the new hotels: a hotel MICHELIN links from a starred restaurant takes that
    #      restaurant's town (production's city, MICHELIN's restaurant-page town); else town()
    rest_city = {r['code']: r['city'] for r in X['restaurants']}
    for h in new_hotels:
        rc = sorted({rest_city[r] for hc, r, c, ev in new_links if hc == h['code']})
        if len(rc) == 1 and h['mid'] not in TOWN_FIX:
            h['town'] = rc[0]
            if n(rc[0]) != n(h['loc']):
                report.append(dict(code=h['code'], name=h['name'], kind='TOWN FROM LINKED RESTAURANT',
                                   detail=f"hotel page locality '{h['loc']}'; the restaurant MICHELIN links to this hotel is in '{rc[0]}' (production city) -- used"))
        else:
            assert len(rc) <= 1, (h['name'], rc)
            h['town'] = town(h['mid'], h['loc'])
    # every new hotel's town must be the commune at its pin, a place inside it that is not itself a commune
    # (Val Thorens, Pyla-sur-Mer, Méribel), or a recorded TOWN_KEEP
    cc_ = json.load(open(os.path.join(HERE, '_source/commune_check_20261030.json')))['hotels']
    bad = []
    for h in new_hotels:
        c = next((v for v in cc_.values() if v['name'] == h['name']), None)
        assert c, h['name']
        pc = c['pin_commune']
        same_named = c['city_is_commune'] if c['city'] == h['town'] else None
        if h['mid'] in TOWN_KEEP or (pc and n(pc['nom']) == n(h['town'])):
            continue
        if same_named is None:   # the town changed after the check was taken: it must be the pin's commune
            bad.append((h['name'], h['town'], pc and pc['nom']))
        elif same_named:
            bad.append((h['name'], h['town'], pc and pc['nom']))
    assert not bad, bad
    for id, why in TOWN_KEEP.items():
        report.append(dict(code=hotel_by_mid[id]['code'], name=hotel_by_mid[id]['name'], kind='TOWN KEPT (PIN IN ANOTHER COMMUNE)', detail=why))
    town_by_code = {h['code']: h['town'] for h in new_hotels}
    for o in out:
        if o['code'] in town_by_code:
            o['city'] = town_by_code[o['code']]
    last_hotel = hcode - 1
    keycnt = collections.Counter(h['keys'] for h in hotel_by_mid.values())
    hotel_codes = [h['code'] for h in hotel_by_mid.values()]

    # ---- CSVs
    with open(os.path.join(HERE, 'fr_key_hotels_2026.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(out[0])); w.writeheader(); w.writerows(out)
    with open(os.path.join(HERE, 'match_report.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['code', 'name', 'kind', 'detail']); w.writeheader(); w.writerows(report)

    # ---- migration
    towns = sorted(newtowns, key=n)
    M = f"""-- MICHELIN Key hotels, France 2026: the city prerequisite for the Key hotels added by
-- supabase/data/enrichment/michelin_fr_keys_2026/prepared_fr_key_hotels.sql.
-- Generated by build_fr_key_hotels.py from production's export of {X['exported_at'][:10]}
-- (written 2026-10-30). Filename timestamp is a sequence number only. Names are the
-- hotel page's locality on guide.michelin.com, in the spelling of MICHELIN's 2026
-- French Key article where the two are the same name. None exists in production's
-- export, compared accent-, case-, space-, hyphen- and St/Saint-insensitively.
-- region and postal_municipality left NULL, matching the existing rows. Idempotent:
-- ON CONFLICT targets cities_unique_key.

begin;

insert into public.cities (country_code, name, region)
values
{(','+chr(10)).join(f"  ('{CC}', {q(t)}, NULL)" for t in towns)}
on conflict (country_code, name, coalesce(region, '')) do nothing;

commit;
"""
    open(os.path.join(MIG_DIR, mig), 'w').write(M)

    # ---- SQL
    nm = lambda rows: ', '.join(f"({q(h['code'])}, {q(h['name'])})" for h in rows)
    P = [f"""-- MICHELIN Key hotels, France 2026 (prepared {X['exported_at'][:10]} export, written 2026-10-30).
-- Adds every French MICHELIN Key hotel missing from `hotels`, gives every French Key hotel
-- its current 2026 Key row, fills empty contact fields on existing ones (fill-only), and
-- links French starred restaurants to Key hotels where MICHELIN's restaurant page says
-- "Stay at the hotel". Generated by build_fr_key_hotels.py; evidence in
-- fr_key_hotels_2026.csv and match_report.csv, decisions in README.md.
--
-- Prerequisite: supabase/migrations/{mig} (new towns).
-- One transaction; every check raises and rolls the whole file back.
-- Run: supabase db query --linked -f <absolute path to this file>

begin;

do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len(hotels)} then raise exception '{CC}: expected {len(hotels)} hotels (export), found % -- production changed, re-check', n; end if;
  select count(*) into n from (values {nm(hotels)}) e(code, name)
   where not exists (select 1 from public.hotels h where h.hotel_code = e.code and h.name = e.name and h.country_code = '{CC}');
  if n <> 0 then raise exception '{CC}: % exported hotel codes no longer carry their exported name', n; end if;
  select count(*) into n from public.restaurants where country_code = '{CC}';
  if n <> {len(X['restaurants'])} then raise exception '{CC}: expected {len(X['restaurants'])} restaurants (export), found % -- production changed, re-check', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.restaurants r on r.id = hr.restaurant_id where r.country_code = '{CC}';
  if n <> {len(X.get('links') or [])} then raise exception '{CC}: expected {len(X.get('links') or [])} restaurant hotel links (export), found %', n; end if;
  if exists (select 1 from public.hotels where hotel_code ~ '^hotel_[0-9]+$'
              and substring(hotel_code from 7)::int between {first_hcode} and {last_hotel}) then
    raise exception 'hotel codes hotel_{first_hcode}..hotel_{last_hotel} are no longer free -- re-check';
  end if;
  if exists (select 1 from public.award_history where award_type = 'michelin_keys' and is_current and guide_year <> 2026) then
    raise exception 'current michelin_keys rows are not all guide_year 2026 -- decide the year explicitly';
  end if;
end $$;"""]
    if new_hotels:
        P.append(f"""
-- 1. French MICHELIN Key hotels missing from `hotels` ({len(new_hotels)})
create temp table _new_hotels_fr (code text, name text, keys smallint, city text, address text, lon float8, lat float8,
                               michelin_url text, website_url text, phone text) on commit drop;
insert into _new_hotels_fr values
{(','+chr(10)).join(f"    ({q(h['code'])}, {q(h['name'])}, {h['keys']}::smallint, {q(h['town'])}, {q(h['address'])}, {h['lon']}, {h['lat']}, {q(h['michelin_url'])}, {q(h['website_url'])}, {q(h['phone'])})" for h in new_hotels)};
do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_hotels_fr x
   where (select count(*) from public.cities c where c.country_code = '{CC}' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'hotel city does not resolve to exactly one {CC} row (run the migration first?): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_hotels_fr x join public.hotels h on h.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'hotel already present (michelin_url): %', bad; end if;
end $$;
insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url, website_url, phone)
select x.code, x.name, x.keys,
       (select c.id from public.cities c where c.country_code = '{CC}' and c.name = x.city), '{CC}',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography,
       x.michelin_url, x.website_url, x.phone
  from _new_hotels_fr x;""")
    if key_changes:
        P.append(f"""
-- 1b. Key changes on existing hotels
create temp table _kchg_fr (code text primary key, keys smallint, was smallint) on commit drop;
insert into _kchg_fr values
{(','+chr(10)).join(f"    ({q(c)}, {k}, {w})" for c, k, w in key_changes)};
update public.award_history a set is_current = false from public.hotels h, _kchg_fr k
 where h.id = a.entity_id and h.hotel_code = k.code and a.entity_type = 'hotel' and a.award_type = 'michelin_keys' and a.is_current;
update public.hotels h set michelin_keys = k.keys, updated_at = now() from _kchg_fr k where h.hotel_code = k.code and h.michelin_keys = k.was;""")
    P.append(f"""
-- 1c. current 2026 Key row for every French Key hotel that lacks one (the new rows above, and
--     existing FR hotels the August World's 50 Best import left without one; PE_REPORT finding 1)
insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '{ANNOUNCED_KEYS}'
  from public.hotels h
 where h.hotel_code = any(array[{', '.join(q(c) for c in hotel_codes)}])
   and not exists (select 1 from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
                    and a.award_type = 'michelin_keys' and a.is_current);""")
    if hotel_fills:
        P.append(f"""
-- 1d. existing FR hotels, fill-only (never overwrites)
create temp table _hfill_fr (code text primary key, phone text, website_url text) on commit drop;
insert into _hfill_fr values
{(','+chr(10)).join(f"    ({q(f['code'])}, {q(f['phone'])}, {q(f['website_url'])})" for f in hotel_fills)};
update public.hotels h set phone = f.phone, updated_at = now() from _hfill_fr f where h.hotel_code = f.code and f.phone is not null and h.phone is null;
update public.hotels h set website_url = f.website_url, updated_at = now() from _hfill_fr f where h.hotel_code = f.code and f.website_url is not null and h.website_url is null;""")
    if new_links:
        P.append(f"""
-- 2. links to French Key hotels, from MICHELIN's "Stay at the hotel" ({len(new_links)})
create temp table _links_fr (hotel_code text, restaurant_code text, confidence text, evidence text) on commit drop;
insert into _links_fr values
{(','+chr(10)).join(f"    ({q(h)}, {q(r)}, {q(c)}, {q(ev)})" for h, r, c, ev in new_links)};
do $$
declare n int;
begin
  select count(*) into n from _links_fr l
   where not exists (select 1 from public.hotels h where h.hotel_code = l.hotel_code and h.country_code = '{CC}')
      or not exists (select 1 from public.restaurants r where r.restaurant_code = l.restaurant_code and r.country_code = '{CC}');
  if n <> 0 then raise exception '% links point at a missing hotel or restaurant', n; end if;
  select count(*) into n from _links_fr l join public.restaurants r on r.restaurant_code = l.restaurant_code
   where r.property_name is not null;
  if n <> 0 then raise exception '% linked restaurants carry a property_name -- review first', n; end if;
end $$;
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, l.confidence, l.evidence, now()
  from _links_fr l join public.hotels h on h.hotel_code = l.hotel_code join public.restaurants r on r.restaurant_code = l.restaurant_code
on conflict (hotel_id, restaurant_id) do nothing;""")
    lost_codes = [h['code'] for h in lost]
    excl = f" and hotel_code <> all(array[{', '.join(q(c) for c in lost_codes)}])" if lost_codes else ''
    P.append(f"""
-- post-conditions: MICHELIN's 2026 French Keys, {keycnt[3]}/{keycnt[2]}/{keycnt[1]}
do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 3{excl};
  if n <> {keycnt[3]} then raise exception 'expected {keycnt[3]} three-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 2{excl};
  if n <> {keycnt[2]} then raise exception 'expected {keycnt[2]} two-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}' and michelin_keys = 1{excl};
  if n <> {keycnt[1]} then raise exception 'expected {keycnt[1]} one-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = '{CC}';
  if n <> {len(hotels) + len(new_hotels)} then raise exception 'expected {len(hotels) + len(new_hotels)} FR hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = '{CC}' and h.michelin_keys is not null{excl.replace('hotel_code', 'h.hotel_code')}
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception '% Key hotels without exactly one matching current Key row', n; end if;
  select count(*) into n from public.hotel_restaurants hr join public.restaurants r on r.id = hr.restaurant_id where r.country_code = '{CC}';
  if n <> {len(X.get('links') or []) + len(new_links)} then raise exception 'expected {len(X.get('links') or []) + len(new_links)} FR restaurant hotel links, found %', n; end if;
  select count(*) into n from public.restaurants r where r.country_code = '{CC}' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '% restaurants have both a hotel link and a property_name', n; end if;
end $$;

commit;
""")
    open(os.path.join(HERE, 'prepared_fr_key_hotels.sql'), 'w').write('\n'.join(P))
    kinds = collections.Counter(r['kind'] for r in report)
    print(dict(keys=dict(keycnt), new_hotels=len(new_hotels), websites=sum(1 for h in new_hotels if h['website_url']),
               phones=sum(1 for h in new_hotels if h['phone']), fills=len(hotel_fills), key_changes=len(key_changes),
               links=len(new_links), towns=len(towns), codes=f'hotel_{first_hcode}..hotel_{last_hotel}'))
    print(dict(kinds))


if __name__ == '__main__':
    main()
