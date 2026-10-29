# Germany & Italy: MICHELIN completion, Place IDs and phones (research 2026-10-29)

Status: **APPLIED 2026-10-29** (ledger 108/108, plus `prepared_aqua_closure.sql`; see the Michelin_Database CHANGELOG). Generated from production's
export of 2026-10-29 06:31 UTC. To apply, run in order:

1. `supabase/migrations/20261023130000_add_de_it_2026_star_cities.sql`
   (330 towns)
2. `prepared_de_it_stars_2026.sql` (one transaction; aborts on any check)

Review `match_report.csv` first. The decisions waiting for you are QA-253
(the three German losses and Aqua's closure, which is optional and
commented out) and QA-255 (three Italian rows kept).

| After applying | Germany | Italy |
|---|---|---|
| Stars (3/2/1) | 12/48/278, exactly MICHELIN's live 2026 | 15/38/327: MICHELIN's live 2026 plus 3 kept (QA-255) |
| Restaurants added (rest_1842–rest_2444) | 281 | 322 |
| Place ID / phone, all starred rows | 336 / 316 | 362 / 362 |
| Hotel links (25 → 66) | +15 | +26 |

Germany's launch rows are relabelled 2025 (58 rows; Haerlin and Tohru
already had a 2025 row from the history pass, so theirs are left alone).
L.A. Jordan goes 2 → 3. Aqua, bianc and Courtier are written as losses
(QA-252, QA-253). In Italy, Tre Olivi is corrected 2 → 1 (QA-254).

**Tested on the real export,** loaded into a scratch Postgres 16 + PostGIS
database:

- **Without the migration**, the file aborts with nothing applied.
- **With it**, the counts above hold, and every row's history checks out.
- **Re-runs:** the migration is idempotent, and a re-run of the prepared file
  aborts.
- **A renamed existing row** aborts the whole file.

It was not run against the real database or a full migration replay.

## What MICHELIN shows (guide.michelin.com, read 2026-10-29)

| | 3 stars | 2 stars | 1 star | Total | Edition |
|---|---|---|---|---|---|
| Germany, live | 12 | 48 | 278 | 338 | 2026 (announced 23 Jun 2026, Frankfurt) |
| Italy, live | 14 | 37 | 326 | 377 | 2026 (announced 19 Nov 2025, Parma) |

- Every one of the 715 restaurant pages was read. Each carries
  `dateAwarded "2026"`, and its stars agree with the listing. The pages are
  saved in `../michelin_{de,it}_stars/_source/michelin_restaurant_pages_20261029.jsonl`.
- **Germany:** MICHELIN's 2026 announcement gives 339 restaurants; 338 are
  live. Its own page confirms "Die Selektion 2026 zählt 48
  2-Sterne-Restaurants". schanz. restaurant. (Piesport, 3 stars) has a
  listing card without data attributes and was added by hand.
- **Italy:** MICHELIN's 2026 article lists 394 restaurants (15/38/341);
  377 are live. About 19 from the article are no longer on the site,
  including **Quattro Passi (3 stars)**, Santa Elisabetta (2),
  Don Alfonso 1890, Lido 84, Impronte, Il Circolino and Unforgettable.
  Following the Spain precedent, they are not added. If production already
  has them, they need a decision (Belgium kept such rows; QA-220).
  D.one Ristorante Diffuso (Montepagano) is live but not in the article,
  probably a mid-year addition.
- **Italy's 2027 edition is announced on 12 November 2026** (Piacenza).
  Italy's stars change again two weeks after this pass. The restaurants,
  Place IDs and phones carry over.

## Guide year: launch-label rule (DATA_UPDATE_PROCESS §3, QA-217)

- **Germany: relabel needed.** The seeded DE rows (12 three-star,
  47 two-star) match MICHELIN's **2025** list exactly (341: 12/47/282,
  `../michelin_de_stars/_source/michelin_full_list_2025_parsed.json`).
  L.A. Jordan, for example, is seeded at 2 stars, its 2025 value; it
  became 3 stars in 2026. As for the Netherlands, the DE launch rows move
  to 2025 with values unchanged, and the 2026 values are then applied as
  changes. Seeded two-stars that are no longer live (Aqua, bianc, Atelier,
  Esplanade, Courtier, CODA, Cœur D'Artichaut and ammolite; some may only be
  renames) become losses or closures, to be checked against the export.
- **Italy: no blanket relabel.** All 58 seeded rows appear in the 2026
  article, including the 2026 three-star newcomer La Rei Natura, so the
  seed holds 2026 values. Tre Olivi is the one exception: seeded at 2, but
  1 in the 2026 article. It gets the Belgian row-by-row treatment, once its
  2025 value is confirmed.
- **Town names:** production writes German and Italian towns as English
  exonyms (Munich, Cologne, Rome, Milan), so MICHELIN's English listing
  names are used for new towns.

## Research results per restaurant

All results are in `../michelin_de_stars/de_research_2026.csv` and
`../michelin_it_stars/it_research_2026.csv`. Each row includes the
evidence and notes.

| | Germany | Italy |
|---|---|---|
| Place ID confirmed | 333 / 338 | 358 / 377 |
| Phone confirmed | 316 | 361 |
| Sits in a hotel (MICHELIN "Stay at the hotel") | 41 | 63 |

### Place IDs (find-place-id rules, as for Spain)

- **Under 100 m:** confirmed when it is the restaurant's own record with the
  right type, not its hotel's.
- **100–500 m:** confirmed when Google's record carries the official domain
  and the address agrees. That covers 5 German and 37 Italian rows; Paca
  was checked by hand.
- **Combined same-name hotel-restaurant listings** are accepted, as for the
  Netherlands and Spain:
  - Germany: Söl'ring Hof, Erbprinz, Meisenheimer Hof, Rebers Pflug,
    Rüssel's Landhaus, Zur Post, Zur Weinsteige.
  - Italy: Terra, Al Sorriso, La Speranzina, Locanda de Banchieri,
    Relais Blu, Shalai, Signum, Ca' Vittoria, Antonello Colonna.
- **Overrides,** each explained in the CSV:
  - Atlantic Restaurant, Tantris DNA, Adler, I Portici, Nazionale and
    Procaccini: the right record of several at the same address.
  - Name variants and operating-company names: bi:braud, 5, BjörnsOx,
    garbo, Ontra's, Huberwirt, Philippin, Meyers Keller, Schwarz,
    Mater1apr1ma, Moebius.
- **Left blank: Germany (5)**
  - Hotel or outlet records only: die burg – fine dining, DiVa,
    Ente (Kloster Eberbach), Karner.
  - Gut Lärchenhof: 658 m away, at another address.
- **Left blank: Italy (19)**
  - Over 500 m from MICHELIN's pin, with the same address and domain, so
    one of the two pins is wrong: Aqua Crua (1.7 km), Bluh Furore,
    Ca' Matilde, Casamatta, Il Pellicano, Il Tiglio, Il Visibilio,
    La Pineta, La Trattoria Bartolini, Locanda del Pilone, Locanda Margon.
  - Only the hotel's record exists: Alici (Borgo Santandrea), Glicine
    (Santa Caterina), Villa Feltrinelli, Cannavacciuolo Countryside and
    Cannavacciuolo Vineyard (Laqua).
  - Another outlet: AM Bistrot for Andrea Monesi.
  - No record: Alpenroyal Gourmet, Wood.

### Phones

- **Confirmed** when one of these holds:
  - MICHELIN and Google agree (Germany 287, Italy 325).
  - Otherwise, the number is printed on the venue's own site. When the
    site shows both numbers, MICHELIN's is kept.
- **Left out:** numbers that look like a hotel or estate switchboard
  (Orangerie, Tipken's, Il Refettorio), as with Deessa in Spain. Rows where
  neither number appears on the site are also left out.
- **Format:** international, as MICHELIN or Google prints it.

### Hotels

`michelin_hotel_pages_20261029.json` holds the 103 MICHELIN hotel pages
behind the "Stay at the hotel" links: name, coordinates and Key. 74 of
them carry a Key. With the export, each is matched to our `hotels` rows by
its MICHELIN pin (within 150 m), never by name.

- **Matched:** the restaurant gets a `hotel_restaurants` link. Since
  2026-10-28, `hotels` also holds World's 50 Best hotels without a Key, so
  matching uses every hotel in the export.
- **Not matched:** the restaurant gets `property_name`.

## Next step (needs the export)

The SQL is generated, not hand-written, by `build_prepared_de_it.py`:

```
python3 build_prepared_de_it.py <export.json> <first_free_code> <migration_name> <qa_first_id>
```

- **`export.json`** is the JSON cell from `export_de_it_query.sql`.
- **`first_free_code`** must be above production's maximum *and* above every
  code claimed by unapplied files on any branch. Check with
  `git grep` across branches.
- **`migration_name`** is named after the highest migration on main.

It writes `match_report.csv`, which lists every judgement call:

- matches made by coordinates or Place ID;
- losses;
- kept rows;
- import errors;
- stored coordinates that are off;
- hotel mismatches.

It also writes `prepared_de_it_stars_2026.sql` and the cities migration.
Review the report before applying anything.

**How existing rows are matched to MICHELIN**, never by name alone:

1. MICHELIN slug and town segment;
2. otherwise the same Google Place ID;
3. otherwise coordinates within 200 m with a name check, or within 1 km
   with a near-exact name.

**Tested 2026-10-29** on a scratch PostgreSQL 16 + PostGIS database seeded
with a *simulated* export built from the launch seed (`restaurants_master.csv`:
59 DE and 58 IT rows, 270 hotels, 25 links). The outputs of that run were
deleted.

- **Without the migration**, the file aborts with nothing applied.
- **With the migration:**
  - DE ends at 12/48/278 with 3 losses (Aqua, bianc and Courtier, which
    need confirming), and every launch row is verified and relabelled 2025.
  - IT ends at 15/38/327: MICHELIN's live listing plus Lido 84, Quattro
    Passi and Santa Elisabetta, which are kept and need confirming.
    Tre Olivi is corrected to 1.
  - Each restaurant has one current row that agrees with
    `michelin_stars`.
- **A re-run aborts.**

The real export will differ: rows have been added since launch. The run is
repeated on it and the output reviewed before anything is committed for
apply.
