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
| confirmed, in SQL Step 1 | 73 | 14 |
| confirmed, Singita (SQL Step 2, after the W50B import) | 1 | — |
| left out | 2 | 1 |

Most confirmed rows are under 100 m with the right record type. Name
differences are brand/operator suffixes only ("…, A Belmond Hotel",
"…, Beckons", "Bvlgari", "Restaurant X").

## Double-checked and included (second pass, same day)

Each against the venue's own website and OpenStreetMap. Every one of these
Google records links to the venue's official site with Google-Business
tracking tags, i.e. a listing the venue manages itself.

- **hotel_748 Amangalla (496 m)** — *our* coordinates are wrong. Official
  site: 10 Church Street, "within the ramparts of Galle Fort". Google's pin
  and OSM's building outline agree on 6.0286, 80.2170; our stored point
  falls on a wine shop on Wakwella Road, outside the fort. Coordinate fix
  prepared, commented out, in the SQL (needs a QA id first).
- **hotel_693 Hotel Cipriani (130 m), hotel_727 Desa Potato Head (101 m),
  hotel_760 Jumeirah Marsa Al Arab (140 m)** — both points lie on the same
  property (Giudecca 10 compound; the Petitenget 51B complex, where ours is
  the Beach Club; the resort's own island). Cipriani's CLOSED_TEMPORARILY
  is its seasonal winter closure.
- **Merlet, De Swarte Ruijter, 't Lansink, De Bloemenbeek** — Google's only
  record is a combined hotel-restaurant listing; accepted on the owner's
  instruction. None is a Key hotel.
- **Zheng, De Woage** — outside the 13 named in the handoff, included on
  the owner's instruction.

## Left out

- **hotel_744 Six Senses Zighy Bay** — the record is the resort's own
  listing, but Google's pin sits at the clifftop restaurant (Sense on the
  Edge), 1.57 km from the beach. Our coordinates match OSM's hotel node on
  the bay and look right. Over the 500 m rule; offered commented out in the
  SQL.
- **hotel_704 Mandarin Oriental Qianmen** — mainland China, skipped by rule.
- **rest_0781 Graphite by Peter Gast** — no Google business record (hidden
  door speakeasy). MICHELIN gives Paardenstraat 11; we hold 15III — worth a
  QA entry.

## Pattern

Hotels: Google's coverage is complete outside mainland China. The trap was
as documented — for Four Seasons Hong Kong, Aman New York and Gleneagles the
nearest record was a restaurant, bar, spa or bare building. Resort pins can
be wrong in remote terrain (Zighy Bay). Dutch hotel-restaurants are listed
by Google as one hotel. Round-number stored coordinates (Amangalla's
6.03306, 80.21667) are a tell that our own location is the error.

## Tested

Run against a scratch Postgres 16 with `hotels`/`restaurants` stubs seeded
from the export: fills 73 + 14; a rerun is a no-op; an ID held by another row
aborts with nothing applied; an unknown code aborts with nothing applied; an
existing different ID is kept and reported; Step 2 aborts until hotel_801
exists and fills it once it does. Not tested against the real schema
(triggers, RLS) — the statements touch only `google_place_id`. Optional
block (b) was run and fills hotel_744; optional block (a) was not run (no
PostGIS in the scratch database).
