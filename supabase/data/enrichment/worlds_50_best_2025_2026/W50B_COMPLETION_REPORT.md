# World's 50 Best — catalogue completion and phone numbers (2026-10-28)

Status: **PREPARED — NOTHING APPLIED.** Everything here waits on review.

## Why

1. Every World's 50 Best list (restaurants and hotels) should be complete,
   1–100, in the catalogue. On 2026-10-28 production held 73/100 restaurants
   (2025), 96/100 hotels (2025) and 81/100 hotels (2026).
2. User feedback: every ranked venue should carry a phone number.

## Decisions (user, 2026-10-28)

| Question | Decision |
|---|---|
| Unstarred restaurants ranked 51–100 | In scope. `inclusion_reason = 'worlds_50_best'`. |
| Ranked hotels without a MICHELIN Key | Accepted (Carlton Cannes, Wynn Palace). CLAUDE.md hotel-scope rule updated. |
| Capella Hanoi / Waldorf Astoria Osaka Keys | Recommended and adopted: NULL until each hotel's own MICHELIN page resolves (QA-195). |
| Singita Kruger (Sweni + Lebombo) | One row, at Lebombo, 2 Keys (QA-196). |
| Scope of the rankings check | Current editions only: restaurants 2025, hotels 2025 and 2026. |

## 1. Rankings check — production vs official lists

Every production row matched the official ranking; nothing was wrong. Details
and sources: `RANKINGS_VERIFICATION_20261028.md`. Official captures are in
`_source/`.

## 2. Missing venues — what gets added

All 50 missing venues had already been staged in September
(`../worlds_50_best_new_venues/`, address + coordinates + Place ID) but never
loaded. This pass completed them (`restaurants_completion.csv`,
`hotels_completion.csv`): stars/Keys from each venue's own MICHELIN page only,
MICHELIN URL, official website, phone, open status.

- **26 restaurants** (2025, 51–100). 14 starred (Tuju 3, Evvai 3, Fu He Hui 2,
  The Clove Club 2, ten at 1), 12 unstarred.
- **22 hotels** (19 new on the 2026 list, plus the 4 held back in August;
  One&Only Mandarina is on both lists). 18 with Keys, 4 NULL.
- **Held back: Meet the Bund** (2025 #94) — staged location is a different
  restaurant (QA-194). After the import, restaurants 2025 is 99/100.
- No collision with production (codes, Place IDs, MICHELIN URLs) — checked
  2026-10-28. Highest codes then: `rest_1368`, `hotel_781`.

## 3. Phone numbers — existing ranked venues

178 venues researched (`phones_all.csv`, source URL per row): 152 confirmed,
7 unclear, 19 not found. Imported: the 151 confirmed numbers (69 restaurants,
82 hotels) that ring in the venue's own country; Rosewood Mayakoba's only
number is a US toll-free line and is left out, like Montage Los Cabos. Not
found is mostly hotel groups whose sites block automated access (QA-201).

## Files and apply order

| # | File | What |
|---|---|---|
| 1 | `supabase/migrations/20261016120000_add_worlds_50_best_countries_and_cities.sql` | 3 countries (EC, PA, VN), 16 cities |
| 2 | `supabase/migrations/20261016130000_add_hotel_phone.sql` | `hotels.phone` + `hotels_full.phone` |
| 3 | `prepared_w50b_new_venues_import.sql` (this folder) | 26 restaurants, 22 hotels, 49 ranking rows, 32 award_history rows |
| 4 | `prepared_w50b_phone_backfill.sql` (this folder) | 151 phone numbers, fills empty values only |
| 5 | App build with `lib/` changes | Hotel model `phone`, `hotelFullColumns`, Call action on hotel detail |

1–2 go out with `supabase db push --linked`; 3–4 are run explicitly
(`supabase db query --linked --file ...`). Step 5 must not ship before step 2
is applied: its explicit column list selects `hotels_full.phone`.

## What was tested, and what wasn't

- **Tested:** files 1–4 against a scratch PostgreSQL 16 + PostGIS database
  rebuilt from the repo migrations and seeded to production's reported state
  (code maxima, ranking counts, current award rows). Both migrations applied
  and re-ran cleanly; the import reached 99/100/100 and its post-checks passed;
  a re-run of the import aborts at its first guard; the phone file updated the
  expected rows.
- **Not tested:** against the real Supabase stack, or the real production data
  (only its counts and maxima were mirrored). The Flutter change is not
  compiled or run here — no Flutter SDK in this environment.
  `test/live_view_full_columns_test.dart` will fail until migration 2 is
  applied, by design.
- The import picks the hotel Key `guide_year` from the existing current Key
  rows, and aborts unless they share a single year. Restaurants use 2026,
  which is the year each MICHELIN page shows; the import aborts if no current
  2026 star rows exist.
