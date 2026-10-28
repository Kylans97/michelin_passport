# Place ID backfill — results (2026-10-28)

Prepared, **not applied**. Brief and queue query: `README.md` (on branch
`claude/upbeat-ramanujan-4kedct`). Evidence per row: `placeid_results.csv`.
SQL: `prepared_place_id_backfill.sql`.

Input: production export of README Step 1, 90 rows (75 ranked hotels, 15 NL
restaurants), plus hotel_801 Singita from the prepared W50B import. Places API
(New) `places:searchText`, name + city with a 2 km location bias, distance
measured against the stored coordinates.

| | Hotels | Restaurants |
|---|---|---|
| confirmed, in SQL Step 1 | 69 | 8 |
| confirmed, Singita (SQL Step 2, after the W50B import) | 1 | — |
| confirmed, outside handoff scope (commented out) | — | 2 (Zheng, De Woage) |
| unclear | 5 | 5 |
| blocked (mainland China) | 1 | — |

All 80 confirmed rows are under 100 m (most under 50 m) with the right record
type. Name differences are brand/operator suffixes only ("…, A Belmond Hotel",
"…, Beckons", "Bvlgari", "Restaurant X").

## Not filled, and why

- **hotel_744 Six Senses Zighy Bay** — right name and type, but 1,571 m from our
  coordinates. Rejected by rule; our stored location is the likely error.
- **hotel_748 Amangalla** — 496 m; stored coordinates look like a rounded DMS
  conversion. Re-verify coordinates first.
- **hotel_693 Hotel Cipriani** — 130 m; Google shows CLOSED_TEMPORARILY
  (probably the seasonal closure).
- **hotel_727 Desa Potato Head** — 101 m. **hotel_760 Jumeirah Marsa Al Arab** — 140 m.
- **hotel_704 Mandarin Oriental Qianmen** — mainland China, skipped by rule.
- **rest_0784 Merlet, rest_0789 De Swarte Ruijter, rest_0790 't Lansink,
  rest_0791 De Bloemenbeek** — Google has one combined hotel-restaurant record
  whose primary type is *hotel*; no separate restaurant record exists. None
  is a Key hotel, so using it would clash with nothing — reviewer's call.
- **rest_0781 Graphite by Peter Gast** — no Google record. The address
  (Paardenstraat 15, 3rd floor) resolves to Vaanya, a different restaurant
  at street level.

## Pattern

Hotels: Google's coverage is complete — every ranked hotel outside mainland
China has a lodging record. The trap was as documented: for Four Seasons Hong
Kong, Aman New York and Gleneagles, the nearest record was a restaurant, bar,
spa or bare building, not the hotel. Dutch hotel-restaurants are the real gap:
Google treats the property as one hotel listing.

## Tested

Run against a scratch Postgres 16 with `hotels`/`restaurants` stubs seeded
from the export: fills 69 + 8; a rerun is a no-op; an ID held by another row
aborts with nothing applied; an unknown code aborts with nothing applied; an
existing different ID is kept and reported; Step 2 aborts until hotel_801
exists and fills it once it does. Not tested against the real schema
(triggers, RLS) — the statements touch only `google_place_id`.
