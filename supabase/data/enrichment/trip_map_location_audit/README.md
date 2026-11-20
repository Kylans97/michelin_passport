# Trip map location audit — 2026-11-20

Read-only against production. Nothing here has been written to Supabase.

Reported: "on the map with trips the restaurants and hotels don't always
appear on the right place".

## Checks that found nothing

- Latitude/longitude order: `restaurants_full`/`hotels_full` expose
  `st_y(location)` as latitude and `st_x` as longitude; the app reads them
  in that order. No swapped pair was found: every venue was compared with
  the median of its own city (>25 km) and its own country (>1,200 km); all
  outliers are real (Canary Islands, Hawaii, Okinawa, Baja, Yucatán, regional
  "cities" such as Mallorca or Napa).
- No (0, 0) or near-zero points except Quito (`rest_1374`, EC), which is on
  the equator.

## What did turn up

1. **Low-precision seed coordinates.** 139 rows carry at most 4 decimals;
   119 of them are the original seed restaurants `rest_0001`–`rest_0143`
   (95 of production's 131 NL restaurants). Each stored `address` was
   geocoded with public Nominatim (free-form, one result, country-scoped,
   1.2 s apart) and compared with the stored point:
   `low_precision_vs_osm_address.csv`.
   - 106 geocoded, 33 not found.
   - 25 within 150 m, 36 at 150–500 m, 13 at 500–1,000 m, 32 over 1 km
     (up to 5.2 km: `rest_0087`, Gulpen).
   - Where these points came from was not established (not checked
     whether they are city centroids or rounded from another source).
2. **Hotel ↔ restaurant links far apart** (`hotel_restaurant_links_over_400m.csv`).
   The worst three are seed rows from (1): `rest_0008` (FR, 3.1 km from
   `hotel_2154`), `rest_0021` (NL, 2.0 km from `hotel_02`), `rest_0022`
   (NL, 1.8 km from `hotel_13`). `rest_0008`'s own address (91 Rue du
   Cherche-Midi) is not the address of the hotel it is linked to (Place des
   Vosges): an identity question, not just a coordinate one — held back.
3. **119 pairs of venues within 10 m** of each other (mostly a restaurant
   inside its hotel). Not a data error; this was the app-side bug, fixed in
   `lib/features/trips/trip_map/`.

## Not verified

- An OSM hit is a candidate, not a verified point: some resolved only to a
  street (`highway`) or a neighbouring building (`shop`, `office`). None of
  these should be imported as-is. Each correction needs the usual
  per-venue verification (MICHELIN Guide page + one corroborating source,
  structured and venue queries agreeing within 150 m, per
  `michelin_bulk_location_enrichment/BULK_LOCATION_METHOD.md`), a QA id from
  `qa_issues.csv`, and an entry in the Michelin_Database changelog.
- The 33 not-found rows and the non-NL rows were not researched further.
- Nothing was reproduced in the simulator (it needs a signed-in account).

## Verified coordinates for the seed restaurants (staged, 2026-11-20)

`seed_coordinates_staged.csv`: one row for each of the 119 seed restaurants
(`seed_scope.csv`: restaurant codes up to `rest_0143` whose stored point has
at most 4 decimals). Nothing has been written to Supabase.

**101 confirmed, 18 unclear.** Across the confirmed rows, the median
distance from the stored point is 752 m: 61 move more than 500 m and 45
more than 1 km.

### Method

1. **First pass, stored address** (`first_pass_nl_bag_osm.csv`, NL only).
   - Look up the street and house number in the official Dutch address
     register (BAG, via PDOK Locatieserver).
   - Corroborate with an OpenStreetMap eating place of the same name within
     150 m (`VENUE_EXACT`).
   - 26 rows passed. A 27th, `rest_0055`, passed on BAG street, number and
     postcode alone.
   - Every other row was sent to research, including those where an OSM
     venue stood more than 150 m away (`CONFLICT`).
2. **Research** (`research/batch_*_in.csv` / `_out.csv`, 92 rows).
   - The current address comes from the venue's own website plus a second
     independent source: the MICHELIN Guide, or World's 50 Best where
     MICHELIN has no guide.
   - The research found the stored address unreliable. Most rows had the
     wrong street, house number, postcode or town, and some were a former
     location.
3. **Geocoding** (`scripts/final.py`).
   - A coordinate is written only when the address is confirmed and the
     hit is at house level.
   - NL: BAG on exact postcode + house number, with the street name
     checked.
   - Elsewhere: OSM with the same house number and postcode.
   - Every Dutch point is also checked to fall inside the Netherlands.
   - `coordinate_source` and `source_url` name the exact BAG or OSM record.

### Held back (certainty `unclear`, no coordinate)

- **Address confirmed, but no house-level geocode:**
  - `rest_0136` AR, `rest_0138` CL, `rest_0143` CO, `rest_0067` ES
    (Passeig de Gràcia 38-40), `rest_0137` HK, `rest_0077` IT,
    `rest_0139` PE, `rest_0080` US.
  - `rest_0093` NL: Museumstraat 2 is not in BAG.
  - `rest_0082` NL: Hoofdstraat 75 is not in BAG, and sources disagree
    between 73 and 75.
- **Address not confirmed:**
  - `rest_0092` NL: Wolfslaardreef 100 or 102.
  - `rest_0115` NL: the official site is unreachable.
  - `rest_0072` NL: Noor is closing; the address rests on MICHELIN only.
  - `rest_0071` TR: the house number comes from MICHELIN only.
  - `rest_0059` US: the official site gives only a mailing address.
- **Closed:**
  - `rest_0043` NL Demain: left Strandhotel Cadzand on 2026-05-31; no
    new location yet.
  - `rest_0108` NL The White Room: "officieel gesloten"; whether the
    closure is permanent is not established.
  - `rest_0140` BR Lasai: closed while it moves to the Sofitel Ipanema,
    December 2026.

### Status findings for review

- **Moved:**
  - `rest_0014` Bolenius, to Nachtwachtlaan 20B.
  - `rest_0037` De Librije, to Spinhuisplein 1.
  - `rest_0048` Fred, to Boompjes 41.
  - `rest_0066` ML, to Klokhuisplein 5 (since 2018).
  - `rest_0088` Calva, to Markt 53 Nootdorp.
  - `rest_0098` Sense, to Raadhuisstraat 1 Vught.
  - `rest_0137` The Chairman, to The Wellington (2022).
- **Moves announced:**
  - `rest_0096` Sabero, to Eindhoven on 2027-02-01.
  - `rest_0113` Versaen, to Marktstraat 14 in mid-February 2027.
  - Both coordinates are for the current location; re-check after the
    move.
- **Renamed:** `rest_0070` Noble Kitchen became Nami (2026-05-20); the
  catalogue already uses the new name.
- **Data mix-up:** `rest_0032` De Juwelier was stored at Zoldering's
  address, Utrechtsestraat 141.
- **Hotel link:** `rest_0008` Anne is at 28 place des Vosges, inside
  Pavillon de la Reine. Its stored Cherche-Midi address was wrong, so its
  link to `hotel_2154` holds.

### Limits

- **Stored address not researched for the 27 first-pass rows.** For those,
  the coordinate is corroborated by the BAG address plus an OSM venue of
  the same name (26 rows), or by the BAG address with a matching postcode
  alone (`rest_0055`).
- **Address corrections are not part of this file.** `current_address`
  is recorded as evidence, but correcting the `address` column is a
  separate decision.
- **A BAG point is the building's address point, not the entrance.** For a
  restaurant inside a large building (a hotel, Rijksmuseum), it is the
  building's address.
- **Before applying,** each correction needs a QA id from `qa_issues.csv`
  and a Michelin_Database changelog entry. Guard each update on the old
  point, as earlier coordinate corrections did.
