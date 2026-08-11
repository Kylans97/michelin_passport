# Gault&Millau Data Foundation — Review Checkpoint Report

Retrieval date: 2026-08-11. Status: **RESEARCH + DATASET PREPARATION ONLY — nothing applied to production.** This is the stop-before-application checkpoint requested by the task brief.

---

**1. Gault&Millau markets researched**
France, Belgium, Netherlands, Switzerland, Germany, Austria (all 6 markets named in the brief), plus a broader 20+-market survey (`research_global_survey.md`) covering Italy, Portugal-adjacent and other European/international editions at a lighter depth to identify future expansion candidates. UK, Spain, Portugal, and the Nordics were explicitly searched for and **not found** as live Gault&Millau markets.

**2. Exact scoring/toque systems per market**
All 6 core markets use a 0–20 half-point scale with a 5-toque ("Hauben"/"Toques") ceiling, **except**:
- **Germany** abolished numeric scoring entirely in 2022 — toques only, with a unique **red vs. black** colour distinction at the same toque count (5-red ≠ 5-black).
- **France** additionally has an unscored top tier, "Toques d'Or" (Gault&Millau Academy), for restaurants deliberately removed from numeric scoring.
- **Belgium** additionally runs "H!P," a structurally separate, permanently unscored casual-dining selection (250+ addresses, own URL namespace).
A consistent score→toque mapping (10–10.5=0 … 19–19.5=5) is officially published on the France/international and Austria sites; it is **not** independently confirmed as separately republished on the NL or BE domains, and NL's own 2022 news post describes a materially different boundary — left as an explicit unresolved discrepancy, never silently resolved.

**3. Recommended initial Chasing Stars scope**
- **Launch (A):** France, Belgium, Netherlands, Switzerland, Austria — all 5 have live, reachable, current (2026) editions with usable data.
- **Defer (B), do not launch with:** Germany — its guide has **no 2026 edition**, the site is down (SSL error), and there is an unresolved publisher/licensing dispute with no successor named. Its post-2022 no-score system is also structurally incompatible with the other 5 markets' data shape, so even a resumed German edition would need separate handling. The 15 German rows collected here are a secondary-sourced snapshot of the stale 2025 edition, marked `confidence: medium/low` throughout, retained for completeness but not recommended for launch inclusion until the site is live again.
- **Future expansion:** the ~15 additional markets found live in `research_global_survey.md` Part A, not yet collected at restaurant-row depth.

**4. Number of Gault&Millau restaurant records collected**
**87** rows in `gault_millau_restaurants.csv` — FR 19, BE 16, NL 15, DE 15, AT 12, CH 10 — spanning the 2025 (Germany, last live edition) and 2026 (all others) guide years.

**5. Existing catalogue match counts by tier**
Of 87: **EXACT 46, HIGH_CONFIDENCE 11, REVIEW 0, NO_MATCH 30.** (57 of 87 = 66% already exist in the Chasing Stars catalogue under some name/city form.)

**6. Number of genuinely new restaurant candidates**
**30**, in `gault_millau_new_restaurant_candidates.csv` — includes every France Toques d'Or restaurant (5) and the one Belgium H!P sample (1), since neither of those non-standard recognition types happened to already be in the catalogue.

**7. Historical years available**
Only **2025** (Germany, last live edition before its outage) and **2026** (all other markets) were collected. No official structured historical archive was found on any of the 6 markets' live sites — past scores are only reconstructable via individually dated news articles or third-party press, never a browsable archive. This makes the proposed `gault_millau_awards` annual-snapshot table (never overwritten, one row per restaurant per guide_year) **more complete than Gault&Millau's own websites** for the specific question "how has this restaurant's score changed over time," once populated year over year going forward.

**8. Special awards found**
**63** rows in `gault_millau_special_awards.csv` across all 6 markets — Chef of the Year, Pastry Chef, Sommelier, Young Chef/Talent/Discovery (inconsistently named per market), Restaurant Manager/Host, Lifetime Achievement, plus market-specific categories (NL's Vegetable Restaurant of the Year, BE's regional Young Chef ×3, AT's Wine/Beer/Wirtshaus awards). Award-category naming is confirmed **not standardized** across national organizations — modeled as an open vocabulary, not a fixed enum.

**9. Proposed normalized database model**
Two new tables, full reasoning in `SCHEMA_DESIGN.md`:
- `gault_millau_awards` — core recognition, one row per `(restaurant_id, guide_year)`, mirrors `worlds_50_best`'s annual-snapshot shape. `score` and `toque_count` independently nullable; `toque_colour` for Germany's red/black distinction; `recognition_type` (`scored` / `unscored_top_tier` / `unscored_casual`) distinguishes France's Toques d'Or and Belgium's H!P from ordinary scored rows without losing the fact that a row has no score.
- `gault_millau_special_awards` — editorial awards, deliberately separate table, `restaurant_id` nullable (`ON DELETE SET NULL`), no uniqueness constraint (confirmed necessary: Switzerland and Belgium both have real multi-winner categories in a single year).

**10. Migration drafted**
Yes — `supabase/migrations/20260811120000_create_gault_millau_awards.sql`, header marked **"PREPARED — NOT APPLIED."** Verified via a rolled-back local transaction only (column lists confirmed, then rolled back) at design time, and separately re-applied to a local dev database, exercised end-to-end via the import script, then **dropped again** to leave that database exactly as found (see point 15). **Never applied to, or connected to, any remote/production database.**

**11. Import/upsert approach**
`import_gault_millau.py` — self-contained (no dependency on `scripts/`), dry-run by default, transactional, INSERT-only (never UPDATE/DELETE), idempotent (verified: a second `--apply` run produced 0 new inserts, 57+63 `ALREADY_PRESENT`). Only imports `gault_millau_awards` rows for candidates classified EXACT/HIGH_CONFIDENCE (57 of 87) — REVIEW/NO_MATCH rows are structurally unable to produce a row, no fuzzy fallback exists. Special-award rows are imported with `restaurant_id = NULL` always, since award-winner names were never run through the matching pipeline and the task explicitly forbids resolving identity from a weak match. **Has no `--target remote` option in the file at all** — the only reachable target is a local database.

**12. Data-quality issues found**
See `CONTROL_REPORT.md` — **15/15 automated checks passed, 0 issues** (no duplicate rows, all scores/toques in valid range, all guide_years plausible, no suspiciously reused profile URLs, every EXACT/HIGH_CONFIDENCE match's restaurant_code resolves against the catalogue, full provenance on every row). Two **unresolved discrepancies are flagged in the research docs themselves** (not "issues" in the automated sense, but open questions for a human reviewer): the NL score→toque boundary mismatch, and Germany's indefinite guide outage.

**13. Files created**
All under `supabase/data/enrichment/gault_millau/` (13 files) plus 1 migration:
`research_france.md`, `research_netherlands_belgium.md`, `research_dach.md`, `research_global_survey.md`, `gault_millau_restaurants.csv`, `gault_millau_matches.csv`, `gault_millau_new_restaurant_candidates.csv`, `gault_millau_special_awards.csv`, `gault_millau_sources.csv`, `SCHEMA_DESIGN.md`, `import_gault_millau.py`, `validate_gault_millau.py`, `CONTROL_REPORT.md`, `README.md`, this `FINAL_REPORT.md`; plus `supabase/migrations/20260811120000_create_gault_millau_awards.sql`.

**14. Sources used**
20, catalogued in `gault_millau_sources.csv` with domain, market scope, content used, retrieval date, and access status — includes the explicit `gaultmillau.de: INACCESSIBLE (SSL error)` entry.

**15. Explicit confirmation — nothing was applied to production**
Confirmed. `git status` shows only new, untracked files: everything under `supabase/data/enrichment/gault_millau/` and the one new migration file — **no existing file was modified, no Guides/UI/Flutter file was touched, nothing was committed, nothing was pushed.** The migration was applied only to a local development Postgres instance (`127.0.0.1:54322`, never a remote host) for verification purposes, and the two tables it created were **dropped again** immediately after testing — that local database has been restored to its exact original state (confirmed by re-querying `information_schema.tables`). No remote or production Supabase connection was ever made at any point in this workstream.
