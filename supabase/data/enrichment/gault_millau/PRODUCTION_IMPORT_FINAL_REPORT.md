# Gault&Millau — Schema Migration + Existing-Match Import — Final Report

Executed: 2026-08-11. **Status: DEPLOYED. Committed. Pushed to origin/main.**

---

**1. Migration state before application**

`supabase migration list` showed `20260811120000` (Gault&Millau schema) pending (`remote: ""`) while `20260811220000` (the catalogue architecture fix, applied in the prior task) was already applied — an out-of-order timestamp.

**2. Exact migration-history handling used**

A plain `supabase db push` correctly refused with `"Found local migration files to be inserted before the last migration on remote database"`, suggesting `--include-all`. Confirmed via `--dry-run --include-all` that this would push exactly and only `20260811120000` — nothing else swept in. `--include-all` is a normal push flag, not `migration repair`; no migration history was rewritten or manipulated. Applied with `supabase db push --include-all --yes`.

**3. Schema migration result**

Applied cleanly. `supabase migration list` afterward: all 12 local migrations show `local == remote`.

**4. Remote schema verification**

Via read-only `supabase db dump --linked --schema public`: both tables exist with every reviewed column, all 4 CHECK constraints (`recognition_type`, `score`, `toque_colour`, `toque_count`), `UNIQUE(restaurant_id, guide_year)` on `gault_millau_awards`, no uniqueness constraint on `gault_millau_special_awards` (confirmed absent, by design), both FKs (`gault_millau_awards.restaurant_id → restaurants(id) ON DELETE CASCADE`; `gault_millau_special_awards.restaurant_id → restaurants(id) ON DELETE SET NULL`; `gault_millau_special_awards.country_code → countries(country_code)`), all 4 indexes, RLS enabled on both tables with exactly one `SELECT`-only policy each for `anon`+`authenticated`, no write policy on either. `GRANT ALL` at the table level confirmed identical to the pre-existing `restaurants` table's own grants — standard Supabase default, RLS is the real enforcement layer.

**5. Pre-import table counts**

Both tables confirmed empty (`content-range: */0`) via anon-key REST query before any import.

**6. Production dry-run core totals**

**41 `INSERT`, 0 `SKIP_UNRESOLVED_CODE`, 0 `ALREADY_PRESENT_OR_CONFLICT`** — resolved against live production `restaurants`, zero writes (generated SQL grep-verified free of INSERT/UPDATE/DELETE).

**7. Production dry-run special totals**

**58 `INSERT`, 0 `SKIP_UNRESOLVED_COUNTRY`** — resolved against live production `countries`, zero writes.

**8. Core import inserted/updated/skipped totals**

**41 inserted, 0 updated, 0 skipped.**

**9. Core remote final count**

**41.**

**10. Core market breakdown**

AT 11, BE 9, CH 7, FR 1, NL 13 = 41. Germany: 0.

**11. Special import inserted/updated/skipped totals**

**58 inserted, 0 updated, 0 skipped.**

**12. Special remote final count**

**58.**

**13. Special market breakdown**

NL 18, BE 14, AT 12, CH 8, FR 6 = 58. Germany: 0.

**14. Germany exclusion confirmation**

Confirmed: 0 German rows in either table, verified via live query. All German research rows remain untouched in the enrichment CSVs — nothing deleted.

**15. gm_024 exclusion confirmation**

Confirmed: a live query for `gault_millau_awards` rows joined to `restaurant_code = 'rest_0085'` (the "212"/Amsterdam restaurant `gm_024` would have matched) returns 0 rows. `gm_024` remains classified `REVIEW`, structurally excluded from the loader's output.

**16. Confirmation ZERO restaurants were created**

Confirmed by construction (every core-award insert is `INSERT INTO gault_millau_awards ... SELECT r.id ... FROM restaurants r WHERE r.restaurant_code = '<code>'` — no `INSERT INTO restaurants` statement exists anywhere in either generated SQL file, grep-verified) and by count (774 before, during, and after every step).

**17. Restaurant row count before → after**

**774 → 774.** Unchanged.

**18. Michelin regression verification**

3-star sample query (ABAC, DiverXO) returns correctly, unaffected.

**19. World's 50 Best regression verification**

Rank #1 query (Maido) returns correctly, unaffected.

**20. Hall of Fame verification**

**Still exactly 6** (Disfrutar, El Celler de Can Roca, Eleven Madison Park, Geranium, Osteria Francescana, The French Laundry) — unaffected by this task, re-confirmed live.

**21. Idempotency verification**

A gap was found in the dry-run generator's special-awards path (it never cross-checked existing rows, unlike the core-awards path). Verified empirically instead: re-ran both exact `apply` SQL files a second time against production — a safe operation given the `WHERE NOT EXISTS` guard is provably idempotent by construction. Result: **41 and 58 unchanged after the second run** — 0 duplicates either table.

**22. Current Gault&Millau read-model recommendation**

Repository-level derivation (not a database view), mirroring `HotelWorlds50BestRepository`'s precedent: `left join gault_millau_awards g on g.restaurant_id = r.id and g.guide_year = (select max(guide_year) from gault_millau_awards where restaurant_id = r.id)`. No view built — none required yet, no UI consumer exists.

**23. Breakdown of the 23 deferred new candidates**

- **A. Likely missing Michelin restaurants (23):** `gm_001–007, 009–018, 036, 037, 039, 045, 056, 058` — needs Michelin catalogue reconciliation, a separate workstream.
- **B. Genuinely Gault&Millau-origin (1):** `gm_050` Martino — confirmed 2026 H!P of the Year winner, Belgium-only recognition.
- **C. Still needs identity review (6):** `gm_019, 030, 047, 049, 060, 085` — Michelin status genuinely uncertain either way, insufficient address/website data collected.

Full detail with names/cities in `PRODUCTION_IMPORT_REPORT.md`. None of the 30 caused, or will cause, a restaurant row from this task.

**24. Exact files committed**

21 files, commit `f12a8ff`: `apply_gault_millau_production.py` (new), `import_gault_millau.py`, `validate_gault_millau.py`, `CONTROL_REPORT.md`, `FINAL_REPORT.md`, `PRODUCTION_IMPORT_REPORT.md` (new), `PRODUCTION_READINESS_REVIEW.md`, `README.md`, `SCHEMA_DESIGN.md`, 4 `research_*.md` files, `proposed_catalogue_architecture_fix.sql`, 6 `gault_millau_*.csv` data files, and `supabase/migrations/20260811120000_create_gault_millau_awards.sql`.

**25. Exact files intentionally excluded**

`docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md` — a leftover untracked report from the prior (unrelated) catalogue-architecture-fix task, not a Gault&Millau data-foundation artifact; left out as out-of-scope for this commit, still sitting untracked afterward. No Flutter file, no Guides UI file, no other migration was ever staged.

**26. `flutter analyze` result**

`No issues found!`

**27. `flutter test` result + total test count**

**All tests passed. 331 total** — unchanged, confirming zero regression from this schema/data-only task. `git diff -- lib/` confirmed empty before staging.

**28. Commit hash**

`f12a8ff82ec740b112853b09258a12452dbb185c`

**29. Pushed branch**

`main` → `origin/main` (`a6abee1..f12a8ff main -> main`)

**30. Confirmation local `main` == `origin/main`**

`git rev-parse HEAD` and `git rev-parse origin/main` both return `f12a8ff82ec740b112853b09258a12452dbb185c` — identical.

**31. Final `git status`**

```
?? docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md
```

Only the one unrelated pre-existing untracked file remains (§25) — nothing left dirty from this task.

**32. Explicit confirmation: Gault&Millau UI was NOT implemented**

Confirmed. No file under `lib/` was created, modified, or staged. `GuidesScreen`, Michelin Guides, 50 Best Guides, Explore, Passport, and navigation are all untouched (`git diff -- lib/` empty throughout). This was a schema-and-data-import task only.

---

**STOP — as instructed.** No new restaurants were added. No new-restaurant candidates (23 or otherwise) were resolved or imported. Germany was not imported. `gm_024` was not resolved. Michelin catalogue reconciliation was not started. Gault&Millau Guides UI was not built. Bottom navigation was not changed.
