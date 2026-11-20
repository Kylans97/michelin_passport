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
