# Contact fields — MICHELIN Key hotels, Spain (2026-10-29)

Status: **PREPARED — NOT APPLIED.**

| File | What it is |
|---|---|
| `prepared_es_hotel_contacts.sql` | One guarded transaction: 109 `michelin_url`, 107 `website_url`, 104 `phone` |
| `es_hotels_all.csv` | One row per hotel (109): value, status, source URL, how it was confirmed, notes |
| `_source/es_michelin_match.txt` | The MICHELIN page matched to each hotel, with distances, postcode, Keys and MICHELIN's printed phone |
| `_source/research_brief.md` | The rules the website/phone research followed |

## Scope

Read-only production export, 2026-10-29: every `hotels` row with
`country_code = 'ES'` and `michelin_keys` set. That is 109 rows. Before this pass:

| Field | Already set | Empty |
|---|---|---|
| `phone` | 2 (Four Seasons Madrid, Mandarin Oriental Ritz) | 107 |
| `website_url` | 2 (Atrio, Mandarin Oriental Ritz) | 107 |
| `michelin_url` | 0 | 109 |

The file fills only the empty fields. It never touches a field that is
already set.

## Result

| Field | Confirmed (in the SQL) | Unclear | Not found |
|---|---|---|---|
| `michelin_url` | 109 | 0 | 0 |
| `website_url` | 107 | 0 | 0 |
| `phone` | 104 | 2 | 1 |

Left NULL:

- **hotel_551 Little Beach House Barcelona.** The Soho House page's own
  structured data gives +34 932 20 46 00. That is Soho House Barcelona's
  number (hotel_569) in the city, so it may not be Garraf's line. MICHELIN
  prints +34 935 22 15 52, which the site does not show.
- **hotel_504 Cap Menorca.** The only number on the site, +34 871 047 217, sits
  next to `booking@` and is not labelled as the hotel's line. MICHELIN prints
  +34 971 489 191, which is Faustino Gran's number. Both hotels belong to the
  same group, Mare e Terra.
- **hotel_566 Casa Beatnik.** The site prints no phone number on any page,
  only an email address. MICHELIN's "076 556 75 75" is not a valid Spanish
  number.

## How values were confirmed

**MICHELIN URL.** All 422 hotel pages in MICHELIN's Spain listing were read in
a real browser, including each page's JSON-LD (`Hotel`: name, address, geo,
telephone, award). Each production row was matched to the nearest MICHELIN
page by **coordinates**, never by name, and then checked on postcode.

- **106 matched directly.** The median distance is 13 m, and 103 are within
  300 m. Where another MICHELIN hotel stands almost as close, the street and
  number on the MICHELIN page decided the match:
  - CoolRooms Villapanés: 38 m against 40 m to Hospes Casas del Rey de Baeza;
    Santiago 31 matches.
  - Hotel Arts: 123 m against 127 m to Sofitel Skipper; Marina 19-21 matches.
  - Four Seasons Madrid: 21 m against 44 m; Calle de Sevilla 3 matches.
- **3 were missing from the listing.** These are Helguera (hotel_473),
  Fairmont La Hacienda (hotel_527) and Palacio de Luces (hotel_549). They were
  found through MICHELIN's own `/h/<id>` short links, and their JSON-LD
  coordinates are within about 60 m of ours.
  - Their working English path keeps MICHELIN's capitalised city segment,
    e.g. `/en/hotels-stays/Santander/...`. The lower-case form returns 404.
- **Format.** Every URL uses `https://guide.michelin.com/en/hotels-stays/<city>/<slug>`,
  the same form as the existing NL/US/PE rows.
- **Uniqueness.** `michelin_url` is unique on `hotels`, and the SQL refuses to
  run if another row already holds one of these URLs. Six Senses Ibiza
  (hotel_698, not a Key row) holds its own URL, which does not collide.

**Website and phone.** Research ran in four parallel batches. Each value was
read on the hotel's own site, or on the property's page on the brand's site,
and confirmed by **name + city + address on that page**. Afterwards this
session re-fetched every confirmed phone's source page and checked that the
digits appear on it:

- 95 checked by plain fetch;
- 9 checked in the built-in browser, because Marriott, Four Seasons, Anantara,
  Meliá and The One block plain fetches.

All 104 were found.

- **Not used as a source:** MICHELIN's printed number was a cross-check only.
  OTA, Google and search snippets were never used.
- **Format:** phones are stored as `+34` followed by the hotel's own grouping,
  like the earlier PE and Ritz hotel values.
- **Basis name + city only (no street printed on the site):** Son Bunyola,
  Helguera, Cortijo del Marqués, Torre del Marqués and Anantara. For
  Helguera, the site's footer prints the non-Cantabrian postcode 12947, which
  looks like an error on the site.

### Phone lines for a reviewer to note

These meet the rule (own site's number) but are not a plain "reception" line:

- **Labelled reservations, and the only number on the site:** Abadía Retuerta
  (+34 983 687 600), Petunia (+34 971 808 197) and Vincci Unuk
  (+34 955 26 64 99, labelled "Venta Telefónica").
  - Petunia's number comes from hotelpetunia.com, which looks dormant. The
    number does match MICHELIN. The website stored is the Beaumier property
    page instead.
- **The site's hotel line, where MICHELIN prints a reservations or central line:**

  | Hotel | Stored (site's hotel line) | MICHELIN prints |
  |---|---|---|
  | Sant Francesc | 971 495 000 | 971 495 131 |
  | Bahía del Duque | 922 74 69 00 | 922 74 69 32 |
  | Palacio de los Duques | 915 41 67 00 | 912 76 47 47 (Meliá central) |
  | Only YOU Boutique | 910 05 22 22 | 910 05 27 46 (group reservations) |
  | Wittmore | 935 500 885 | 937 378 312 |
- **MICHELIN's number appears nowhere on the site; the site's own is stored:**
  Santa María Briones (941 99 15 99), Serras (936 061 632) and Cap Vermell
  (871 811 222).
- **Mobile-range number, the only line the hotel prints:** Can Mascort,
  Rural Sant Ignasi and Puntagrande.

### Websites that are a group or brand page

Many properties' own domains now redirect to a group site. In each case the
stored URL is the property page the redirect lands on:

- **Único Hotels:** The Principal, Único, Finca Serena, Mas de Torrent and
  Palacio de Luces.
- **Hidden Hotels:** Cavalta, Seda Club, Gran Hotel Inglés and Posada Terra
  Santa.
- **Barceló:** the three Royal Hideaway hotels.
- **Others:** Hotel Arts goes to Ritz-Carlton, Yurbban Passage to
  hotels.yurbban.com, and Brach to Evok Collection.

## Wrong-record traps hit (all rejected)

- **The Palace and Santo Mauro (Marriott codes).** Marriott's `madlc-` code is
  **Santo Mauro**; The Palace is `madcl-`. The research brief's own example
  URL had them crossed, and batch 4 caught it. Both rows now carry the
  correct code, re-checked in the browser.
- **Hotel Maria Cristina:** hotelmariacristina.com is the Hotel María
  Cristina in **Toledo**.
- **Name-alike domains that are a different business:**
  - canmascort.com is a restaurant in Quart; the hotel is canmascortecohotel.com.
  - torredelmarques.com is an apartment rental in Asturias; the hotel is
    hoteltorredelmarques.com.
  - cavalta.com is an unrelated placeholder.
- **Parked or broken domains:**
  - lacaminera.com is parked (for sale); the hotel is hotellacaminera.com.
  - maslazuli.com is parked; the hotel is hotelmaslazuli.es.
  - www.cristinebedfor.com has an invalid certificate; the hotel is on
    cristinebedforhotel.com/menorca/.
  - brachmadrid.com serves a certificate for another domain.
- **Nobis:** nobishotel.se/palma lands on Nobis **Stockholm**; Palma is
  nobishotel.es.
- **Sibling properties kept apart:**
  - Only YOU Atocha / Boutique / Valencia;
  - CoolRooms Atocha / Villapanés;
  - Mercer Barcelona / Sevilla;
  - Cristine Bedfor Mahón / Málaga / Sevilla;
  - Royal Hideaway Corales Suites / Corales Villas;
  - Ohla Eixample / Ohla Barcelona;
  - Soho House Barcelona / Little Beach House.
- **Anantara:** the obvious property URL
  (`/en/villa-padierna-palace-benahavis-marbella`) is a 404. The real page is
  `/en/villa-padierna-marbella`.

## Data problems found (logged, not fixed)

- **QA-260 — Key counts differ from MICHELIN's live pages for 12 hotels.**
  - **MICHELIN shows no Key on the hotel's page, but production has one:**
    Only YOU Atocha, Ohla Eixample, The Principal Madrid, Little Beach House
    and Yurbban Passage. These pages are still in MICHELIN's Spain hotel
    listing.
  - **MICHELIN shows more Keys than production:**

    | Hotel | Production | MICHELIN |
    |---|---|---|
    | Cap Rocat | 1 | 2 |
    | Can Cera | 1 | 2 |
    | Esperit Roca | 1 | 2 |
    | Cap Vermell | 1 | 2 |
    | Marbella Club | 1 | 2 |
    | Casa Beatnik | 1 | 2 |
    | Torre del Marqués | 2 | 3 |

  `michelin_url` is filled for all 12, because each page is still the hotel's
  own. The Key values are untouched.
- **QA-261 — 17 hotels hold a Key on MICHELIN's Spain listing but are not in
  `hotels`.** The list is in the QA entry.
- **QA-262 — Location and address differences.**
  - Stored coordinates are 1.0–3.1 km from MICHELIN's pin for Es Racó d'Artà,
    La Torre del Visco and Peralada. The match is not in doubt: postcode and
    street agree, and the next MICHELIN hotel is 4.9 km or more away.
  - Smaller address differences:
    - Alma: the site says Mallorca 271, we store 269.
    - Fontsanta: MICHELIN has postcode 07639 and the site 07630; we store 07638.
    - Es Racó: the site has postcode 07570, we store 07579.
    - Fairmont: MICHELIN has 11310, we store 11360.
    - Canfranc: the site says Av. Fernando el Católico, we store Calle Huesca.
- **QA-263 — Three hotels have no confirmable phone:** Little Beach House,
  Cap Menorca and Casa Beatnik, as described above.

Also noted:

- **Son Brull** is closed for renovation until 11 April (temporary). Its
  `status` was not changed.
- **MICHELIN's Spain listing omits pages.** It shows "422 hotels" but yields
  411 unique pages; three of ours were among the missing ones.

## Testing

The SQL was run on a scratch PostgreSQL 17 database seeded with the 109
exported rows plus hotel_698. The `hotels` table there was minimal: code,
name, country, keys, the three fields, and unique `hotel_code` and
`michelin_url`.

- **First run:** commits 109 / 107 / 104 updates. Afterwards 106 phones and
  109 websites and MICHELIN URLs are set, and the pre-existing values
  (Four Seasons phone, Atrio website, Ritz phone and website) are unchanged.
- **Second run:** raises "field already set since the export" and changes
  nothing.
- **A changed hotel name:** raises "not the expected Spanish Key hotel" and
  rolls back.
- **A MICHELIN URL already held by another row:** raises and rolls back.

Not tested: the production table's own triggers. `hotels_updated_at` sets
`updated_at`, so the file does not.

## Next countries

By number of Key hotels: IT 155, DE 126, JP 118, AT 48, CH 42, BE 15, HU 12,
PL 11, HR 10.

The MICHELIN step is the same for every country:

1. list `/en/hotels-stays/<country>` page by page;
2. read each page's JSON-LD;
3. match on coordinates;
4. use `/h/<id>` for pages the listing misses.

Japan's addresses and its brand-site coverage will need their own care.
