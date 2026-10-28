# MICHELIN Guide France 2026: completion, corrections and phones (2026-10-28)

Status: **PREPARED, NOT APPLIED.** Nothing in this folder has touched production.

| File | What it does |
|---|---|
| `supabase/migrations/20261019120000_add_fr_2026_star_cities.sql` | 82 French cities the new restaurants need. Moved into `supabase/migrations/` with your go-ahead, 2026-10-28; not applied. |
| `prepared_fr_stars_2026.sql` | 14 star corrections, 410 `michelin_url` fixes, and 173 new restaurants (`rest_1405`–`rest_1577`) with 2026 award rows |
| `prepared_fr_phone_backfill.sql` | 385 confirmed phones for French restaurants already in production |

Order: the cities migration must run before the stars file. The phone file is
independent and can run before or after either.

## Source

MICHELIN's own site is the only source.

- **Full list.** "La liste complète des Étoiles du Guide MICHELIN France 2026",
  published 16 March 2026. It has 668 starred restaurants (31 three-star,
  84 two-star, 553 one-star), and 62 are marked *Nouveau*. Nine are in
  Monaco, so France alone has 659. The parsed list is in
  `_source/michelin_full_list_2026_parsed.json`. The article contains two
  empty stray links (L'Amaryllis, L'Arcane), which were dropped. With them
  removed, the counts are exactly the article's stated totals.
- **Live listing.** On 2026-10-28, `guide.michelin.com/en/fr/restaurants/all-starred`
  shows 646 restaurants (30 three-star, 79 two-star, 537 one-star). The
  capture is in `michelin_fr_starred.csv`, and each restaurant page's
  structured data is in `michelin_fr_pages.csv`.
- **Restaurant pages.** Every restaurant's page was read: its structured data
  gives the award (`dateAwarded` 2026), address, coordinates, phone and website.
- **Agreement.** Every one of the 646 live entries is one of the article's
  659. The article, the listing and the restaurant's own page agree on the
  star count for every one. Eight article links were stale, and each was
  paired by hand to its current page (see `PAIR` in
  `_tools/classify.py`). Two of those pairs are renames (QA-222).

**The 2025 list was not the issue.** The August import took its data from
screenshots of the live site, so it already held the **2026** edition. 36 of
MICHELIN's 2026 *Nouveau* restaurants were already in production with the
2026 value. The import was incomplete and had some transcription errors, but
it was not a year out of date. So, unlike the Netherlands, nothing is
relabelled: the 2026 rows stay as they are, and the wrong ones are corrected
in place.

## What changes

| | Count |
|---|---|
| French restaurants matched to MICHELIN 2026 | 474 of 480. 456 by MICHELIN URL; 18 had no URL or a broken one and were matched by coordinates (≤124 m) plus name, all checked by hand. |
| Star corrections (QA-220) | 14 |
| `michelin_url` set or corrected (QA-223) | 410 |
| New restaurants | 173: 7 three-star, 24 two-star, 142 one-star |
| Starred FR after apply | **652** (30 three-star, 80 two-star, 542 one-star) = 646 live + 6 withdrawn already in production |

The 14 star corrections are listed in QA-220. Three are three-star
restaurants stored as two-star: Maison Lameloise, Le Coquillage and L'Oustau
de Baumanière. Le Suquet is stored as three-star and is one-star in all three
MICHELIN sources.

The seven new three-star restaurants are Le Clos des Sens, Les Morainières
(new in 2026), La Table du Castellet, Flocons de Sel, Troisgros, Alléno Paris
au Pavillon Ledoyen and Le Pré Catelan. Whole regions were missing from the
August screenshots, which is why 82 cities are missing, including Lyon,
Nantes, Rennes, Annecy and Megève.

New rows take their address, coordinates, cuisine, website and phone from
MICHELIN's page. Every coordinate was checked to fall inside France.
`property_name` and hotel links are left empty. Of production's 10 French
hotels, only one sits near a new restaurant: the Ritz is about 100 m from
Pur', and Pur' is in the Park Hyatt, so it is not a link.

## Not changed, logged instead

- **Withdrawn since March (QA-221).** 13 restaurants are in the 2026 article
  but their MICHELIN pages are now gone. Six are in production and keep their
  2026 stars, which are true for that edition. Seven are not added. The reason
  is not known for any of them. See `withdrawn_since_march.csv`.
- **Renames (QA-222).** `rest_0972` Jean Imbert au Plaza Athénée is now
  listed by MICHELIN as La Grande Table du Plaza Athénée. Its name and URL are
  untouched until you decide. Baumanière 1850 is now Slalom 1850; it is new
  to production and is added under its current name.
- **Monaco (QA-224).** Nine starred restaurants, out of scope until a decision
  is made.
- **Le Doyenné** (`rest_1383`) has no stars and is not part of this work.

## Phones

The rule follows the BE/LU run. A number is `confirmed` only if MICHELIN's
number for the restaurant also appears on the restaurant's own website: in a
`tel:` link or in the page text of the home page or up to four of the site's
own contact or booking pages. For a hotel restaurant, a number the site
labels only as the hotel or reception line is held back as a possible
switchboard.

| | Existing rows | New rows |
|---|---|---|
| Confirmed (in the SQL) | 385 | 148 |
| Site refused a plain download, or showed no number | 62 | 16 |
| Site shows a different number | 11 | 3 |
| Possible hotel switchboard | 7 | 5 |
| MICHELIN lists no phone, or no website | 6 | 1 |

These are counts of rows, by reason. A reason is given for every row in
`fr_phones_existing.csv` / `new_restaurants.csv` (QA-225). Five of the
"no number" sites were also checked in the browser, which runs their
JavaScript. On two of them MICHELIN's number then appeared on the site and
was confirmed. On a third, Le 1947, the matching number is Cheval Blanc
Courchevel's main hotel line, so it is held back. The browser pass was stopped
there because of cost. The rest are mostly large hotel groups (Four
Seasons, Oetker, Dorchester, Cheval Blanc), where the number shown would
likely be a switchboard anyway.

## Google Place IDs: not done

This session had no Places API key. After both files are applied, about 646
starred French restaurants need a Place ID (473 existing plus the 173 new
ones). The handoff is `PLACE_ID_HANDOFF.md`.

## Testing

All three files were run on a scratch PostgreSQL 17 database, seeded with
production's 480 French restaurants, their 482 award rows and the 329 French
cities, exported read-only on 2026-10-28. PostGIS was stubbed, so the
`location` value was not tested.

- **Stars file without the cities migration.** It aborts and names the
  missing cities. Nothing changes.
- **Cities migration, then stars file.** The result is 30/80/542 = 652. Every
  starred French restaurant has exactly one current star row, and that row
  agrees with `michelin_stars`. Award rows go from 482 to 655, cities from 329
  to 411.
- **Re-running the stars file.** It aborts at the code check.
- **Phone file.** It ran before and after the stars file: 3 existing phones +
  386 + 148 = 537 (385 after Le 1947 was held back, so 536 now). A re-run changes nothing.

None of the files was run against the real database.

## Not done here

- The Michelin_Database CHANGELOG entry is written once this is applied.
- The 13 withdrawn restaurants need a status check.
- Website backfill for existing rows: `official_website` is in
  `fr_phones_existing.csv`, ready for that.
- Belgium and Luxembourg were not re-checked against their own 2026
  selections.
