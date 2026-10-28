# Google Place ID backfill — handoff (written 2026-10-28)

**For a new session.** The session that wrote this had no Google Places API
access. The user has since added a Places API key to the environment, and a
new session picks it up. Expected variable name: `GOOGLE_PLACES_API_KEY`;
ask the user if it is named differently. Never print the key or commit it.

## Goal

Fill `google_place_id` where it is missing for:

1. the 13 NL starred restaurants added by the Netherlands import (Basiliek,
   Graphite by Peter Gast, Daalder, Merlet, Latour, Restaurant Smink,
   De Vlindertuin, De Swarte Ruijter, 't Lansink, De Bloemenbeek,
   De Gieser Wildeman, De Moerbei, Bij Jef);
2. every World's 50 Best ranked hotel with no Place ID (about 75; 71 of the
   96 ranked 2025 hotels had none on 2026-10-28);
3. hotel_801 Singita – Kruger National Park, from
   `../worlds_50_best_2025_2026/prepared_w50b_new_venues_import.sql`. It
   needs the **Singita Lebombo** record, not Sweni's.

The user asked for "missing Place IDs where needed". If the export below shows
other gaps, confirm the scope with the user before widening it.

## Step 1 — get the queue from production (the user runs this)

The SQL Editor returns at most 100 rows, so run it with `offset 0`, then
`offset 100`, and so on, until a page comes back short.

```sql
select 'restaurant' as type, restaurant_code as code, name, city_name, country_code,
       latitude, longitude, address, website_url, status
from restaurants_full
where google_place_id is null and status <> 'permanently_closed'
  and (country_code = 'NL' or worlds_50_best_rank is not null)
union all
select 'hotel', h.hotel_code, h.name, h.city_name, h.country_code,
       h.latitude, h.longitude, h.address, h.website_url, h.status
from hotels_full h
where h.google_place_id is null and h.status <> 'permanently_closed'
  and exists (select 1 from worlds_50_best_hotels w
               where w.hotel_id = h.id and w.year >= 2025)
order by 1, 2
limit 100 offset 0;
```

## Step 2 — method

Follow the `find-place-id` skill's rules exactly. The coordinates are the
evidence:

- Use the Places API (New) `places:searchText` with name + city, plus
  `locationBias` around the known coordinates. Field mask:
  `places.id,places.displayName,places.location,places.types,places.formattedAddress,places.businessStatus`.
- Compute the distance to the known coordinates:
  - **under 100 m** with the right name and type: `confirmed`;
  - **100–500 m**: `unclear`;
  - **over 500 m**: reject.
- **Hotels:** the record must have type `lodging`. Google often ranks the
  hotel's restaurant or spa first.
- **Restaurants:** the record must be the restaurant, not its hotel.
- **Mainland China:** skip and mark blocked. Google's coverage there is
  unreliable.
- A candidate ID already used by another row is `unclear`. Ten hotel/restaurant
  pairs share an ID deliberately.
- Note `businessStatus` (CLOSED_PERMANENTLY / CLOSED_TEMPORARILY) as a
  finding.

## Step 3 — output

Write the following to this folder:

- `placeid_results.csv`, one row per queued venue, with columns
  `code,type,name,google_place_id,google_name,distance_m,record_type,business_status,certainty,notes`;
- `prepared_place_id_backfill.sql`, which fills only `google_place_id is null`
  and sets only `confirmed` rows, in one transaction. It aborts on an unknown
  code or on an ID already used in the same table (Place IDs are UNIQUE per
  table).

Nothing is applied to production; the user reviews and runs the file. Commit
and push to the session's feature branch.

## Context

- The phone backfills already prepared are in `../worlds_50_best_2025_2026/`
  and `../michelin_nl_phones/`. They are independent of this work.
- QA log: `supabase/data/qa_issues.csv`, QA-194 to QA-208.
