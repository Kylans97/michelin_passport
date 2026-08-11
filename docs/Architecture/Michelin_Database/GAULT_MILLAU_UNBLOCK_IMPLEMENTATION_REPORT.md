# Catalogue Architecture Fix — Implementation Report

Implemented: 2026-08-11. **Status: IMPLEMENTED LOCALLY, NOT APPLIED REMOTELY. Not committed. Not pushed.**

Companion to `GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md`, which this implements.

---

**1. Exact current dependencies on `inclusion_reason` found**

Re-confirmed identical to the architecture review's §2 audit (re-verified by re-reading the live view definition and re-running the grep sweep, not assumed from memory): one Flutter model field (`Restaurant.inclusionReason`), one previously-derived getter (`Restaurant.isHallOfFame`, now a stored field), one repository filter clause (`RestaurantRepository.search()`'s `hallOfFameOnly` branch), one import-time write expression (`scripts/import_catalogue.py:678`, unchanged — out of scope, still correctly never produces `'hall_of_fame'`, see finding in report §11 below), 8 test fixtures using it as required-field boilerplate only. No index, no trigger, no other view, no RLS policy depends on the column. Nothing found that contradicts the review's conclusion — implemented as reviewed, no redesign.

**2. Migration created**

`supabase/migrations/20260811220000_gault_millau_provenance_and_hall_of_fame_fix.sql` — a proper, timestamped, production-shaped migration (not the enrichment-folder sketch, which stays as a design artifact only). Two sections: (1) widen `inclusion_reason`'s CHECK constraint to add `gault_millau`; (2) `create or replace view public.restaurants_full` adding `is_hall_of_fame`, derived from `worlds_50_best.list_type = 'hall_of_fame'`. Header marked **PREPARED — NOT APPLIED**.

**3. Final CHECK values**

`michelin_star`, `worlds_50_best`, `hall_of_fame`, `bib_gourmand`, `gault_millau` — the 4 existing values preserved exactly, `gault_millau` added. `chasing_stars_editorial` deliberately **not** added, per the review's explicit deferral (no editorial feature exists yet). Verified live via a rolled-back local transaction: `information_schema.check_constraints` shows exactly this 5-value list post-migration, and the original 4-value list again post-rollback.

**4. `restaurants_full` change**

One additive column, `is_hall_of_fame`, computed as `exists (select 1 from public.worlds_50_best hof where hof.restaurant_id = r.id and hof.list_type = 'hall_of_fame')` — the same derivation pattern already used for `worlds_50_best_rank` two lines above it in the same view. Every existing column preserved verbatim (confirmed by diffing the column list before/after: all 27 prior columns present, `is_hall_of_fame` and nothing else added — `latitude`/`longitude` from the prior coordinates migration also confirmed present). `security_invoker = true` preserved unchanged. No grant statements needed changing — `restaurants_full` inherits `restaurants`' own RLS-governed read access (`DATABASE_ARCHITECTURE.md` §15.2), and this migration neither adds nor removes a policy.

**5. Restaurant model change**

`lib/models/restaurant.dart`: `isHallOfFame` changed from a derived getter (`inclusionReason == 'hall_of_fame'`) to a real `final bool isHallOfFame` field, populated in `fromJson` from `json['is_hall_of_fame']` (defaulting `false` if absent, matching the existing `isInHotel` pattern). `inclusionReason` is **unchanged and still present** — its doc comment was extended to explicitly state it is creation-provenance-only and must never be read for current recognition, and to note that `inclusionReason == 'michelin_star'` with `isHallOfFame == true` simultaneously is the correct, expected real-world state (documented directly in code, not just in the architecture doc). The constructor's `isHallOfFame` parameter defaults to `false`, so no existing call site (8 test fixtures, none of which touch Hall of Fame) needed updating.

**6. Restaurant query/column changes**

`lib/data/repositories/restaurant_repository.dart`: `restaurantFullColumns` (the single shared constant every restaurant-reading repository imports — confirmed via grep: `restaurant_worlds_50_best_repository.dart`, `planned_trips_repository.dart`, `events_repository.dart`, `hotel_repository.dart`, `wishlist_repository.dart`, `visited_repository.dart` all reuse it, none define a separate column list) gained `is_hall_of_fame`. One shared constant, one edit — no N+1, exactly as instructed. **A deployment-ordering hazard was found and explicitly documented in-code**, mirroring the file's own existing warning for `latitude`/`longitude`: requesting `is_hall_of_fame` before migration `20260811220000` lands on whatever schema this code targets will throw PostgREST 42703 and break every catalogue screen (Explore, Passport, Rankings, Detail, Wishlist, Visits/Stays) — flagged with a new comment block directly above the constant, not silently left implicit.

**7. Explore Hall of Fame filter change**

`RestaurantRepository.search()`'s `hallOfFameOnly` branch changed from `builder.eq('inclusion_reason', 'hall_of_fame')` to `builder.eq('is_hall_of_fame', true)` — server-side, one line, no change to `explore_screen.dart` or `explore_filters.dart` (their own `isHallOfFame` is an unrelated enum getter on `RestaurantAwardFilter`, confirmed by inspection, not touched). No visual design, other filter, search semantics, or World's 50 Best ranking behavior changed — confirmed by diff: exactly one line changed in this method beyond the added comment.

**8. Other Hall of Fame presentation usages corrected**

Exactly one: `RestaurantAwardsCard` (`lib/features/restaurants/widgets/restaurant_awards_card.dart:27`) reads `restaurant.isHallOfFame` — **required no change**, since the getter name and calling convention are unchanged; only what backs it changed (a stored field instead of a derived expression). Full-repo grep after the change confirms zero remaining references to `inclusion_reason`/`hall_of_fame` as a filter predicate anywhere in `lib/` (the one remaining string match is the explanatory code comment itself, not a predicate).

**9. Validation result for the six real Hall of Fame restaurants**

Confirmed via a rolled-back local transaction against the actual migration file (not a re-typed approximation): Disfrutar, El Celler de Can Roca, Eleven Madison Park, Geranium, Osteria Francescana, The French Laundry all resolve `is_hall_of_fame = true`; **exactly 6** rows total resolve `true` catalogue-wide (`select count(*) from restaurants_full where is_hall_of_fame` → 6). The authoritative table matched the review's expected set exactly — no discrepancy found, so no STOP was needed per the task's own instruction for that case.

**10. Local proof that `gault_millau` provenance can be inserted**

Confirmed, rolled back: inside the same test transaction, `insert into restaurants (..., inclusion_reason, ...) values (..., 'gault_millau', ...)` with `michelin_stars = null` succeeded and returned the inserted row with `inclusion_reason = 'gault_millau'`, `michelin_stars = null` — i.e. a restaurant genuinely representable as Gault&Millau-only, implying nothing about Michelin or World's 50 Best recognition. A second insert attempt with an arbitrary invalid value (`'not_a_real_value'`) was correctly rejected by the CHECK constraint. Nothing from this test insert was committed — rolled back along with the rest of the transaction, and re-confirmed absent afterward (`restaurant_code like 'rest_test%'` → 0 rows).

**11. Existing-value backward compatibility**

Confirmed: `inclusion_reason` distribution queried immediately after the migration was applied (pre-rollback) showed `{michelin_star: 767, worlds_50_best: 7}` — byte-identical to the pre-migration distribution. No row's stored value was touched; the migration only widens what a *future* `INSERT` may write. **Incidental finding, not fixed here (explicitly out of this task's scope per its own §15/§9):** `scripts/import_catalogue.py`'s `insert_restaurants()` still can only ever write `'michelin_star'` or `'worlds_50_best'` — it will never write `'gault_millau'` either, meaning any future initial-catalogue-load pass would still need that script updated separately before it could actually import Gault&Millau-provenance rows at scale. `import_gault_millau.py` (the Gault&Millau-specific importer) is unaffected — it never writes `inclusion_reason` at all, by design.

**12. Hotel comparison finding**

Re-confirmed unchanged from the architecture review: `hotels` has **no `inclusion_reason` column at all** (confirmed via `information_schema.columns` — this task did not add one, and the review explicitly recommended against ever adding one). No equivalent live bug exists on the hotel side: `worlds_50_best_hotels.list_type` has no `hall_of_fame` value to begin with (that table only has `top_50`/`extended_51_100`), so there is no hotel-side "recognition value that can never actually be written" failure mode to fix. No hotel architecture was modified, per instruction.

**13. Database tests/dry-run result**

All items from the task's checklist verified in one combined rolled-back transaction against local Postgres (`127.0.0.1:54322`):

| Check | Result |
|---|---|
| Migration succeeds | ✅ applied cleanly |
| Existing `inclusion_reason` values remain valid | ✅ `{michelin_star: 767, worlds_50_best: 7}`, unchanged |
| `gault_millau` accepted | ✅ insert succeeded |
| Invalid arbitrary value rejected | ✅ `CheckViolation` raised |
| `restaurants_full` retains every required field | ✅ all 27 prior columns + `is_hall_of_fame` + `latitude`/`longitude` present |
| `is_hall_of_fame` exists | ✅ |
| Hall of Fame derivation correct | ✅ exactly the 6 expected restaurants, no more, no less |
| `security_invoker` preserved | ✅ `['security_invoker=true']` |
| No unrelated schema loss | ✅ column-by-column diff confirmed |
| Rollback leaves local DB unchanged | ✅ re-queried post-rollback: original 4-value CHECK, no `is_hall_of_fame` column, 0 leftover test rows, 774 restaurants |

**14. `flutter analyze` result**

Clean after one fix: the new test file's null-conditional map-entry pattern (`if (isHallOfFame != null) 'is_hall_of_fame': isHallOfFame,`) triggered a `use_null_aware_elements` info-level lint, corrected to `'is_hall_of_fame': ?isHallOfFame,`. Final run: **`No issues found!`**

**15. `flutter test` result + total test count**

**All tests passed. 331 total** (0-indexed `+330`), including the 7 new tests in `test/restaurant_hall_of_fame_test.dart` (individually re-run to confirm: `+0` through `+6`, `All tests passed!`). No existing test broken.

**16. Exact files changed/added**

Modified (2):
- `lib/models/restaurant.dart`
- `lib/data/repositories/restaurant_repository.dart`

Added (3, this task):
- `supabase/migrations/20260811220000_gault_millau_provenance_and_hall_of_fame_fix.sql`
- `test/restaurant_hall_of_fame_test.dart`
- `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_IMPLEMENTATION_REPORT.md` (this file)

Pre-existing, untouched by this task (confirmed via `git status` — same untracked state as before this task started):
- `docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md`
- `supabase/data/enrichment/gault_millau/` (entire folder — read-only, nothing inside written or staged; `git add .`/`git add -A` never used, only untouched pre-existing untracked state)
- `supabase/migrations/20260811120000_create_gault_millau_awards.sql`

**17. Confirmation: Gault&Millau award data was NOT imported**

Confirmed. `import_gault_millau.py` was not run in this task. No row was inserted into `gault_millau_awards` or `gault_millau_special_awards`. The 41 core rows, 58 special awards, 23 READY_TO_ADD candidates, Germany's deferred rows, and `gm_024`'s REVIEW status are all untouched and exactly as the prior Gault&Millau production-readiness review left them.

**18. Confirmation: NOTHING was applied remotely**

Confirmed. Every database interaction in this task connected only to the local development Postgres instance (`127.0.0.1:54322`); the migration was applied inside a transaction and immediately rolled back, re-verified via fresh queries afterward to confirm the local DB matches its exact pre-task state (original 4-value CHECK, no `is_hall_of_fame` column, 0 leftover rows, 774 restaurants). No `supabase db push` was run. No remote or production connection string was used anywhere in this task. `git status` shows the changes listed in §16 as modified/untracked only — **nothing was staged with `git add .`/`git add -A`, nothing was committed, nothing was pushed.**

**STOP — as instructed. Awaiting explicit further instruction before any remote application, commit, or push.**
