# Google Place IDs for starred French restaurants: handoff (written 2026-10-28)

**For a session that has a Google Places API key.** The session that wrote this
had no key (`GOOGLE_PLACES_API_KEY` was unset). The user chose to finish the
stars and phones first. Never print the key or commit it.

## When

Run this after `prepared_fr_stars_2026.sql` is applied. Then the 173 new
restaurants are in the queue with their MICHELIN coordinates, and the 18
production rows that had no or a broken MICHELIN URL have one.

## Step 1 — get the queue from production

```sql
select restaurant_code as code, name, city_name, latitude, longitude, address,
       website_url, michelin_url, status
from restaurants_full
where country_code = 'FR' and michelin_stars is not null
  and google_place_id is null and status <> 'permanently_closed'
order by restaurant_code
limit 100 offset 0;
```

The SQL Editor returns 100 rows at most, so page through with `offset`.
`supabase db query --linked` returns them all at once. Expect about 640 rows.

## Step 2 — method

Use the same method as `../place_id_backfill/README.md` (Step 2) and the
`find-place-id` skill.

- Use Places API (New) `places:searchText` with name + city and a
  `locationBias` around the stored coordinates.
- Distance to the stored coordinates decides the result:
  - **under 100 m**, with the right name and a restaurant type: `confirmed`;
  - **100–500 m**: `unclear`;
  - **over 500 m**: rejected.
- The record must be the restaurant, not its hotel. Many French starred
  restaurants sit inside hotels; one example is `Pur'` in the Park Hyatt
  Paris-Vendôme. A candidate ID already used by another restaurant row is
  `unclear`.
- Record `businessStatus` (CLOSED_PERMANENTLY / CLOSED_TEMPORARILY) as a
  finding. This matters most for the six restaurants MICHELIN has withdrawn
  since March (QA-221).

The stored coordinates for the 473 rows from the August import came from that
import's own location step, not from MICHELIN's pages. If several of them land
100–500 m off, the cause may be the stored point, not the Google record.
MICHELIN's own coordinates for all 646 live restaurants are in
`michelin_fr_pages.csv`; join on `michelin_url`. Compare against those before
rejecting.

## Step 3 — output

Write the following to this folder:

- `placeid_results_fr.csv`, with columns
  `code,name,google_place_id,google_name,distance_m,record_type,business_status,certainty,notes`;
- `prepared_place_id_backfill_fr.sql`, which:
  - fills only `google_place_id is null`, and only from `confirmed` rows;
  - runs in one transaction;
  - aborts on an unknown code or on an ID already used in `restaurants`.
