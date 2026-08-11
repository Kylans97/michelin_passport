# Gault&Millau — Data Foundation

**Status: RESEARCH + DATASET PREPARATION, REVIEWED FOR PRODUCTION READINESS. Nothing in this folder has been applied to any production or remote database.** See `PRODUCTION_READINESS_REVIEW.md` for the full 18-point checkpoint report — it supersedes the original `FINAL_REPORT.md`'s numbers (some match classifications changed during review; see below).

This is an isolated, parallel data workstream preparing Gault&Millau as a candidate fifth Chasing Stars Guide source, alongside Michelin and World's 50 Best (Restaurants/Hotels). It does not touch, depend on, or get depended on by any Flutter/`lib/` UI code, including the in-progress Guides UI workstream.

## Folder contents

**Research** (source-cited findings, retrieval date 2026-08-11):
- `research_france.md` — France's system, incl. the unscored "Toques d'Or" top tier.
- `research_netherlands_belgium.md` — NL/BE, incl. Belgium's unscored "H!P" casual category and the NL score→toque discrepancy (unresolved, flagged).
- `research_dach.md` — Switzerland/Germany/Austria, incl. Germany's 2022 abolition of numeric scoring and current (2026) inaccessibility, and Austria's editorial independence from Germany.
- `research_global_survey.md` — 20+ market survey, special-awards taxonomy across markets, and historical/annual-edition mechanics.

**Datasets** (CSV, one row per fact, every row carries `source_url` / `retrieval_date`):
- `gault_millau_restaurants.csv` — 87 rows collected across FR/BE/NL/CH/DE/AT, 2025–2026 editions.
- `gault_millau_matches.csv` — each of the 87 rows classified against the existing Chasing Stars catalogue. **Post-review: EXACT 52 / HIGH_CONFIDENCE 4 / REVIEW 1 / NO_MATCH 30** (originally 46/11/0/30 — the 2026-08-11 production-readiness review promoted 6 HIGH_CONFIDENCE matches to EXACT on address/website corroboration and downgraded 1, `gm_024`, to REVIEW after finding a genuine address conflict — see `PRODUCTION_READINESS_REVIEW.md` §4 for the full reasoning on each).
- `gault_millau_new_restaurant_candidates.csv` — the 30 NO_MATCH rows in full detail. **Not inserted anywhere.**
- `gault_millau_new_restaurant_review.csv` — **new**, added during the production-readiness review: each of the 30 candidates classified READY_TO_ADD (23) / NEEDS_REVIEW (3) / DO_NOT_ADD (4) by identity-data completeness, plus a `likely_already_michelin_starred` flag — most READY_TO_ADD candidates are widely-recognized Michelin-starred restaurants that are simply absent from the current 774-row catalogue mirror, which is a separate, more consequential finding than data completeness (see §6 of the review).
- `gault_millau_special_awards.csv` — 63 editorial awards (Chef of the Year and similar) across the same markets/years.
- `gault_millau_sources.csv` — the 20 source domains used, with access status (`gaultmillau.de` is marked `INACCESSIBLE (SSL error)`).

**Design & schema:**
- `SCHEMA_DESIGN.md` — the reasoning behind every table/column/constraint choice, grounded in specific research findings.
- `../../migrations/20260811120000_create_gault_millau_awards.sql` — the proposed migration (two tables: `gault_millau_awards`, `gault_millau_special_awards`). Header marked **PREPARED — NOT APPLIED**. **Updated during review to add Row Level Security** (public-read, no client write — the original draft omitted RLS entirely, a real gap against `DATABASE_ARCHITECTURE.md` §15.2). Syntax- and RLS-verified via a rolled-back local transaction only. Deliberately does **not** touch `restaurants.inclusion_reason` — see the architectural gap noted below.

**Tooling** (self-contained; no dependency on `scripts/` or vice versa):
- `import_gault_millau.py` — dry-run-by-default import/upsert script. Idempotent, transactional, INSERT-only, structurally incapable of targeting anything but a local database. **Updated during review** to exclude Germany by default (`DEFERRED_COUNTRY_CODES = {"DE"}`, override with `--include-deferred-markets`). Tested end-to-end against a local dev instance twice (before and after the review's changes) — applied, verified, re-applied to confirm idempotency, tested with and without the Germany filter, then the test tables were dropped each time to leave that database exactly as found. **Not** left running against, or connected to, production.
- `validate_gault_millau.py` — read-only control-report generator; no database connection. Produces `CONTROL_REPORT.md`. Updated during review for the REVIEW-tier reclassification and to add a per-market breakdown.
- `CONTROL_REPORT.md` — 15/15 checks passed, 0 issues (regenerated post-review).
- `PRODUCTION_READINESS_REVIEW.md` — the review's 18-point checkpoint report. **The most important finding: `restaurants.inclusion_reason` has a closed 4-value CHECK constraint (`michelin_star`/`worlds_50_best`/`hall_of_fame`/`bib_gourmand`) with no Gault&Millau-only value — no new restaurant can be inserted from this workstream today without either violating that constraint or misusing an existing value. This blocks all 23 READY_TO_ADD candidates until a separate, explicitly-reviewed migration widens that constraint. Only the 41 matched-restaurant award rows (against already-existing catalogue rows, launch markets only) are actually production-ready.**

## Explicit boundaries (per the task brief)

- **Not modified, referenced for read-only matching context only:** `supabase/data/restaurants_master.csv`, the production `restaurants` table (read-only queries against a local dev mirror, for verification purposes only).
- **Never copied:** long-form Gault&Millau descriptions or editorial reviews — only structured factual metadata.
- **Never derived:** toque counts from scores, or vice versa.
- **Never fabricated:** every missing value is `null` or an explicit `"not found"`-style placeholder with a stated reason.

## If this workstream is promoted later

1. Resolve the architectural gap: a small, separately-reviewed migration widening `restaurants.inclusion_reason`'s CHECK constraint to permit a Gault&Millau-only reason (see `PRODUCTION_READINESS_REVIEW.md` §6). Do this before inserting any of the 23 READY_TO_ADD candidates. **Full architecture review, options considered, and a verified (not applied) SQL sketch now live at `docs/Architecture/Michelin_Database/GAULT_MILLAU_CATALOGUE_ARCHITECTURE_REVIEW.md` and `proposed_catalogue_architecture_fix.sql`** — that review also found and diagnosed (but did not fix) a live, unrelated bug: `inclusion_reason` is never actually set to `'hall_of_fame'` by the import path, so the Hall of Fame badge/filter are currently non-functional for all 6 real Hall of Fame restaurants.
2. For each READY_TO_ADD candidate, verify current Michelin status against production first — most are very likely already Michelin-starred restaurants missing from the catalogue for unrelated reasons, in which case they belong in the existing Michelin catalogue-expansion process, not here.
3. Resolve `gm_024` (Restaurant 212, Amsterdam) manually — a genuine address conflict between sources, flagged REVIEW, not EXACT/HIGH_CONFIDENCE.
4. Apply the migration (with RLS) to a real target.
5. Run `import_gault_millau.py` against launch markets first (Germany excluded by default); re-evaluate Germany separately once its guide situation resolves.
6. Resolve the two flagged open questions: the NL score→toque discrepancy, and Germany's guide status.
7. Decide how to resolve `gault_millau_special_awards.restaurant_id` (currently always `NULL` on import — deliberately not attempted here, see `import_gault_millau.py`'s module docstring).
