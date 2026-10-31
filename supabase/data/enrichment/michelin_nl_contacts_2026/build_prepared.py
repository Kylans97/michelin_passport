"""Build nl_contacts_research.csv and prepared_nl_contacts.sql.

Input: _source/nl_missing_fields_LIVE_20261031.csv, a read-only production
export (2026-10-31) of every NL restaurant and hotel with an empty
website_url or phone (export_nl_missing.sql). Websites found on 2026-10-28
come from ../michelin_nl_phones/nl_phones_all.csv and were re-checked live
on 2026-10-31 (_source/website_recheck_20261031.tsv). Every other value
below was read on 2026-10-31 from the venue's own site, at the URL given.

Run from this folder: python3 build_prepared.py
"""
import csv
import re

HERE = '.'
PREV = '../michelin_nl_phones/nl_phones_all.csv'
TODAY = '2026-10-31'

# Dutch area codes of two digits; every other fixed-line code has three.
TWO_DIGIT = {'10', '13', '15', '20', '23', '24', '26', '30', '33', '35', '36',
             '38', '40', '43', '45', '46', '50', '53', '55', '58', '70', '71',
             '72', '73', '74', '75', '76', '77', '78', '79'}


def nl(e164):
    """+31205235235 -> '+31 20 523 5235', the format restaurants.phone uses."""
    d = e164[3:]
    if d[:2] in TWO_DIGIT:
        return f'+31 {d[:2]} {d[2:5]} {d[5:]}'
    return f'+31 {d[:3]} {d[3:6]} {d[6:]}'


# Pages whose address only shows on a contact page (checked 2026-10-31).
CONTACT_PAGE = {
    'rest_0001': ('https://aandepoel.nl/contact/', 'Handweg 1 1185TS Amstelveen'),
    'rest_0014': ('https://bolenius-rembrandtpark.nl/contact',
                  'Nachtwachtlaan 20B, 1058EA Amsterdam (production address George Gershwinlaan 30 is out of date)'),
    'rest_0070': ('https://nami.nl/contact', 'Deutersestraat 39B 5266 AW Cromvoirt (production says Molenstraat 7)'),
    'rest_0101': ('https://www.studio.restaurant/info', 'Wycker Grachtstraat 24 6221 CX Maastricht (production says Kesselskade 66)'),
    'rest_0118': ('https://www.restaurantwils.nl/homenl', 'Stadionplein 26 1076 CM Amsterdam'),
}

# Website decisions that differ from the 2026-10-28 pass, or are new.
WEBSITE = {
    'rest_0092': ('https://www.restaurantwolfslaar.com/', 'name+city+address', 'confirmed',
                  "Restaurant's own site, now reachable: Wolfslaardreef 100 4834 SP Breda. Replaces the 2026-10-28 candidate "
                  "(estate page wolfslaar.com/restaurant/), which the skill rule rules out once the restaurant has its own site."),
    'rest_0086': ('https://www.restaurantaffect.com/', 'name+city+address', 'confirmed',
                  "Linked from MICHELIN's page; site footer: Thorbeckegracht 41-42 8011 VN Zwolle. Production address "
                  "(Luttenbergstraat 4) differs - MICHELIN has Thorbeckegracht 41 too."),
    'rest_0115': ('https://www.vistawillemstad.nl/', 'name+city+address', 'confirmed',
                  "Linked from MICHELIN's page; site title 'Restaurant VISTA Willemstad - Michelinster', text places it on the "
                  "Havenhoofd in Willemstad. Production address (Benedenkade 14) differs - MICHELIN has Havenhoofd 2, 4797 SR."),
    'rest_0788': ('https://restobardewoage.nl/', 'name+city+address', 'confirmed',
                  "Linked from MICHELIN's page; site footer: Meiboomsplein 1 7783 AT Gramsbergen. Name on site and on "
                  "MICHELIN is 'Restobar de Woage' (production: 'De Woage')."),
    'rest_0043': ('', 'none found', 'unclear',
                  "MICHELIN page /en/zeeland/cadzand/restaurant/demain returns 404 on 2026-10-31; 2026-10-28 pass found "
                  "demain.restaurant stripped to a group contact page and Strandhotel no longer listing it (QA-205). "
                  "Possible closure - not verified."),
    'rest_0098': ('', 'none found', 'unclear',
                  "MICHELIN page sense306045 returns 404 on 2026-10-31; no official site found on 2026-10-28 either. "
                  "Search results put it at Raadhuisstraat 1 Vught (production: Taalstraat 100). Possible closure or delisting."),
    'rest_0781': ('', 'none found', 'unclear',
                  "MICHELIN page returns 404 on 2026-10-31; reported closed in Feb 2025 (QA-203). No live site."),
}
PARENT_SITE = {
    'rest_0031': 'Restaurant page on the Landgoed Lauswolt site; no separate restaurant site exists.',
    'rest_0055': 'Restaurant page on the Grand Hotel Karel V site; karel5.nl does not load (no TLS, http 404).',
    'rest_0062': 'LIZZ page on the Weeshuis Gouda (wshs.nl) site; no separate restaurant site found.',
    'rest_0116': 'restaurantvoltaire.nl redirects here (Parc Broekhuizen estate); this is the restaurant\'s own domain.',
}

# Phones read 2026-10-31 (E.164, source, certainty, notes).
PHONE = {
    # Hotels: number shown with the hotel's own address on its own site.
    'hotel_01': ('+31205235235', 'https://www.pulitzeramsterdam.com/nl/', 'confirmed', "Footer 'Prinsengracht 323 1016 GZ Amsterdam Tel +31 (0)20 5235235'."),
    'hotel_02': ('+31703872081', 'https://www.centralparkvoorburg.com/', 'confirmed', "Footer 'Oosteinde 14 2271 EH Voorburg 070 - 387 20 81'. Restaurant and hotel share the number (also rest_0021)."),
    'hotel_03': ('+31205302010', 'https://www.dylanamsterdam.com/nl/', 'confirmed', "Footer 'Keizersgracht 384 Amsterdam T: +31 20 530 2010'."),
    'hotel_04': ('+31208880300', 'https://www.sohohouse.com/houses/soho-house-amsterdam', 'confirmed', "'Spuistraat 210 1012 VT Amsterdam ... Contact +31 20 888 0300'."),
    'hotel_05': ('+31432400040', 'https://www.vanoys.com/contact/', 'confirmed', "Contact page: 'Kasteellaan 1 6245 SB Eijsden-Margraten ... +31 43 240 0040' (also the room reservations line; sales is 0045)."),
    'hotel_06': ('+31384256789', 'https://www.pillowshotels.com/zwolle/', 'confirmed', "'Stationsweg 9 - 8011 CZ Zwolle +31 38 425 67 89'."),
    'hotel_07': ('+31436088888', 'https://www.oostwegelcollection.nl/chateau-st-gerlach/en/', 'confirmed', 'tel: link +31 43 608 88 88 on the hotel page; address on page.'),
    'hotel_08': ('+31529478777', 'https://www.mooirivier.nl/en', 'confirmed', 'tel: link +31 529 47 87 77; address on page.'),
    'hotel_09': ('+31202101218', 'https://hotelthecraftsmen.com/', 'confirmed', "'Telephone: +31 20 210 12 18'; address on page."),
    'hotel_10': ('+31702076900', 'https://deplesman.com/', 'confirmed', "Footer '+31(0)70 207 6900 welcome@deplesman.com'; address on page."),
    'hotel_11': ('+31577407393', 'https://www.roodekoper.nl/en', 'confirmed', "'Jhr. Dr. C.J. Sandbergweg 82 3852 PV Leuvenum +31 (0)577 40 73 93'."),
    'hotel_12': ('+31208020200', 'https://www.pillowshotels.com/amsterdam-mauritskade/', 'confirmed', "'Mauritskade 61 - 1092 AD Amsterdam +31 20 80 202 00'."),
    'hotel_13': ('+31433251359', 'https://www.oostwegelcollection.nl/chateau-neercanne/en', 'confirmed', "'Von Dopfflaan 10 6213 NG Maastricht ... T: +31 (0)43 325 1359'."),
    'hotel_14': ('+31202182180', 'https://www.hoteltwentyseven.com/nl/contact', 'confirmed', "Contact page 'Hotel TwentySeven ... +31 20-21 82 180 Dam 27'. Bougainville (rest_0016) has its own line, 2182."),
    'hotel_15': ('+31207223300', 'https://www.rosewoodhotels.com/en/amsterdam', 'confirmed', "'Prinsengracht 432-436, 1017 KE Amsterdam +31 20 722 3300'."),
    'hotel_16': ('+31205540600', 'https://www.tivolihotels.com/nl/tivoli-doelen', 'confirmed', "'Tivoli Doelen Amsterdam (+31) 20 55 40 600 ; (+31) 20 55 40 686' - first (main) number taken. curl gets 403; read in a browser."),
    'hotel_17': ('+31205311777', 'https://www.deleurope.com/nl/', 'confirmed', "Footer 'Nieuwe Doelenstraat 2-14 1012 CP Amsterdam +31 20 5311777'. Read in a browser."),
    # Restaurants.
    'rest_0086': ('+31382300033', 'https://www.restaurantaffect.com/', 'confirmed', "Footer 'CONTACT ... 038 23 00 033'; same number on MICHELIN."),
    'rest_0092': ('+31762014975', 'https://www.restaurantwolfslaar.com/', 'confirmed', "Restaurant's own line: 'Wolfslaardreef 100 4834 SP Breda 076 201 49 75'. Not the estate switchboard (076 560 8000)."),
    'rest_0782': ('+31703620828', 'https://restaurantzheng.com/', 'confirmed', "'Prinsestraat 33 2513 CA Den Haag +31 70 362 0828'."),
    'rest_0788': ('+31524563788', 'https://restobardewoage.nl/', 'confirmed', "Footer '0524 - 563788'; same number on MICHELIN."),
    'rest_0789': ('+31548596660', 'https://swarteruijter.nl/', 'confirmed', "'De Swarte Ruijter Holterbergweg 7 7451 JL Holten T 0548-596660'. Hotel-restaurant of the same name, one business (like De Nederlanden, De Leuf)."),
    'rest_0790': ('+31742910066', 'https://hotellansink.nl/contact/', 'confirmed', "Contact page 'C.T. Storkstraat 18 7553 AR Hengelo Bel ons +31 (0)74 291 00 66'. Hotel-restaurant of the same name, one business; the 2026-10-28 pass held it back as a switchboard."),
    'rest_0791': ('+31541551224', 'https://www.bloemenbeek.nl/', 'confirmed', "'+31 (0) 541 551 224'; address on page. Hotel-restaurant of the same name, one business; the 2026-10-28 pass held it back as a switchboard."),
    'rest_1403': ('+32483536017', 'https://suisralfberendsen.com/', 'confirmed', "'Strucht 77, 6305 AG Schin op Geul +32 483 53 60 17' - a Belgian mobile, the only number SUIS publishes."),
    # Left blank on purpose.
    'rest_0028': ('', 'https://www.cue-amsterdam.com/', 'unclear', 'Site prints +3165463526 (tel:003165463526): one digit short of a Dutch mobile. Not corrected by guessing.'),
    'rest_0031': ('', 'https://www.lauswolt.nl/eten-drinken/de-heeren-van-harinxma', 'unclear', 'Only the Landgoed Lauswolt switchboard +31 512 381 245 is shown.'),
    'rest_0055': ('', 'https://www.karelv.nl/eten-drinken/restaurant-karel-5', 'unclear', 'Only the Grand Hotel Karel V switchboard +31 30 233 7555 is shown.'),
    'rest_0062': ('', 'https://wshs.nl/eat-drink/lizz/', 'unclear', 'Only the Weeshuis Gouda switchboard +31 182 231 253 is shown.'),
    'rest_0114': ('', 'https://www.vinkeles.com/', 'unclear', "Only +31 20 530 2010, which is The Dylan's main number (hotel_03)."),
    'rest_0116': ('', 'https://parcbroekhuizen.nl/eten-drinken/restaurant-voltaire/', 'unclear', 'Only the Parc Broekhuizen estate number +31 343 745 858 is shown.'),
    'rest_0115': ('', 'https://www.vistawillemstad.nl/', 'unclear', "No number read on the own site (contact page would not load); MICHELIN lists +31 168 852 212 - one source, not the venue's own."),
    'rest_0043': ('', '', 'unclear', 'See website notes - possible closure.'),
    'rest_0098': ('', '', 'unclear', 'See website notes - possible closure; +31 73 614 4208 appears only on an aggregator.'),
    'rest_0781': ('', '', 'unclear', 'See website notes - reported closed.'),
}


def main():
    prev = {r['code']: r for r in csv.DictReader(open(PREV))}
    recheck = {l.split('\t')[0]: l.rstrip('\n').split('\t')
               for l in open('_source/website_recheck_20261031.tsv')}
    rows = list(csv.DictReader(open('_source/nl_missing_fields_LIVE_20261031.csv')))

    out = []
    for r in rows:
        code = r['code']
        if r['status'] != 'open':
            out.append(dict(code=code, table='restaurants', name=r['name'], city=r['city'], field='phone',
                            value='', value_e164='', certainty='skipped', match_basis='', source_url='',
                            notes=f"status {r['status']}: not researched (as on 2026-10-28)."))
            continue
        table = 'hotels' if r['t'] == 'H' else 'restaurants'
        if r['website_url'] == 'NULL':
            if code in WEBSITE:
                url, basis, cert, notes = WEBSITE[code]
            else:
                p = prev[code]
                url = p['official_website']
                fin = recheck[code]
                assert fin[1] == '200', code
                basis, cert = 'name+city+address', 'confirmed'
                if code in CONTACT_PAGE:
                    src, addr = CONTACT_PAGE[code]
                    check = f"re-checked {TODAY}: contact page {src} shows '{addr}'"
                elif code == 'rest_0094':
                    check = (f"re-checked {TODAY}: domain now shows a holding page ('Rijnzicht is gewoon open ... "
                             "tijdelijk offline in verband met een beveiligingsprobleem'), so the address could not be re-read")
                else:
                    check = f're-checked {TODAY}: HTTP 200, lands on {fin[2]}, venue name and city on the page'
                notes = f"Found 2026-10-28 ({p['certainty']} pass, michelin_nl_phones): {p['notes']} | {check}."
                if code in PARENT_SITE:
                    notes = PARENT_SITE[code] + ' ' + notes
            out.append(dict(code=code, table=table, name=r['name'], city=r['city'], field='website_url',
                            value=url, value_e164='', certainty=cert, match_basis=basis,
                            source_url=url or r['michelin_url'], notes=notes))
        if r['phone'] == 'NULL':
            e164, src, cert, notes = PHONE[code]
            disp = (nl(e164) if e164.startswith('+31') else
                    '+32 483 53 60 17' if e164 == '+32483536017' else '')
            assert bool(e164) == (cert == 'confirmed'), code
            out.append(dict(code=code, table=table, name=r['name'], city=r['city'], field='phone',
                            value=disp, value_e164=e164, certainty=cert, match_basis='name+city+address' if e164 else '',
                            source_url=src, notes=notes))

    cols = ['code', 'table', 'name', 'city', 'field', 'value', 'value_e164', 'certainty', 'match_basis', 'source_url', 'notes']
    with open('nl_contacts_research.csv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(out)

    ok = [o for o in out if o['certainty'] == 'confirmed']
    for o in ok:
        assert o['value'] and "'" not in o['value'], o
        if o['field'] == 'website_url':
            assert re.match(r'^https://[^ ]+$', o['value']), o

    def values(table, field):
        sel = [o for o in ok if o['table'] == table and o['field'] == field]
        return ',\n'.join(f"    ('{o['code']}', '{o['value']}')" for o in sel), len(sel)

    rw, nrw = values('restaurants', 'website_url')
    rp, nrp = values('restaurants', 'phone')
    hp, nhp = values('hotels', 'phone')
    sql = open('prepared_template.sql').read()
    sql = (sql.replace('{{RW}}', rw).replace('{{RP}}', rp).replace('{{HP}}', hp)
           .replace('{{NRW}}', str(nrw)).replace('{{NRP}}', str(nrp)).replace('{{NHP}}', str(nhp)))
    open('prepared_nl_contacts.sql', 'w').write(sql)
    print(f'rows {len(out)}; confirmed: restaurant websites {nrw}, restaurant phones {nrp}, hotel phones {nhp}; '
          f"unclear {sum(o['certainty'] == 'unclear' for o in out)}; skipped {sum(o['certainty'] == 'skipped' for o in out)}")


if __name__ == '__main__':
    main()
