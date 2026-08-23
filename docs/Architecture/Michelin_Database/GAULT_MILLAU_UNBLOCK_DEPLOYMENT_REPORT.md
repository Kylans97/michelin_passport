# Catalogue Architecture Fix — Remote Apply + Commit + Push Report

Executed: 2026-08-11. **Status: DEPLOYED to remote. Committed. Pushed to origin/main.**

Companion to `GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md` (design) and `GAULT_MILLAU_UNBLOCK_IMPLEMENTATION_REPORT.md` (local implementation), which this deploys.

> **Later update (added during repository evidence cleanup — original
> report below is unmodified):** this report is a point-in-time record
> of the catalogue-architecture-fix deploy only. At the time it was
> written, the Gault&Millau awards migration (`20260811120000`) was
> deliberately left unapplied (§3/§18/§19 below), and every "not
> applied"/"was not imported" statement in this file was accurate as of
> that moment. That migration and the Gault&Millau award data import
> were subsequently applied later the same day, in a separate task — see
> `supabase/data/enrichment/gault_millau/PRODUCTION_IMPORT_FINAL_REPORT.md`
> for that final, current state (41 core awards + 58 special awards,
> live in production). Nothing below this note was altered.

---

**1. Migration state before apply**

`supabase migration list` showed both `20260811120000` (Gault&Millau awards) and `20260811220000` (architecture fix) with `remote: ""` — both pending. `supabase db push --dry-run` confirmed it would push **both**, in timestamp order, exactly the risk flagged in the task brief.

**2. Exact method used to apply ONLY the architecture migration**

Temporarily moved `supabase/migrations/20260811120000_create_gault_millau_awards.sql` out of the migrations directory into the session scratchpad (`mv`, not `rm` — file content untouched) so `supabase db push` would see only one pending migration. Re-ran `--dry-run` to confirm exactly `20260811220000` was the only migration listed, then ran `supabase db push --yes`. Restored the moved file to its original path and name **immediately** after the apply completed (successful) — confirmed via `supabase migration list` re-run afterward: `20260811120000` still `remote: ""`, unaffected throughout.

**A real bug was caught mid-deployment, not proactively.** The first apply attempt failed: `ERROR: cannot change name of view column "latitude" to "is_hall_of_fame" (SQLSTATE 42P16)`. Root cause: `CREATE OR REPLACE VIEW` can only ever *append* new output columns — inserting `is_hall_of_fame` between `worlds_50_best_rank` and `latitude` shifted every later column's position, which PostgreSQL reads as an attempted rename of `latitude`. This was invisible in every prior local test because the local dev database's `restaurants_full` had never actually received the `latitude`/`longitude` migration (`20260807140000`) — a genuine, pre-existing drift between the local dev mirror and the real remote schema, discovered only by this failed real deploy. The failed statement rolled back atomically (confirmed via `migration list` showing `20260811220000` still unapplied, and a live REST query confirming `is_hall_of_fame` did not exist and the CHECK constraint was untouched) — no partial state was left on remote. Fixed by moving `is_hall_of_fame` to the very end of the `SELECT` list, after `longitude`; re-verified locally by first replaying the *true* remote-matching baseline (28 original columns + `latitude`/`longitude`, established fresh inside the same test transaction) and only then applying the fix on top — this time a clean append, `is_hall_of_fame` landing at column 31. Re-attempted the real remote push with the corrected migration; it applied cleanly on the first try.

**3. Confirmation: Gault&Millau awards migration was NOT applied**

Confirmed, both during the temporary move (it was never on disk in the migrations directory at push time) and after (`supabase migration list` shows `{"local":"20260811120000","remote":""}` in the final, post-push listing below).

**4. Final remote `inclusion_reason` CHECK values**

Verified via a **read-only** `supabase db dump --linked --schema public` (no writes, no inserts):

```sql
CONSTRAINT "inclusion_reason_valid" CHECK (("inclusion_reason" = ANY (ARRAY[
  'michelin_star'::"text", 'worlds_50_best'::"text", 'hall_of_fame'::"text",
  'bib_gourmand'::"text", 'gault_millau'::"text"])))
```

Exactly the 5 expected values — 4 preserved, `gault_millau` added.

**5. `restaurants_full` remote verification**

Via the same schema dump: all prior columns present in their original order (`id` through `worlds_50_best_rank`, then `latitude`, `longitude`), `is_hall_of_fame` appended last (column 31), `WITH ("security_invoker"='true')` preserved unchanged, the view's `COMMENT ON VIEW` matches what the migration set. Every join (`cities`, `countries`, `hotel_restaurants`, `hotels`, `worlds_50_best`) preserved verbatim. Nothing dropped, nothing renamed.

**6. Remote Hall of Fame row count**

Queried live via the anon-key REST endpoint (the same access level the app uses): `content-range: 0-0/6` — **exactly 6 rows**.

**7. Exact Hall of Fame restaurants returned**

Disfrutar (`rest_0331`), El Celler de Can Roca (`rest_0337`), Eleven Madison Park (`rest_0045`), Geranium (`rest_0473`), Osteria Francescana (`rest_0078`), The French Laundry (`rest_0735`) — matches the architecture review's expected set exactly. No discrepancy; no STOP was needed.

**8. Confirmation: ordinary restaurant catalogue queries still work**

Verified live, anon-key REST, read-only: a 3-star Michelin filter (`michelin_stars=eq.3`) returned real rows (ABAC, DiverXO, Le Bernardin, ...); a World's 50 Best rank query (`worlds_50_best_rank=not.is.null`, ordered) returned Maido at #1, Asador Etxebarri at #2, Quintonil at #3 — correct. Total `restaurants_full` row count unchanged: `content-range: 0-0/774`.

**9. Confirmation: Explore Hall of Fame filtering now uses authoritative data**

`RestaurantRepository.search()`'s `hallOfFameOnly` branch reads `builder.eq('is_hall_of_fame', true)` (committed in `a6abee1`). The read-only remote query run for point 6 above (`is_hall_of_fame=eq.true`) is the exact REST-level equivalent of that filter, and it returned the correct 6 rows against live data — the filter is proven correct end-to-end, not just at the source-code level.

**10. Confirmation: `gault_millau` provenance is structurally allowed**

Confirmed via the read-only schema dump (point 4) — `'gault_millau'::"text"` is a member of the live `inclusion_reason_valid` CHECK constraint on the real remote table. No row was inserted to prove this; schema inspection alone is sufficient and was preferred per the task's own instruction.

**11. `flutter analyze` result**

`No issues found!`

**12. `flutter test` result + total test count**

**All tests passed. 331 total** — matches the expected pre-apply baseline exactly, confirming this deployment introduced no regression.

**13. Exact files committed**

```
A  docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md
A  docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_IMPLEMENTATION_REPORT.md
M  lib/data/repositories/restaurant_repository.dart
M  lib/models/restaurant.dart
A  supabase/migrations/20260811220000_gault_millau_provenance_and_hall_of_fame_fix.sql
A  test/restaurant_hall_of_fame_test.dart
```

6 files, 768 insertions, 7 deletions. Staged individually via 6 separate `git add <path>` calls — `git add .`/`git add -A` never used.

**14. Exact parallel-workstream files excluded**

`supabase/data/enrichment/gault_millau/` (entire folder, untracked, untouched) and `supabase/migrations/20260811120000_create_gault_millau_awards.sql` (untracked, unapplied remotely, content never modified — only its filesystem location changed transiently and was restored). Verified via explicit grep checks against the staged diff before committing (all passed) and via `git status --short` after push (both still show as the only two remaining untracked paths).

**15. Commit hash**

`a6abee182e5150be54dace543900686ed99c88e8`

**16. Pushed branch**

`main` → `origin/main` (`579ca9b..a6abee1 main -> main`)

**17. Confirmation local `main` == `origin/main`**

`git rev-parse HEAD` and `git rev-parse origin/main` both return `a6abee182e5150be54dace543900686ed99c88e8` — identical.

**18. Remote migration status**

Post-push `supabase migration list`: `20260811220000` now shows `{"local":"20260811220000","remote":"20260811220000"}` — applied. `20260811120000` still shows `{"local":"20260811120000","remote":""}` — unapplied, exactly as required.

**19. Final `git status`**

```
?? supabase/data/enrichment/gault_millau/
?? supabase/migrations/20260811120000_create_gault_millau_awards.sql
```

The working tree is expected to remain non-clean — the separate Gault&Millau enrichment workstream and its awards migration are untouched and uncommitted, exactly as instructed. Nothing was deleted or staged merely to make `git status` clean.

---

**STOP — as instructed.** The Gault&Millau awards migration was not applied. Gault&Millau award data was not imported. No new restaurants were added. Guides Gault&Millau UI work was not started.
