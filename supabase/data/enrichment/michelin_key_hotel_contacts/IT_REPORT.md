# Contact fields — MICHELIN Key hotels, Italy (2026-10-29)

Status: **APPLIED 2026-10-29** (see the Michelin_Database CHANGELOG). This pass uses the same method and
rules as Spain (`ES_REPORT.md`). Only the differences are written out here.

| File | What it is |
|---|---|
| `prepared_it_hotel_contacts.sql` | One guarded transaction: 150 `michelin_url`, 140 `website_url`, 137 `phone` |
| `it_hotels_all.csv` | One row per hotel (155): value, status, source URL, how confirmed, notes |
| `_source/it_michelin_match.txt` | The MICHELIN page matched to each hotel |
| `_source/research_brief_it.md` | The research rules, with Italian phone format |

## Scope

Read-only production export, 2026-10-29: every `hotels` row with
`country_code = 'IT'` and `michelin_keys` set, 155 rows in all.

Before this pass:

| Field | Already set | Empty |
|---|---|---|
| `phone` | 14 | 141 |
| `website_url` | 14 | 141 |
| `michelin_url` | 5 | 150 |

## Result

| Field | Confirmed (in the SQL) | Unclear | Not found |
|---|---|---|---|
| `michelin_url` | 150 | 0 | 0 |
| `website_url` | 140 | 1 | 0 |
| `phone` | 137 | 4 | 0 |

These are left NULL:

- **hotel_409 La Palma Capri, website and phone.** oetkercollection.com
  redirects to oetkerhotels.com, which shows a security checkpoint to plain
  fetches. In the browser it rendered an empty page.
- **hotel_331 Hotel Lungarno, phone.** The Lungarno Collection page prints
  "+39 055 396 1" with an empty `tel:` link, which looks truncated. MICHELIN
  prints +39 055 27261.
- **hotel_401 Portrait Milano, phone.** The page prints "+39 023 6799 5800",
  11 digits and oddly grouped. MICHELIN prints +39 02 50043661.
- **hotel_458 Palazzo Avino, phone.** The number is not in the static HTML,
  and the site then refused connections, from the browser too. MICHELIN
  prints +39 089 818181.

**Phone format.** Italian landlines keep their leading 0 after +39, so a
number is stored as `+39 089 871012`, not `+39 89 871012`. Every confirmed
number has 6–11 digits after +39 and starts with 0 or 3.

## How values were confirmed

### MICHELIN URLs

MICHELIN's Italy listing says "794 hotels" but yields 757 unique pages. I read
every page's JSON-LD in the browser. MICHELIN began rate-limiting after about
430 pages, so the rest were fetched slowly in the background.

Matching was on **coordinates**, then checked against **street and house
number**, never name.

**8 nearest-page matches were wrong and were rejected.** In each case the
hotel's own page was simply not in the listing, so the nearest page belonged
to a neighbour:

| Hotel | Nearest page, rejected |
|---|---|
| Le Sirenuse | Hotel Poseidon (219 m) |
| Bellevue Syrene | Palazzo Marziale |
| Violino d'Oro | Nolinski |
| Borgo Santandrea | Monastero Santa Rosa |
| Bulgari Roma | Palazzo Ripetta |
| Four Seasons Firenze | Hotel Regency |
| San Domenico Palace | Metropole Taormina |
| Orient Express La Minerva | Hotel Scenario |

Coordinates alone would have written these. Six of them now point to the
hotel's own page. San Domenico Palace and La Minerva already had their URLs.

**Final tally:**

- **134 matched from the listing.** The median distance is 11.5 m.
  - 12 had another MICHELIN hotel within three times the distance. All 12
    were settled by street and number. Examples: Hotel Vilòn (5 m against
    43 m), Stella d'Italia (2 m against 19 m), Palazzo Ripetta (4 m against
    41 m).
- **16 were missing from the listing.** I found them through search on
  guide.michelin.com, then read each one through MICHELIN's own `/h/<id>` link.
  - Two keep a `%20` in MICHELIN's own path: Villa Fontelunga
    (`foiano-%20della-chiana`) and Villa Petriolo (`Cerreto%20Guidi`). The
    stored URL is exactly as MICHELIN serves it, and both return 200.
- **Uniqueness.** No existing production row holds any of the 150 MICHELIN
  page ids. I checked by id, so country-prefixed variants of a URL can't slip
  through. I ran the same check on the Spain file: also clean.

### Websites and phones

Research ran in five parallel batches, using the same brief as Spain plus the
Italian phone format.

- **Phones re-checked afterwards.** I re-fetched every confirmed phone's
  source page and checked the digits appear on it: 130 by plain fetch and 7
  in the built-in browser (Six Senses, Portrait/Lungarno, Four Seasons,
  Bulgari, Passalacqua, Londra Palace, Terra). All 137 were found.
- **Read in the browser because plain fetches were blocked:**
  - Lungarno Collection: Hotel Lungarno, Portrait Milano, Portrait Roma;
  - Six Senses Rome;
  - Four Seasons Firenze;
  - Bulgari Roma (phone only);
  - Passalacqua (phone only);
  - Le Sirenuse (website only).

**Websites confirmed on name + city only:**

| Hotel | Why |
|---|---|
| Santa Caterina | the site gives S.S. Amalfitana 9 |
| Il Sereno | no street printed |
| Therasia | no street printed |
| Grand Hotel Victoria | no street printed |
| Monaci delle Terre Nere | site: Via Monaci 82 |
| Corte della Maestà | site: Vicolo della Provvidenza |
| Critabianca | site: SP 278 km 1,57 |
| Borgo Egnazia | no street printed, only Savelletri di Fasano 72015 |

### Phone lines for a reviewer to note

- **Labelled reservations on the hotel's own site, and the only number there:**
  Precise Tale Poggio alla Sala, Casa Clàt and Conti di San Bonifacio.
  - For Casa Clàt, MICHELIN's first number is the restaurant and bar line.
- **The site's hotel line, where MICHELIN prints something else:**

  | Hotel | Stored | MICHELIN prints |
  |---|---|---|
  | La Foresteria Planeta | +39 0925 529986 | Planeta central reservations, which the site lists for the sister properties |
  | Villa d'Este | switchboard +39 031 3481 | the room-reservations line |
  | Casa Cipriani Milano | +39 02 2506 4088 | a mobile not on the site |
  | Hassler | +39 06 699340 | +39 06 69934301 |
  | Donna Coraly | landline | a mobile not on the site |
  | Grand Hotel Excelsior Vittoria | +39 081 877 7111 | |
  | Villadorata | landline | the mobile |
  | Lupaia | first of two unlabelled landlines | the second |
  | I Borghi dell'Eremo | landline | the mobile |
- **Already set, not touched, but worth a look:**
  - Borgo Egnazia's stored phone (+39 080 225 5850) is the line its site
    labels *Prenotazioni*. The site's Info line is +39 080 225 5000.
- **Palazzo Margherita:** +39 0835 549060 appears next to the hotel's address
  on its Coppola Hideaways page. The same number is labelled "Toll Free" in
  that site's global footer.

## Wrong-record traps hit (all rejected)

- **The 8 wrong nearest-page MICHELIN matches** above.
- **Name-alike domains that are a different business:**
  - stelladitalia.com is a same-named hotel in **San Mamete (Valsolda)**.
  - villapetriolo.com is a hijacked spam site.
  - sienahouse.com, viveresuites.com and casanewton.com are parked domains,
    and sienahouse.org is an unrelated site.
- **Hosting pages:** www.monacidelleterrenere.it is a hosting welcome page;
  the real site is the bare domain.
- **Sibling properties kept apart:**
  - Villadorata Country House / Seven Rooms Villadorata;
  - La Fiermontina Luxury Home / Palazzo Bozzi Corso;
  - Lefay Garda / Dolomiti;
  - Sextantio Matera / Santo Stefano;
  - Splendido / Splendido Mare;
  - Portrait Roma / Milano;
  - J.K. Place Roma / Capri;
  - Villa Sant'Andrea / Grand Hotel Timeo (Belmond list: 0942 6271 200 vs
    0942 6270 200);
  - Monastero Santa Rosa / Borgo Santandrea;
  - Palazzo Ripetta / Bulgari Roma.
- **Odd domains:** the real sites are borghidelleremo.it (not
  iborghidelleremo), agrivivere.com for Vivere Suites, lume-ortigia.com,
  casa-newton.com and villapetriolotuscany.com.

## Data problems found (logged, not fixed)

- **QA-264 — Key counts differ from MICHELIN's live pages for 17 hotels.**
  - **MICHELIN shows fewer Keys than production:**

    | Hotel | Production | MICHELIN |
    |---|---|---|
    | Casa Angelina | 2 | 1 |
    | Hassler | 2 | 1 |
    | Le Sirenuse | 2 | 1 |
    | J.K. Place Roma | 2 | 1 |
    | La Palma | 2 | 1 |
    | Aethos Monterosa | 1 | no Key |
  - **MICHELIN shows more Keys than production:**

    | Hotel | Production | MICHELIN |
    |---|---|---|
    | Santa Caterina | 1 | 2 |
    | Castel Fragsburg | 1 | 2 |
    | Palazzo Talìa | 1 | 2 |
    | Villa La Massa | 1 | 2 |
    | Splendido Mare | 1 | 2 |
    | Villa d'Este | 1 | 2 |
    | Borgo San Felice | 1 | 2 |
    | Splendido | 2 | 3 |
    | Corte della Maestà | 2 | 3 |
    | Collegio alla Querce | 2 | 3 |
    | Borgo Santandrea | 2 | 3 |

  The Key values are untouched.
- **QA-265 — 66 hotels carry a Key on MICHELIN's Italy pages but are not in
  `hotels`.** Examples: Bvlgari Milano, Four Seasons Milano, Mandarin Oriental
  Milan, Hotel de Russie, Gritti Palace, Airelles Palladio (3), Grand Hotel
  Timeo, Caruso, Villa San Michele, Principe di Savoia and Hotel Eden. The full
  list is in the QA entry.
  - One of the 66 is "La Minerva" under a different page id from our
    hotel_789 Orient Express La Minerva. That may be a duplicate MICHELIN
    listing.
- **QA-266 — Location and address differences.**
  - **Stored coordinates far from MICHELIN's pin:** Castel Monastero 4.5 km,
    COMO Castello del Nero 1.7 km, ADLER Lodge Ritten 626 m, Castelfalfi
    309 m. Street and postcode agree in all four.
  - **Address differences on the hotels' own sites:**
    - Santa Caterina: S.S. Amalfitana 9, against our Via Mauro Comite 9.
    - Monaci delle Terre Nere: Via Monaci 82.
    - Corte della Maestà: Vicolo della Provvidenza.
    - Critabianca: SP 278 km 1,57.
    - Borgo dei Conti: MICHELIN gives Strada Montepetriolo 26.
    - Hotel Signum: the hotel is at Via Scalo 15; Via Pastificio is the legal
      seat.
    - Palazzo Talìa: Largo, not Via, del Nazareno 25.
    - Splendido: Salita, not Viale, Baratta 16.
  - **Postcodes:** Grand Hotel Tremezzo 22016 against our 22019; Pellicano
    58019 against 58018.
- **QA-267 — Five contact gaps:** La Palma (website and phone), and the
  Lungarno, Portrait Milano and Palazzo Avino phones, as described above.

## Testing

I ran the SQL on a scratch PostgreSQL 17 database seeded with the 155
exported rows.

- **First run:** commits. The table then holds 151 phones, 154 websites and
  155 MICHELIN URLs. The 14 / 14 / 5 values that were already set are
  unchanged; I spot-checked Borgo Egnazia, San Domenico Palace and Bulgari.
- **Second run:** raises and changes nothing.
- **A single phone filled after the export** (hotel_317): raises with that
  code and rolls everything back.

The production table's triggers were not tested.
