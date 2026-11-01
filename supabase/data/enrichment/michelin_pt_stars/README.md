# MICHELIN Guide Portugal 2026: catalogue completion (2026-11-01)

Status: **PREPARED, NOT APPLIED.** Run, in order:

1. `supabase/migrations/20261031160000_add_pt_2026_star_cities.sql`
   (24 towns)
2. `prepared_pt_stars_2026.sql` (one transaction; it aborts on any failed
   check)

## What it does

- **Source:** MICHELIN Portugal 2026, announced 10 March 2026 in Funchal.
  The live listing shows 53 restaurants: 9 with two stars, 44 with one star,
  none with three. Every page reports `dateAwarded "2026"`.
- **Before:** production held one restaurant, Belcanto (2 stars). It is
  matched by its Google Place ID; its 2026 row (2) is correct, so no relabel
  is needed.
- **Added:** 52 restaurants (`rest_3761`–`rest_3812`), each with a 2026
  history row. 50 have a Place ID and 50 a phone; all have a MICHELIN link
  and a website.
- **Hotels:** production has no Portuguese hotels. The 20 restaurants that
  MICHELIN places in a hotel therefore get `property_name` (hotel scope
  rule 3). 16 of those hotels hold a Key; when they are added, the links
  follow.
- **Left blank** (QA-398):
  - Place IDs for A Cozinha do Paço and Herdade do Esporão.
  - Éon's phone, because its site shows only the hotel switchboard.
- **Towns:** names follow MICHELIN's English listing, matching production's
  "Lisbon". Guimarães and Portimão keep their diacritics, which MICHELIN's
  English listing drops.

## Evidence

- `pt_research_2026.csv`: per restaurant, with Place ID, phone and hotel.
- `michelin_restaurant_pages_20261101.jsonl` and
  `michelin_hotel_pages_20261101.json`: the MICHELIN pages as captured.
- `match_report.csv`: the existing row and how it was matched.

The SQL comes from `../michelin_de_it/build_prepared_de_it.py`, now generic
per country.

## Tested

Run on a scratch PostgreSQL 16 + PostGIS database seeded with the export:

- **Without the migration**, the file aborts.
- **With it**, PT ends at 0/9/44 with one current row per restaurant.
- **A re-run** aborts.
- **A renamed Belcanto** aborts the whole file.

It was not run against the real database.
