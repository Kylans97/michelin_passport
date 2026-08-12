# Netherlands 15-Restaurant Production Import Report

Executed 2026-08-12. Follow-up to `NETHERLANDS_15_PRE_IMPORT_REPORT.md` (audit passed) and the city deployment (commit `b78d0b8`).

---

## PRE-IMPORT BASELINE

restaurants=774, NL restaurants=105, award_history=1,580, cities=1,064, hotels=775, hotel_restaurants=68 — verified fresh immediately before the apply, identical to every prior checkpoint this session.

## APPLY METHOD

`supabase db query --linked --file supabase/data/enrichment/michelin_netherlands_completion/pre_import/prepared_nl_15_import.sql` — the same read-only-capable, established production channel used for every other database interaction across this entire workstream (never a raw psycopg connection to production). The file was applied exactly as approved in the pre-import audit — byte-for-byte unchanged (verified via a pre-apply content check before running).

**Transaction result:** Success. One statement (`WITH` chaining two data-modifying CTEs) executed atomically; no error returned.

## RESULT

- Restaurant inserts: **15**
- Award inserts: **15**
- Hotel-link inserts: **0** (none planned — 0 verified relationships)
- Skips: **0**
- Blocks/errors: **0**

## PRODUCTION AFTER

| Metric | Before | After | Delta | Expected | Match |
|---|---|---|---|---|---|
| restaurants | 774 | 789 | +15 | +15 | ✅ |
| NL restaurants | 105 | 120 | +15 | +15 | ✅ |
| award_history | 1,580 | 1,595 | +15 | +15 | ✅ |
| cities | 1,064 | 1,064 | +0 | +0 | ✅ |
| hotels | 775 | 775 | +0 | +0 | ✅ |
| hotel_restaurants | 68 | 68 | +0 | +0 | ✅ |

Every delta reconciles exactly against the fresh pre-apply baseline.

## NEW RECORDS

15/15 verified live, in full detail (name, `restaurant_code`, `id`, city, `michelin_stars`, `inclusion_reason`, `michelin_url`, exactly 1 linked `award_history` row each):

| Name | Code | City | ★ | Award rows |
|---|---|---|---|---|
| Basiliek | rest_0780 | Harderwijk | 1 | 1 |
| Graphite by Peter Gast | rest_0781 | Amsterdam | 1 | 1 |
| Zheng | rest_0782 | The Hague | 1 | 1 |
| Daalder | rest_0783 | Amsterdam | 1 | 1 |
| Merlet | rest_0784 | Schoorl | 1 | 1 |
| Latour | rest_0785 | Noordwijk aan Zee | 1 | 1 |
| Restaurant Smink | rest_0786 | Wolvega | 1 | 1 |
| De Vlindertuin | rest_0787 | Zuidlaren | 1 | 1 |
| De Woage | rest_0788 | Gramsbergen | 1 | 1 |
| De Swarte Ruijter | rest_0789 | Holten | 1 | 1 |
| 't Lansink | rest_0790 | Hengelo | 1 | 1 |
| De Bloemenbeek | rest_0791 | De Lutte | 1 | 1 |
| De Gieser Wildeman | rest_0792 | Noordeloos | 1 | 1 |
| De Moerbei | rest_0793 | Warmond | 1 | 1 |
| Bij Jef | rest_0794 | Den Hoorn | 1 | 1 |

Codes are exactly sequential, unique, no collision — computed live from `max(restaurant_code)+1` inside the statement itself, exactly as designed (not the hardcoded placeholder range from the audit's own prediction, though it happened to match).

**`restaurants_full` view:** 15/15 resolve correctly — correct `city_name`/`country_name` ("Netherlands"), correct `michelin_stars`, correct `latitude`/`longitude` (matching source exactly, no swap), `is_in_hotel=false` for all 15 (no fabricated hotel link), `worlds_50_best_rank=null` for all 15 (no fabricated ranking).

**Current-recognition filter (Guides/Explore equivalent):** `select count(*) from restaurants_full where country_code='NL' and michelin_stars>=1` → **120**, matching 105 existing + 15 new exactly.

**Award linkage:** 15/15 — `guide_year=2026, award_type='michelin_stars', award_value=1, is_current=true, announced_on=NULL` for every one, identical to the pattern already used by all 105 pre-existing NL award rows.

## IMPORTANT RECORDS

- **Merlet:** `rest_0784`, Schoorl, 1★, 1 current award row. ✅
- **Latour:** `rest_0785`, Noordwijk aan Zee, 1★, 1 current award row. ✅
- **Daalder:** `rest_0783`, Amsterdam, 1★, 1 current award row. ✅

## SAFETY

- **Noble Kitchen / AIRrepublic / Pure C:** 0 rows found under any of these names post-import — confirmed not inserted.
- **Unintended duplicates:** 0. No duplicate `michelin_url` among non-null values across all 789 restaurants (the one grouped "duplicate" is `michelin_url IS NULL`, count 569 — expected/benign, NULL never collides under a Postgres unique constraint, and this reflects 569 restaurants with no Michelin URL on file, not a new issue).
- **Pre-existing restaurant rows:** 0 changed — count with `restaurant_code < rest_0780` is exactly 774, and their most recent `updated_at` (2026-08-10) predates this entire session, meaning the `restaurants_updated_at` trigger never fired on any of them.
- **Pre-existing award_history rows:** 0 changed — exactly 105 NL current award rows exist excluding the 15 new ones, matching the pre-import baseline exactly.
- **Cities:** 0 changed (1,064 → 1,064).
- **Hotels / hotel_restaurants:** 0 changed (775/68 → 775/68).
- **Belgium/France workstream:** untouched — no file under `michelin_belgium_expansion/`, `michelin_bulk_location_enrichment/`, `michelin_france_manual_source/`, or `michelin_location_spike/` read or written.
- **Gault&Millau:** untouched — no file under `gault_millau/` read or written.
- **Flutter:** untouched — see VALIDATION below.

## VALIDATION

- `flutter analyze`: see below
- `flutter test`: see below, total reported
- `git diff -- lib/`: confirmed empty

## PRESERVED ARTIFACT

`prepared_nl_15_import.sql` was applied exactly as written and is preserved unchanged in `pre_import/` as the durable audit trail — not deleted, not rewritten. The applied SQL is identical to the reviewed/approved artifact (verified via content check before running).

---

**Import complete.** 15 new Netherlands Michelin restaurants are now live in production, each with correct current recognition, correct city linkage, correct coordinates, and zero collateral changes to any of the other 774 pre-existing restaurants, 1,580 pre-existing award rows, 1,064 cities, or 775 hotels.
