# Contact fields — MICHELIN Key hotels, Germany (2026-10-29)

Status: **APPLIED 2026-10-29** (see the Michelin_Database CHANGELOG). This pass uses the same method and
rules as Spain and Italy (`ES_REPORT.md`, `IT_REPORT.md`). Only the
differences are written out here.

| File | What it is |
|---|---|
| `prepared_de_hotel_contacts.sql` | One guarded transaction: 122 `michelin_url`, 120 `website_url`, 123 `phone` |
| `de_hotels_all.csv` | One row per hotel (126): value, status, source URL, how it was confirmed, notes |
| `_source/de_michelin_match.txt` | The MICHELIN page matched to each hotel |
| `_source/research_brief_de.md` | The research rules, with the German phone format |

## Scope

Read-only production export, 2026-10-29: every `hotels` row with
`country_code = 'DE'` and `michelin_keys` set, 126 rows in all.

Before this pass:

| Field | Already set | Empty |
|---|---|---|
| `phone` | 0 | 126 |
| `website_url` | 3 (Bareiss, Schloss Elmau, The Fontenay) | 123 |
| `michelin_url` | 4 (La Maison, Landhaus Stricker, Söl'ring Hof, The Fontenay) | 122 |

## Result

| Field | Confirmed (in the SQL) | Unclear | Not found |
|---|---|---|---|
| `michelin_url` | 122 | 0 | 0 |
| `website_url` | 120 | 3 | 0 |
| `phone` | 123 | 3 | 0 |

**Phone format.** German numbers drop the trunk 0 after +49. Area code and
subscriber number are separated by a space: `+49 89 21200`, `+49 7442 4920`.

Printed extensions such as "-0" are folded into the subscriber number,
because that is the number the hotel's own click-to-call link dials. For
example, "+49 40 82255-0" is stored as `+49 40 822550`. No digit is added or
dropped, and the exact printed form is kept in `phone_as_listed`.

These are left NULL:

- **hotel_90 Hotel de Rome, website and phone.**
  - Every Rocco Forte page for it, the property root and its room pages,
    returned Rocco Forte's own 404 in a real browser. Search engines still
    index those pages.
  - Its MICHELIN page still exists at the same address, but now carries
    **no Key award**. See QA-268.
- **hotel_244 Andaz Munich Schwabinger Tor, website and phone.** Hyatt's page
  renders empty, even in the browser.
- **hotel_219 Boutique-Hotel Friesinger, website and phone.** Its only known
  domain, boutique-hotel-friesinger.de, does not exist in DNS. MICHELIN still
  lists the hotel with one Key.

## How values were confirmed

### MICHELIN URLs

MICHELIN's Germany listing says "377 hotels" and yields 379 unique pages. I
crawled all of them slowly (about 0.8 s apart), with no rate-limit trouble
this time. Matching was on coordinates, then street and number, never name.

**3 nearest-page matches were wrong and were rejected.** In each case the
hotel's own page was missing from the listing:

| Our hotel | Nearest page, rejected | How far |
|---|---|---|
| Der Birkenhof | Orphée Andreasstadel, Regensburg | 37 km away |
| The Wellem, Mühlenstraße 34 | De Medici, Mühlenstrasse 31 | 47 m |
| Hotel de Rome | Titanic Gendarmenmarkt | 95 m |

I read all three hotels' own pages through MICHELIN's `/h/<id>` links.

**Kept despite different wording.** Five matches print a different address,
but the stored coordinates are within 33 m and no other MICHELIN hotel is
close. For Weimarer Land the stored location is 913 m off, but the next
MICHELIN hotel is 11.6 km away. Each is logged in QA-270:

| Hotel | Our address | MICHELIN |
|---|---|---|
| Sofitel Frankfurt Opera | Hochstraße 44 | Opernplatz 16 (same building) |
| Hotel Deimann | Alte Handelsstraße 5 | Winkhausen 5 |
| Das Graseck | Wildenau 6 | Graseck 4 |
| Kronelamm | Marktplatz 1 | Marktplatz 2-3 |
| Weimarer Land | Lindenallee 1 (as on the site) | Weimarer Str. 60 |

**Other details:**

- **Median distance:** 15 m.
- **Uniqueness:** no existing production row holds any of the 122 MICHELIN
  page ids. I checked by id.
- **Encoded paths:** two MICHELIN paths contain percent-encoding, and both
  are stored exactly as served:
  - `R%C3%B6hrnbach` for Jagdhof;
  - `Neunburg%20v.%20W.%20%E2%80%93%20Hofenstetten` for Birkenhof.

### Websites and phones

Research ran in five parallel batches.

- **Phones re-checked afterwards.** I re-fetched every confirmed phone's
  source page and checked the digits appear on it: 118 by plain fetch and 5
  in the built-in browser (The Charles, Bayerischer Hof, JW Marriott
  Frankfurt, Koenigshof, RIVA). All 123 were found.
- **Read in the browser because plain fetches were blocked:**
  - The Charles Hotel: Rocco Forte page, Sophienstrasse 28.
  - Bayerischer Hof: Promenadeplatz 2-6, main line 21 20-0.
  - JW Marriott Frankfurt: code FRAJW checked on the loaded page; formerly
    Jumeirah Frankfurt.
  - Koenigshof: code MUCLK checked on the loaded page.
- **Websites:** all 120 confirmed sites printed name, city and address.
- **Line types:** all 123 phones are the hotel's own line. None is a group or
  reservations-only line.

## Wrong-record traps hit (all rejected)

- **The 3 wrong nearest-page MICHELIN matches** above.
- **Domains that belong to someone else:**
  - hotel-jagdhof.de redirects to **Hotel Jagdhof Kleinwalsertal in Riezlern,
    Austria**. Our hotel is jagdhof-roehrnbach.de.
  - maison-messmer.de redirects to **Brenners Park-Hotel**, a different
    Baden-Baden hotel. The real site is the Hommage Hotels property page.
  - achental.com is the regional tourist office; the hotel is das-achental.com.
  - meintzinger.de is an antiques shop; the hotel is weingut-meintzinger.de.
  - schloss-eberstein.de is a **sale listing** offering the whole estate for
    €18.9M; the hotel is hotel-schloss-eberstein.de.
  - hofgalerie.de and hotelderome.com are parked domains.
  - buelow-palais.com is not the hotel's own site; the hotel is buelow-palais.de.
- **Marriott codes:**
  - BERRZ is a different Ritz-Carlton property; the Ritz-Carlton Berlin is
    BERZT.
  - WFBRZ is a 404; the Ritz-Carlton Wolfsburg is WFGRZ.
- **Sibling properties kept apart:**
  - Althoff Schloss Bensberg / Seehotel Überfahrt;
  - Überfahrt / Parkhotel Egerner Höfe (same town, 6690 vs 6660);
  - Europäischer Hof Heidelberg / Steigenberger Icon Europäischer Hof
    Baden-Baden;
  - Severin*s Morsum Kliff / Severin's Resort Keitum;
  - PURS / Hotel am Ochsentor;
  - niXe / Hotel am Meer.
- **Renames and branding:**
  - Widmann's Löwen now trades as **Widmann's Alb.leben**.
  - Söl'ring Hof is now "Hommage Söl'ring Hof".
  - Patrick Hellmann Schlosshotel is styled "Schlosshotel Berlin".
  - Weimarer Land is "Spa & GolfResort Weimarer Land" (formerly Lindner).
  - Louis C. Jacob joined Marriott's Autograph Collection on 22 July 2025 and
    keeps its own domain.

## Data problems found (logged, not fixed)

- **QA-268 — Key counts differ from MICHELIN's live pages for 20 hotels.**
  - **12 pages carry no Key award at all**, though every one is still in
    MICHELIN's Germany listing. Hotel de Rome had two in production; the other
    11 had one: Schloss Eberstein, AMERON Neuschwanstein, Kloster Hornbach,
    Villa Mittermeier, Hanusel Hof, Strandhotel Fischland, DAS.HOCHGRAT,
    Staudacherhof, Haubers, Gewandhaus Dresden and Bachmair Weissach.
  - **Fewer Keys, 2 → 1:** Seezeitlodge, Esplanade Saarbrücken and Ketschauer
    Hof.
  - **More Keys, 1 → 2:** Birkenhof, Hüttenhof, Chiemgauhof, Steigenberger
    Icon Europäischer Hof and PURS.

  This looks like the 2026 Germany Key update never reaching production. That
  is worth settling before the app shows these hotels' Keys again.
- **QA-269 — 16 hotels carry a Key on MICHELIN's Germany pages but are not
  in `hotels`.** Among them are Brenners Park-Hotel, Waldorf Astoria Berlin,
  Budersand, Severin's Resort and Weissenhaus.
- **QA-270 — Location and address differences.** These are the five wording
  differences above, Das James at 361 m, and two postcodes:
  - Burghotel Falkenstein is in 87459 Pfronten; we store 87629.
  - Do & Co's site gives 80333; we store 80331.
- **QA-271 — The three contact gaps above.** It also notes the Schloss
  Eberstein sale listing and the Widmann's rename.

QA ids: the UK session's working copy (`stoic-austin-e5e924`) already uses
QA-280 to QA-288. This file takes QA-268 to QA-271, which no branch or
worktree uses.

## Testing

I ran the SQL on a scratch PostgreSQL 17 database seeded with the 126
exported rows.

- **First run:** commits. The table then holds 123 phones, 123 websites and
  126 MICHELIN URLs. The 3 websites and 4 MICHELIN URLs that were already set
  are unchanged.
- **Second run:** raises and changes nothing.
- **A changed hotel name** (hotel_24): raises with that code and rolls
  everything back.

The production table's triggers were not tested.
