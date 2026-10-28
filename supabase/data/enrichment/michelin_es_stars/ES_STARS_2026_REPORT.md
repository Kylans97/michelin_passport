# MICHELIN Guide Spain 2026: catalogue completion, Place IDs and phones (2026-10-28)

Status: **APPLIED 2026-10-28** (ledger 104/104; see the Michelin_Database CHANGELOG). Run, in order:

1. `supabase/migrations/20261019140000_add_es_2026_star_cities.sql` (123 towns)
2. `prepared_es_stars_2026.sql` (one transaction; aborts on any check)

## Source

MICHELIN alone decides the selection:

- **Live listing:** `guide.michelin.com/en/es/restaurants/{3-stars,2-stars,1-star}-michelin`
  shows 296 restaurants: 16 three-star, 37 two-star and 243 one-star. Every
  restaurant is unique and has coordinates. Capture: `michelin_es_starred.csv`.
- **Each restaurant's own page** (all 296 read): the JSON-LD gives the address,
  coordinates, phone and cuisine, plus `dateAwarded "2026"` and a star rating
  that matches the listing on every row. The page also gives the website and
  the "Stay at the hotel" link. Capture: `_source/michelin_restaurant_pages_20261028.jsonl`.
- **2026 full-list article:** "Todos los restaurantes con Estrellas MICHELIN en
  España 2026", published 25 Nov 2025 with 307 entries (16/37/254, 30 new),
  which matches MICHELIN's own figures. Capture:
  `_source/michelin_full_list_2026_parsed.json`.

**Reconciling the article (307) with the live listing (296).** The article
includes 1 Andorra entry (Ibaya, Soldeu), which is outside Spain. 10 Spanish
one-stars have since been taken off MICHELIN's site (QA-234), and none of
them is in production. The remaining differences are MICHELIN renaming
entries on the live site: Pepe Vieria → Pepe Vieira, Eirado → O Eirado,
O'Pazo → Asador O'Pazo, Víctor Gutiérrez → Tayta by Víctor Gutiérrez,
La Gaia → brula (same page), El Poblet → Flores Raras, and similar.
306 − 10 = 296 ✓.

## Guide year

MICHELIN labels this selection **2026**: the gala was in Málaga on 25 November
2025, and every page's JSON-LD carries `dateAwarded "2026"`. All 57 Spanish
rows in production were checked against the live listing, and their 2026
rows hold this edition's values, so **no relabel** is needed. The **2027
edition is announced on 1 December 2026 in Huesca**. Applying it is a
separate update.

## Production before

The export of 2026-10-28 holds 57 ES restaurants: 16 three-star, 36 two-star
and 5 one-star, every one with a matching current 2026 row. All 57 already
have a Place ID, 47 have no phone and 35 have no `michelin_url`. The 57 were
matched to MICHELIN as follows:

- 17 by their stored link.
- 40 by coordinates. Each match was checked by name and lies 2–160 m away,
  except two whose stored coordinates are wrong (QA-232).

## What the SQL does

| Change | Count |
|---|---|
| New restaurants `rest_1588`–`rest_1826` with a 2026 history row (announced 2025-11-25) | 239 |
| … with a confirmed Google Place ID | 235 |
| … with a confirmed phone | 232 |
| … with `property_name` (sits in a non-Key hotel) | 9 |
| New links to Key hotels (12 new restaurants + Voro) | 13 |
| Existing rows: `michelin_url` filled where null | 35 |
| Existing rows: phone filled where null | 46 |
| Existing rows: `property_name` filled (DiverXO: NH Eurobuilding; M.B: Ritz-Carlton Abama) | 2 |
| Deessa's stored link, which returns 404, replaced (guarded on the old value) | 1 |

After the update, Spain matches MICHELIN's live 2026 listing exactly:
16 / 37 / 243, with one current star row per restaurant.

Codes start at 1588 because Monaco's prepared file
(`michelin_mc_2026/`, on main) claims 1579–1587. The SQL aborts if any code
in the range is already taken.

## Place IDs (find-place-id rules)

- **Search:** name + town near MICHELIN's coordinates, using the Places API (New).
- **Confirmed** when all of these hold:
  - the record is under 100 m away;
  - the name and type are right, meaning the restaurant itself and not its hotel.
- **Confirmed between 100 and 500 m** only when Google's address and the
  official website on the record both agree with MICHELIN's. That applies to
  11 rows: As Garzas, Barahonda, Canfranc Express, Citrus del Tancat,
  El Ermitaño, El Retiro, Esperit Roca, El Batán, Il Bocconcino, Poemas and
  Sollo.
- **Overrides,** each noted in the CSV:
  - Castell Perelada: the restaurant record was chosen, not the castle's.
  - Spelling variants: Ansils/"Ancils", Fishølogy and San-Hô.
  - ReComiendo: Google's name differs, but the address and domain are the same.
  - Casa Arcas and Pico Velasco: Google has only one combined hotel-restaurant
    listing under the same name. These follow the Dutch decision.
  - Nub: Google's pin is inside the Bahía del Duque resort; MICHELIN's pin is
    the outlier (QA-233).
- **Left null** (4):
  - Boroa and Casa Gerardo: more than 500 m off (QA-233).
  - Corral de la Morería Gastronómico and Coto de Quevedo Evolución: Google
    has only the venue's or the hotel's record (QA-239).
- **The 57 stored IDs** were re-checked against MICHELIN's coordinates:
  - All are within 190 m, and none points to a hotel.
  - Molino de Urdániz's stored record is now called "Origen DY" but carries
    MICHELIN's exact phone number. It is the same business, so it is kept.

## Phones

- **Confirmed**
  - 267: MICHELIN and Google agree.
  - The rest: the number is printed on the venue's own site.
    - When the site shows both numbers, MICHELIN's is kept.
    - When the site shows only a hotel switchboard, the phone is left
      unclear, as in the Dutch pass.
- **Format:** stored as MICHELIN prints it ("+34 9xx xx xx xx"), which matches
  production's existing Spanish phones.
- **Left out:** 8 restaurants (QA-237).
- **Not overwritten:** Aponiente's stored number disagrees with the
  MICHELIN/Google number (QA-236).

## Towns and hotels

- **Towns:** each restaurant gets MICHELIN's town as printed on the Spanish
  site (es/es), which is how production writes Spanish towns. Places that
  already exist are reused:
  - San Sebastian for Donostia
  - Sevilla
  - València
  - Malaga
  - La Coruña
  - Alicante for Alacant
  - Lasarte-Oria
  - Atxondo for Axpe

  Restaurants never get an island or area row (Mallorca, Tenerife, Costa
  Brava); those rows are only used by hotels.
- **Key-hotel links** are made only when both hold:
  - MICHELIN's "Stay at the hotel" page carries a Key;
  - that hotel's MICHELIN pin is within 150 m of one of our `hotels` rows.

  None of our Spanish Key hotels has a stored `michelin_url`, so the link can
  never rest on the name. Confidence is `exact` when the restaurant's pin is
  within 100 m of the hotel, otherwise `campus`. Royal Hideaway Corales
  *Resort* is our hotel_545 (MICHELIN renamed it; it is the same page and
  ~15 m away).
- **Other hotels:** a restaurant in a hotel that is not a Key hotel gets
  `property_name` and no link. A check after the update confirms no
  restaurant has both.

## Not done

- `cuisine_id` is left null for the new rows, as in the NL and BE imports.
  MICHELIN's cuisine text is in the CSV.
- No coordinate corrections (QA-232, QA-233).
- No star history before 2026, which is the usual launch limitation.

## Testing

The SQL was run on a scratch PostgreSQL 16 + PostGIS database. It was seeded
with every exported ES row: cities, the 57 restaurants with all their history
rows, the 110 Key hotels and the 10 links. The real uniqueness constraints
were copied, including the partial unique index on current award rows.

- **Without the migration**, the file aborts at the city check and nothing
  is applied.
- **With the migration**, the result is 16/37/243 with 296 current rows. The
  totals come to 292 Place IDs, 288 phones, 296 MICHELIN links, 11 property
  names and 23 links.
- **Re-runs:** the migration changes nothing on a second run, and the file
  aborts at the first check.
- **Identity guard:** each of the 57 existing codes must still carry its
  exported name, so the fills can only reach the restaurant they were
  researched for. Renaming one row in the test makes the whole file abort
  with nothing applied.

It was not run against the real database or a full migration replay.
