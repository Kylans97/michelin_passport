# Contact fields — MICHELIN Key hotels, AT / CH / BE / HU / PL / HR (2026-10-29)

Status: **APPLIED 2026-10-29** (see the Michelin_Database CHANGELOG). This pass uses the same method and
rules as the earlier countries (`ES_REPORT.md`, `IT_REPORT.md`,
`DE_REPORT.md`, `JP_REPORT.md`). Only the differences are written out here.

There is one guarded transaction per country. Each can be applied on its
own, in any order:

| Country | Hotels | SQL file | Evidence |
|---|---|---|---|
| Austria | 48 | `prepared_at_hotel_contacts.sql` | `at_hotels_all.csv` |
| Switzerland | 42 | `prepared_ch_hotel_contacts.sql` | `ch_hotels_all.csv` |
| Belgium | 15 | `prepared_be_hotel_contacts.sql` | `be_hotels_all.csv` |
| Hungary | 12 | `prepared_hu_hotel_contacts.sql` | `hu_hotels_all.csv` |
| Poland | 11 | `prepared_pl_hotel_contacts.sql` | `pl_hotels_all.csv` |
| Croatia | 10 | `prepared_hr_hotel_contacts.sql` | `hr_hotels_all.csv` |

Supporting files:

- `_source/six_countries_michelin_match.txt` — the MICHELIN page matched to
  each hotel.
- `_source/research_brief_six_countries.md` — the research rules, with the
  per-country phone formats.

## Result

Each cell is **confirmed (in the SQL) / already set / blank**:

| Country | `michelin_url` | `website_url` | `phone` |
|---|---|---|---|
| AT | 47 / 1 / 0 | 45 / 2 / 1 | 46 / 1 / 1 |
| CH | 39 / 3 / 0 | 35 / 7 / 0 | 41 / 1 / 0 |
| BE | 10 / 5 / 0 | 14 / 1 / 0 | 15 / 0 / 0 |
| HU | 12 / 0 / 0 | 11 / 0 / 1 | 11 / 0 / 1 |
| PL | 11 / 0 / 0 | 11 / 0 / 0 | 11 / 0 / 0 |
| HR | 10 / 0 / 0 | 9 / 1 / 0 | 9 / 1 / 0 |
| **Total** | **129 / 9 / 0** | **125 / 11 / 2** | **133 / 3 / 2** |

The only blanks are **Park Hyatt Vienna** (hotel_46) and **Párisi Udvar
Budapest** (hotel_277). hyatt.com returns 403 to plain fetches and refused
the built-in browser.

**Phone formats.**

- **Trunk 0 dropped:** Austria `+43`, Switzerland `+41`, Belgium `+32` and
  Croatia `+385`.
- **Hungary `+36`:** the domestic prefix 06 is dropped.
- **Poland `+48`:** no trunk prefix.
- **Austrian "-0" endings:** these are folded into the number as the hotel's
  own `tel:` link dials it. For example, "+43 5583 2206-0" is stored as
  `+43 5583 22060`.

## How values were confirmed

### MICHELIN URLs

MICHELIN's six listings yield 611 unique pages, all of which I read:

| Country | Listed | Pages read |
|---|---|---|
| Austria | 178 | 178 |
| Switzerland | 177 | 176 |
| Belgium | 85 | 85 |
| Hungary | 42 | 42 |
| Poland | 79 | 79 |
| Croatia | 51 | 51 |

Matching was on coordinates, then postcode and street, never name.

**3 nearest-page matches were wrong and were rejected.** In each case the
hotel's own page was missing from the listing:

| Our hotel | Nearest page, rejected |
|---|---|
| Hotel Tannenhof, St. Anton | Post Lech, 12.7 km away |
| Bürgenstock Resort | its sibling Waldhotel by Bürgenstock |
| Alpen-Wellness Resort Hochfirst | The Crystal VAYA, on the same Gurglerstraße |

I read all three hotels' own pages through MICHELIN's `/h/<id>` links.
Bürgenstock Resort (hotel_51, three Keys in production) is MICHELIN's
"Bürgenstock Hotel & Alpine Spa": three Keys, street "Bürgenstock Resort",
postcode 6363.

**Other details:**

- **Already-set MICHELIN URLs:** all 9 carry the same MICHELIN page id as the
  page matched here.
- **Uniqueness:** no existing production row holds any of the 129 new page
  ids. I checked by id.

### Websites and phones

Research ran in six parallel batches.

- **Phones re-checked afterwards.** I re-fetched every confirmed phone's
  source page and checked the digits appear on it: 112 by plain fetch and 21
  in the built-in browser. Every number was found except Hotel Clark
  Budapest's. Its site returned 503 at re-check time, so that number rests on
  the research agent's earlier read and is noted in the row.
- **Read in the browser because plain fetches were blocked:**
  - **Marriott:** Hotel Imperial (VIEIL), Bristol Warsaw (WAWLC), W Budapest
    (BUDWH), H15 Palace (KRKHP), Dorothea (BUDKC).
  - **Four Seasons:** Geneva and Budapest.
  - **Others:** Rocco Forte's Hotel Amigo, Anantara New York Palace, Botanic
    Antwerp, Badrutt's Palace (website) and 7132 Hotel (Cloudflare challenge).
    7132 Hotel's contact page prints "7132 Vals" but no street, so it is
    recorded as name + city.

### Phone lines for a reviewer to note

- **Labelled reservations, the only number on the site:** Esplanade Zagreb
  (+385 1 45 666 66) and Petit Bois, Balatonfüred (a mobile).
- **Mobile, the only hotel line printed:** Korta Katarina, Platán Manor,
  Jaskółka, EN Hotel and Flora Antwerp.
- **Already set, not touched:** Grand Park Rovinj's stored number is the line
  Maistra labels RESERVATIONS.
- **Anantara New York Palace:** +36 1 886 6111 is printed both as the hotel's
  own number and as its central reservations line.

## Wrong-record traps hit (all rejected)

- **The 3 wrong nearest-page MICHELIN matches** above.
- **Domains that belong to someone else:**
  - kronthaler.com is a Munich patent law firm.
  - bergblick.at is a holiday flat in Lofer.
  - kitzhof.com is the Kitzhof Inn in Vermont.
  - tannenhof.com is a German Tannenhof.
  - weissesroessl.at is the Weisses Rössl in **St. Wolfgang**, and
    weisses-roessl.at is a Gasthof in Abtenau. Ours is roesslkitz.at.
  - scheiblhofer.at is the winery; the resort is theresort.at.
  - mamathresl.com redirects to Booking.com.
  - platanhotel.hu is a Platán Hotel in Sárvár.
  - jaskolka.com.pl is a different Jaskółka hotel.
  - hotelcopernicus.pl is parked, with an unrelated phone number.
- **Dead or parked domains:** hotelamigo.com and thewoodward.ch are parked.
  For Bristol Warsaw, hotelbristolwarsaw.pl returns 410 and
  hotelbristol.pl is for sale.
- **A footer printing another hotel's address:** Severins Lech's site footer
  shows the Sylt sister's address. The Lech address and number were taken
  from the contact page and Impressum.
- **Sibling properties kept apart:**
  - Beau-Rivage Geneva / Beau-Rivage Palace Lausanne;
  - Tschuggen Grand / Valsana / Carlton (one group site);
  - Bürgenstock / Waldhotel / Villa Honegg;
  - Grand Park Rovinj / Lone;
  - Burg Vital / Burg Hotel Oberlech.
- **Renames and branding:**
  - Grand Tirolia is now part of Hommage Luxury Hotels.
  - "Alpen-Wellness Resort Hochfirst" is styled "Luxury Mountain Resort
    Hochfirst".
  - San Canzian is "San Canzian Hotel & Residences".
  - Holzleiten is "Holzleiten Nature Hideaway".
  - Platán Manor is "Platán Udvarház".
  - Grand Resort Bad Ragaz's stored URL now redirects to grandresort.ch.

## Data problems found (logged, not fixed)

- **QA-276 — Key counts differ from MICHELIN's live pages for 13 hotels.**
  - **Fewer Keys on MICHELIN:**

    | Hotel | Production | MICHELIN |
    |---|---|---|
    | Beau-Rivage Geneva | 3 | 2 |
    | Villa Honegg | 2 | 1 |
    | Párisi Udvar | 2 | 1 |
    | Zamek Łeba | 2 | 1 |
    | Altus Palace | 2 | 1 |
    | Bristol Warsaw | 2 | 1 |
    | Palace Elisabeth Hvar | 2 | 1 |
  - **More Keys on MICHELIN:**

    | Hotel | Production | MICHELIN |
    |---|---|---|
    | Beau-Rivage Palace | 2 | 3 |
    | Kulm St. Moritz | 2 | 3 |
    | Schlosshotel Fiss | 1 | 2 |
    | Corinthia Brussels | 1 | 2 |
    | Jaskółka | 1 | 2 |
    | Villa Dubrovnik | 1 | 2 |
- **QA-277 — 78 hotels carry a Key on these countries' MICHELIN pages but
  are not in `hotels`.** The full list is below.
- **QA-278 — Location and address differences.**
  - **Stored pins far from MICHELIN's:** Fairmont Montreux 808 m, Scheiblhofer
    801 m, Hochfirst 447 m, Bürgenstock 436 m, Vignée 307 m.
  - **Postcodes:** Hotel Imperial is 1010 on Marriott and MICHELIN; we store
    1015. Altus Palace's own site gives 50-056 (stored); MICHELIN gives 50-005.
- **QA-279 — The two Hyatt gaps**, the Clark Budapest re-check, and the
  stored-value notes above.

### Key hotels on MICHELIN's pages that are not in `hotels` (QA-277)

**Austria (23):**

- **Two Keys:** Mandarin Oriental Vienna, Anantara Palais Hansen Vienna.
- **One Key:**
  - **Vienna:** Altstadt Vienna, The Guesthouse Vienna, Hotel MOTTO, The
    Ritz-Carlton Vienna, Hyatt Regency Vienna, Lieperts Café Dinner Rooms.
  - **Salzburg:** Hotel Goldgasse, Hotel Sacher Salzburg, Hotel Goldener
    Hirsch.
  - **Elsewhere:** Hotel Nesslerhof, Genießerhotel BERGERGUT, Hotel & Chalet
    Aurelio, DasPosthotel, Hotel Josefine, Das Central, Sportresidenz
    Zillertal, AlpenParks The Secret Sölden, Alpin Resort Sacher, Hotel Alpin
    Spa Tuxerhof, Neuwirt, Hotel Schöne Aussicht.

**Switzerland (47):**

- **Two Keys:** The Dolder Grand, Widder Hotel, Six Senses Crans-Montana.
- **One Key:**
  - **Zurich, Basel and Bern:** Mandarin Oriental Savoy Zurich, Storchen
    Zürich, Hotel Märthof Basel, Hotel Schweizerhof Bern & Spa.
  - **Geneva and Lake Geneva:** La Réserve Genève, Hotel d'Angleterre Geneva,
    Hôtel Les Armures, Villars Palace.
  - **Ticino:** Giardino Lago, Giardino Ascona, Splendide Royal Lugano, The
    View Lugano, Relais Castello di Morcote.
  - **Engadin and Graubünden:** Grace La Margna St. Moritz, Kempinski Grand
    Hotel Des Bains, Hotel Palafitte, IN LAIN Hotel Cadonau, Hotel Piz Buin
    Klosters, AMERON Davos, Schloss Schauenstein.
  - **Zermatt:** Grand Hotel Zermatterhof, Mont Cervin Palace, Boutique Hotel
    Matthiol, 22 SUMMITS, Cordée des Alpes, Hotel Welschen, Backstage Hotel
    Vernissage.
  - **Bernese Oberland and Gstaad:** The Cambrian, Hotel Eiger Mürren,
    Bergwelt Grindelwald, Boutique Hotel Glacier, Ultima Gstaad, Hotel de
    Rougemont & Spa, HUUS QUELL.
  - **Central Switzerland:** Waldhotel by Bürgenstock, Kempinski Palace
    Engelberg, Frutt Mountain Resort, Seerose Resort & Spa.
  - **Others:** The Brecon, Chalet RoyAlp, The Omnia, Au Club Alpin, Aïda
    Hôtel & Spa, Miiro The Mansard.

**Belgium (3):** Cobergher Hotel (2 Keys), Faubourg 21, La Réserve
Knokke-Heist.

**Poland (3):** Heron Live Hotel, Bachleda Residence Zakopane, Stary Niedźwiedź.

**Croatia (2):** Hotel Katarina, Palazzo President.

**Hungary:** none; all 12 of MICHELIN's Hungarian Key hotels are in
production.

## Testing

I ran all six files on one scratch PostgreSQL 17 database seeded with the
138 exported rows.

- **First run:** each file commits. Every country ends with its expected
  counts. For Austria that is 47 phones, 47 websites and 48 MICHELIN URLs.
  Hungary has 11 phones and 11 websites, because Párisi Udvar stays blank.
- **Second run** (Austria, Poland): raises and changes nothing.
- **A Belgian row moved to another country:** the Belgium file raises with
  that code and rolls back.

The production table's triggers were not tested.
