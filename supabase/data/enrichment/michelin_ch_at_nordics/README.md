# Switzerland, Austria and the Nordics: completeness check (2026-11-01)

Status: **PREPARED, NOT APPLIED.** A follow-up to `../michelin_ch_at_nordic_2026/`
(on main, applied 2026-10-30), which added these countries' restaurants and
Key hotels but **no Google Place IDs**. This pass fills those. Generated from production's export of
2026-11-01 (`export_query.sql`) by `../michelin_de_it/build_prepared_de_it.py`:

```
python3 build_prepared_de_it.py chn_export.json 3813 (no migration) 400 CH,AT,DK,NO,SE,FI,IS ../michelin_ch_at_nordics prepared_ch_at_nordics_stars.sql
```

Apply: `prepared_ch_at_nordics_stars.sql` alone (one transaction, no
migration needed: every town already exists). Review `match_report.csv` first.

## Result: the catalogue is complete

MICHELIN's live listing (`michelin_starred.csv`, 326 restaurants, read
2026-11-01) was compared with production's 334 rows, matched by MICHELIN
slug, then Place ID, then coordinates; never by name alone.

- **No restaurants missing.** Every live starred restaurant is in production.
  The one exception is PAZ (Tórshavn), which MICHELIN lists under Denmark and
  production already holds under the Faroe Islands.
- **No star changes.** Every matched row already holds MICHELIN's current
  value. The edition labels are right: Switzerland 2025 (announced 2025-10-20,
  the current Swiss edition); Austria 2026; the Nordics 2026.
- **5 rows offline on MICHELIN's site:**
  - **Kept at their current value:** 4 Swiss two-stars, all in MICHELIN's 2025
    Swiss article. IGNIV Bad Ragaz, Stucki and Skin's are QA-362; La Brezza
    Ascona is QA-400. **Switzerland's 2026 edition is announced on
    2 November 2026** (QA-360). This file changes no stars, so it can be
    applied before or after that.
  - **Left untouched, needs a decision:** Aloë (SE), QA-363, with the count
    evidence in QA-401.

## What the file writes (fill-only, never overwrites)

| | Place ID | Phone | Website | property_name |
|---|---|---|---|---|
| CH | 31 → 132 | 123 → 127 | | 4 → 5 |
| AT | 20 → 91 | 93 → 97 | | |
| DK | 9 → 41 | 37 → 40 | | |
| NO | 3 → 21 | 13 → 14 | 20 → 21 | |
| SE | 6 → 24 | 20 → 21 | | |
| FI | 1 → 8 | | | |
| IS | 0 → 3 | | | |

These are restaurant rows, before → after, from 256 fills. Evidence per row
is in `{cc}_research.csv`.

Held back from the fills:
- Obauer (AT): its Google record is `CLOSED_PERMANENTLY`.
- Capri and PM & Vänner: the numbers are hotel switchboards.
- 3 rows where `../europe_gaps/` had chosen the combined hotel record:
  Alpenblick (CH), Lukas Kapeller (AT) and Frederiksminde (DK). Here the
  restaurant's own record is used instead, and those rows were taken out of
  the gap files, so the two packages no longer disagree on any value.
- La Brezza Arosa and Döllerer: their stored Place IDs differ from the search
  result and are kept (QA-402).
- Vyn: its stored point is 2.4 km off (QA-403); no coordinate changes are
  made here.

## Tested

The file was run on a scratch Postgres 16 + PostGIS database seeded with the
real export:

- **Post-conditions:**
  - CH 4/27/103, AT 2/19/78, DK 3/6/32, NO 2/2/17, SE 1/5/18, FI 0/2/6,
    IS 0/0/3.
  - One current award row per restaurant.
- **Re-runs:** a re-run is harmless, since the file only fills.
- **A renamed exported row** aborts the whole file.

It was not run against the real database or a full migration replay.

## Not checked

The Key hotels' membership. The Key counts match MICHELIN's articles; each
hotel was not checked one by one.
