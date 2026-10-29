# Germany & Italy: MICHELIN completion, Place IDs and phones (research 2026-10-29)

Status: **research complete; SQL not yet written**. Writing it needs
production's current Germany/Italy rows: run `export_de_it_query.sql` in
the Supabase SQL Editor (read-only, one JSON cell), download the result as
CSV and upload it to the session.

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

1. Match production's DE/IT rows to MICHELIN:
   - by `michelin_url`;
   - otherwise by coordinates plus a name check, as for Spain.
2. Write a cities migration for the new towns, named after the highest
   migration on main at that time.
3. Write the prepared SQL, with the same guards as Spain:
   - codes must be free, and each existing code must still carry its
     exported name;
   - post-conditions: DE 12/48/278, IT 14/37/326.

   It includes:
   - the Germany relabel;
   - losses;
   - new rows with their history, Place IDs and phones;
   - fill-only updates on existing rows;
   - hotel links.
4. Test it on a scratch Postgres + PostGIS seeded from the export.
