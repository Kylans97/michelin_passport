# Portugal: MICHELIN Key hotels 2026 (2026-11-01)

Status: **APPLIED 2026-11-01** (runbook `../APPLY_2026-11-01.md`, every check passed; 69 hotels, Keys 3/2/1 = 2/14/53, 65 Place IDs, 64 phones, 65 websites, as staged.) Originally prepared, not applied — Apply together with the Portugal stars
file, **in this order:**

1. `supabase/migrations/20261031160000_add_pt_2026_star_cities.sql` (24 towns)
2. `supabase/migrations/20261031170000_add_pt_key_hotel_cities.sql` (25 towns)
3. `prepared_pt_key_hotels_2026.sql`: 69 Key hotels
4. `../michelin_pt_stars/prepared_pt_stars_2026.sql`: 52 restaurants and the
   16 hotel links. It aborts if step 3 has not run.

## What it does

- **Hotels added:** MICHELIN's global Key article of 18 Sep 2026 gives
  "Portugal – 69 Key hotels". Production had none, so all 69 are added
  (`hotel_2810`–`hotel_2878`): 2 Three-Key, 14 Two-Key, 53 One-Key. Each gets
  a current 2026 `michelin_keys` row (announced 2026-09-18), the same shape
  as the IT/ES/DE/Benelux Key refresh.
- **Sources:** `/en/hotels-stays/portugal`, read with that refresh's own
  `fetch_michelin.py` (curl, 2.5 s pacing).
  - The listing has 225 cards; 69 are Portuguese Key cards. The Little Nell
    (Aspen) appears on every listing and is not counted (QA-389).
  - Each hotel's own page gives the JSON-LD award, which agrees with the
    card on all 69, plus the name (`h1`), address, pin and phone.
- **Also written**, unlike the earlier refresh, and fill-only:
  - **Place ID (65):** the hotel's own Google lodging record within 100 m.
  - **Phone (64):** MICHELIN and Google agree, or the number is on the
    official site.
  - **Website (65):** the confirmed record's link, checked one of two ways:
    - 49 load and name the hotel;
    - 16 sites block automated fetches, so for those the URL itself must
      carry the hotel's name.
- **Left blank:** four estates whose record is 140–232 m away (QA-399).
- **Towns:** the hotel page's locality, except that "Madeira" becomes
  Funchal and "Norte" becomes Vidago, both from the hotel's own street
  address, plus two restored diacritics. Notes are in `town_note`.
- **Restaurant links:** in the stars file, 16 starred restaurants link to
  these hotels (14 `exact`, 2 `campus`). The 4 in a non-Key hotel keep
  `property_name`.

## Evidence

- `pt_key_hotels_2026.csv`: per hotel.
- `_source/`: the listing and the 69 hotel pages as read.

## Tested

The test seeded a scratch PostgreSQL 16 + PostGIS database with the
Portugal export and applied all four steps in order:

- **Result:** 69 Key hotels at 2/14/53, each with exactly one current Key
  row equal to `michelin_keys`. Restaurants end at 0/9/44, with 16 links
  and 4 `property_name`, and none has both.
- **Re-runs:** both prepared files abort on a second run; the migrations
  are idempotent.
- **Wrong order:** running the stars file before the hotels file aborts
  with nothing applied.

It was not run against the real database.
