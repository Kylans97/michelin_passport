# Journeys — train and ship candidates (staged, not imported)

Checked 2026-11-16 against operator pages and operator press releases. A fact
that only appeared in press or trade sources is left blank, with the claim
written in `unverified_notes`. The plan is in `docs/Architecture/JOURNEYS_PLAN.md`.
Nothing here goes into Supabase until the product owner picks the rows.

- `trains_candidates.csv` — 15 rows.
- `ships_candidates.csv` — 17 rows, one per ship, not per brand.

## Held back, or not ready

- **Rovos Rail, The Blue Train:** the operator sites sit behind bot checks.
  Only the name, URL and the routes from the Blue Train homepage are filled in.
- **The Ghan:** the onboard pages returned 404, and it has the weakest
  gastronomy case of the trains.
- **Belmond Grand Hibernian:** discontinued. It is kept as a row so it is not
  re-added by mistake.
- **Seven Stars in Kyushu:** the official page contradicts itself on the
  number of suites.
- **Hiram Bingham:** a day train, not a night aboard.
- **Amanikan:** not on Aman's current yachts page.
- **Belmond Road to Mandalay:** no longer offered by Belmond.
- **Sanctuary Sun Boat IV:** A&K's own pages disagree on cabins and capacity.
- **Orient Express Olympian (summer 2027), Amangati (spring 2027):**
  announced, not yet sailing.
- **Ilma, Luminara:** left out. At about 450 guests they are too large.

## MICHELIN claims

The trains research checked chef stars on guide.michelin.com. The ships rows
quote only what the operator says, so they still need checking against the
Guide before any of that text is shown.

## Not yet researched

Shiki-shima (JR East returned 403), Rocky Mountaineer GoldLeaf, Al Andalus,
Royal Canadian Pacific, Desert Express, Golden Eagle Trans-Siberian.

## Route stops (2026-11-20, loaded into production)

Ordered stops with coordinates for 25 of the 38 routes, so a route can be
drawn on the journey page: `journey_route_stops_20261120.csv` (source URL,
coordinate source and note per row), `journey_route_stops_seed_20261120.sql`
to insert them, and `supabase/migrations/20261101610000_add_ro_bg_ba_countries.sql`, which must
run first (adds RO, BG, BA). The 13 routes held back and the rows flagged
for review are in `journey_route_stops_HELD_BACK.md`. Both were run on a scratch Postgres
first, then applied to production on 2026-11-20 on the product owner's
approval.
