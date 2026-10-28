# MICHELIN Gids Nederland 2026: star update (2026-10-28)

Status: **PREPARED, NOT APPLIED.** The SQL file is `prepared_nl_stars_2026.sql`.

## Source

MICHELIN's own site is the only source.

- **Listing.** `guide.michelin.com/en/nl/restaurants/all-starred` shows 119
  restaurants: 1 with three stars, 20 with two and 98 with one. Its pagination
  totals and the per-tier pages agree. The capture is in
  `michelin_nl_starred.csv`.
- **Full-list article.** "De volledige lijst van de Sterren in de MICHELIN Gids
  Nederland 2026" (5 October 2026) matches the listing one-to-one by MICHELIN
  page address.
- **Guide year.** MICHELIN calls this selection **2026**. The exact quote is in
  `GUIDE_YEAR.md`. Press that calls it 2027 is wrong for the Netherlands.
- **Comparison.** MICHELIN's 2025 full list is in `_source/` and was used for
  the comparison. MICHELIN publishes no list of lost stars, so every loss below
  is derived by comparing the two lists. The one exception is De Groene
  Lantaarn's closure, which MICHELIN states.

## Guide-year decision (option A, user, 2026-10-28)

The Dutch award_history rows seeded at launch carry `guide_year = 2026`, which
is the documented launch convention. Their values, however, are the **2025**
edition's: they were verified against MICHELIN's 2025 list, and every row
matches except the two import errors below. The unique key
`(entity, guide_year, award_type)` leaves no room for real 2026 rows beside
them.

So the update does this:

1. It relabels the 118 launch rows to 2025. Their values are unchanged.
2. It writes 2026 rows only where something changed. It closes the 2025 row
   first, which follows the update process's cardinal rule.

Unchanged restaurants keep their 2025 row as current.

## What changes

| | Restaurants |
|---|---|
| Lost their star: 2025 row closed, 2026 = none, `michelin_stars` NULL | Da Vinci, De Juwelier, Demain, Sense, Daalder; Spectrum and De Groene Lantaarn (both already closed) |
| Lost in 2026, already NULL in production, now recorded | De Woage |
| Import errors corrected: never starred in 2025 or 2026 (QA-216) | Graphite by Peter Gast, Zheng |
| MICHELIN page moved: `michelin_url` corrected, stars the same | 18, including Alma, Apicius, Nami (MICHELIN slug `noble-kitchen`), Noor, Tribeca, Yamazato |
| Newly starred: added `rest_1396`–`rest_1404` with a 2026 row | **2 stars:** Azurite (Delft), SUIS (Schin op Geul). **1 star:** Ambrozijn, Bij Sidney, De Cuijt, Le Epifaan, Nassau (Hotel Prinsenhof), Rozewied, Wild Atelier (De Echoput) |

The details of the new restaurants are in `new_restaurants.csv`: address,
coordinates and cuisine from MICHELIN, and website and phone from each
restaurant's own site.

- SUIS's phone is left empty because two sources conflict (QA-218).
- Rozewied moves in spring 2027 (QA-218).
- Neither hotel holds MICHELIN Keys, so `property_name` is used, not a hotel
  link. This follows CLAUDE.md hotel-scope rule 3.
- None of the nine has a Google Place ID yet. They can go into the Place ID
  backfill.

## Before running

Every new restaurant's city must exist. The file aborts and names any that
does not. To check, run:

```sql
select n.city, (select count(*) from cities c where c.country_code = 'NL' and c.name = n.city) as matches
from (values ('Valkenburg'),('Delft'),('Loenen aan de Vecht'),('Mierlo'),('Veeningen'),
             ('Groningen'),('Kortgene'),('Schin op Geul'),('Hoog Soeren')) n(city);
```

A town that shows 0 needs a city row, which is a small migration.

## Order with the other prepared files

The codes do not collide. The World's 50 Best import reserves `rest_1369`–`1395`
and this file uses `rest_1396`–`1404`. Either can go first.

## Testing

The file was run on a scratch PostgreSQL 16 + PostGIS database seeded with all
120 Dutch rows exactly as exported (stars, every history row, current flags).
It reached 1/20/98 = 119 starred, and every Dutch restaurant ended with exactly
one current star row agreeing with `michelin_stars`. A re-run aborts at the
first check.

It was not run against the real database. The seed carried no other columns,
and phone, website and Place ID were not involved in the test.

## Not done here

- `DATABASE_ARCHITECTURE.md` and `DATA_UPDATE_PROCESS.md` still describe the
  launch rows as `guide_year = 2026`. Updating them needs your go-ahead (QA-217).
- The Michelin_Database CHANGELOG entry is written once this is applied.
