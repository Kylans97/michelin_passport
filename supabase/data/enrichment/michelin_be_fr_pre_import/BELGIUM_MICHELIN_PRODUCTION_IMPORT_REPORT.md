# Belgium Michelin Production Import Report

Executed 2026-08-12. Follow-up to `BE_FR_PRE_IMPORT_REPORT.md` (audit passed) and the Netherlands import (commit `97de674`). **France was not touched — its prepared artifact remains applied-nowhere.**

---

## PREFLIGHT

- Git: `HEAD == origin/main == 97de674be62e7871983c3309f8a32eb4b715951b`, confirmed before any write.
- Fresh production baseline (immediately pre-apply): restaurants 789, BE 20, FR 6, NL 120, award_history 1,595, cities 1,064, hotels 775, hotel_restaurants 68 — identical to every prior checkpoint.
- 100/100 Belgium candidates re-verified fresh: 0 bad city FKs, 0 name collisions, 0 URL collisions, 0 coordinate collisions, 100 unique candidate identities.
- Star composition re-verified: 96×1★ + 4×2★ = 100.
- Hotel link re-verified: Fine Fleur (`be_010`) → Botanic Sanctuary Antwerp confirmed live (`hotel_18`), with 1 pre-existing unrelated link at that hotel (Hertog Jan at Botanic, `rest_0159`) — additive, not conflicting.
- Award preflight: `guide_year=2026`, `award_type='michelin_stars'`, `is_current=true` — matches the exact convention of all 20 pre-existing BE current award rows.

## A BUG WAS FOUND, FIXED, AND VALIDATED BEFORE COMMITTING ANYTHING

The first apply attempt failed with: `ERROR: 42703: column "seq" does not exist` — the prepared SQL's `RETURNING id, seq, michelin_stars` clause tried to return a column (`seq`) that only exists on the `proposed` CTE, not on `public.restaurants` (Postgres `RETURNING` can only return real target-table columns). This was a genuine defect in the SQL, not caught by the earlier pre-import audit's read-only SELECT-emulation dry-run (which validated the *decision logic* but never actually executed the real `INSERT...RETURNING` statement).

**Immediately after the error:** production was re-queried and confirmed completely unchanged (restaurants 789, BE 20, award_history 1,595, hotel_restaurants 68, 0 rows with the new code range) — the single-statement failure rolled back atomically and fully, exactly as expected. No partial writes, no manual repair needed.

**Fix:** restructured the SQL to compute `restaurant_code` in its own plain (non-modifying) `coded` CTE, `RETURN`ed `id, restaurant_code, michelin_stars` (all real `restaurants` columns) from the insert, and re-joined `coded` on `restaurant_code` for the hotel-link step instead of the invalid `seq` join. Applied identically to both `prepared_be_michelin_import.sql` and `prepared_fr_michelin_import.sql` (France's file was corrected too, since it shares the same defect, but remains **unapplied** — this task never touched France).

**Before retrying the real apply**, the fixed SQL was validated with a genuine `BEGIN; <exact SQL>; SELECT <counts>; ROLLBACK;` transaction against live production — confirming 100 restaurants / 100 awards / 1 hotel link would be created, correct code range `rest_0795`–`rest_0894`, then confirming production was back to exactly its pre-test state after the rollback. Only then was the real, uncommitted apply attempted again.

## APPLY

- **Method:** `supabase db query --linked --file prepared_be_michelin_import.sql` — same channel as the Netherlands import.
- **Transaction result:** Success, no error, atomic (one `WITH` statement chaining 3 data-modifying CTEs: restaurants → award_history → hotel_restaurants).
- Restaurant inserts: **100**. Award inserts: **100**. Hotel-link inserts: **1**. Skips: **0**. Blocks/errors: **0** (on the corrected, retried attempt).

## PRODUCTION AFTER

| Metric | Before | After | Delta | Expected |
|---|---|---|---|---|
| restaurants | 789 | 889 | +100 | +100 ✅ |
| BE restaurants | 20 | 120 | +100 | +100 ✅ |
| FR restaurants | 6 | 6 | +0 | +0 ✅ |
| NL restaurants | 120 | 120 | +0 | +0 ✅ |
| award_history | 1,595 | 1,695 | +100 | +100 ✅ |
| cities | 1,064 | 1,064 | +0 | +0 ✅ |
| hotels | 775 | 775 | +0 | +0 ✅ |
| hotel_restaurants | 68 | 69 | +1 | +1 ✅ |

## NEW BELGIUM DATA

- **100/100 restaurant verification:** unique codes `rest_0795`–`rest_0894`, 0 bad `inclusion_reason`, 0 bad `country_code`.
- **96×1★ / 4×2★ / 0×3★ verified** directly against the inserted rows.
- **100/100 award linkage:** every one of the 100 has exactly 1 current `michelin_stars` award row.
- **100/100 `restaurants_full` verification:** all 100 resolve correctly; guide-filter equivalent (`country_code='BE' and michelin_stars>=1`) returns exactly 100 within this code range.

## HOTEL

- Fine Fleur (`rest_0797`) → Botanic Sanctuary Antwerp, `link_confidence='exact'` — verified live.
- Exactly 1 new hotel_restaurants row created; no other unintended links.

## DUPLICATE SAFETY

- 0 duplicate `michelin_url` values among non-null values across all 889 restaurants.
- Known collision fixtures re-verified post-import: La Paix (BE `rest_0836` / JP `rest_0709`), Sense (BE `rest_0810` / NL `rest_0098`) — both correctly remain two separate rows, not merged.

## REGRESSION

- Pre-existing restaurants: exactly 789 with `restaurant_code < rest_0795` — unchanged (774 original + 15 Netherlands, both from earlier in this session).
- France (6), Netherlands (120), cities (1,064), hotels (775) — all unchanged.
- Gault&Millau: untouched (no file read or written).
- No pre-existing restaurant or award row was modified — confirmed via exact-delta reconciliation above.

## PRESERVED ARTIFACT

`prepared_be_michelin_import.sql` — applied successfully after the fix described above. Preserved as the durable audit trail. `prepared_fr_michelin_import.sql` was corrected for the same defect but **remains unapplied** — France import was never attempted in this task.

---

**Belgium import complete.** 100 new Belgian Michelin restaurants are now live in production with correct current recognition, correct city linkage, correct coordinates, and exactly one verified hotel relationship — with zero collateral changes to France, Netherlands, or any of the 774 originally-existing restaurants.
