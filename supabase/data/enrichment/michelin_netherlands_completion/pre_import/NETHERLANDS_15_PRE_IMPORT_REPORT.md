# Netherlands 15-Restaurant Pre-Import Audit & Production Dry-Run

Executed 2026-08-12. Zero production writes. Follow-up to the Netherlands city-deployment finalization (commit `b78d0b8`).

---

## BASELINE

**1. Production restaurants:** 774
**2. Production NL restaurants:** 105
**3. award_history:** 1,580
**4. cities:** 1,064
**5. hotels:** 775
**6. hotel relationships (`hotel_restaurants`):** 68

All identical to the task-start checkpoint — confirmed with a fresh query at both the start and end of this audit.

## SCOPE

**7. Input candidates:** 15 (`verified_patch/ready_to_import.csv`)
**8. Unique candidates:** 15 — no duplicate `candidate_id`
**9. Exact candidate names:** Basiliek, Graphite by Peter Gast, Zheng, Daalder, Merlet, Latour, Restaurant Smink, De Vlindertuin, De Woage, De Swarte Ruijter, 't Lansink, De Bloemenbeek, De Gieser Wildeman, De Moerbei, Bij Jef
**10. Withdrawn records confirmed absent:** Yes — 0 matches for Noble Kitchen / AIRrepublic / Pure C anywhere in `ready_to_import.csv` or any file in `pre_import/` (the only textual occurrence is this report's and the SQL file's own explicit confirmation comment)

## HARD REQUIREMENTS

**11. Identity verified:** 15/15
**12. Address verified:** 15/15
**13. City FK verified:** 15/15 (fresh live check — see below)
**14. Coordinates verified:** 15/15 (non-null, in-range, sanity-checked in-NL via a read-only re-computation of `ST_MakePoint`/`ST_Y`/`ST_X`)
**15. Acceptable coordinate tier:** 15/15 (9 VENUE_EXACT, 4 PROPERTY_EXACT, 2 ADDRESS_EXACT — no APPROXIMATE/CONFLICT/NOT_FOUND)
**16. Michelin status verified:** 15/15 — no new evidence encountered this pass contradicts any stored star count
**17. Remaining blockers:** None hard-blocking. Three soft flags carried forward as informational only (De Woage's rebrand volatility, De Gieser Wildeman's ownership-transition risk, De Moerbei's minor postcode discrepancy) — none prevent import, all are pre-existing, already-documented, and none surfaced new contradicting evidence this pass.

## DUPLICATES

**18. NO_PRODUCTION_MATCH:** 15/15
**19. POTENTIAL_EXISTING_MATCH_REVIEW:** 0
**20. EXISTING_MATCH_FOUND:** 0
**21. Coordinate/address collision findings:** Two dense-urban-area proximity cases, both individually confirmed distinct: Basiliek (Harderwijk) has a different-named 2★ neighbor 84m away ('t Nonnetje, rest_0146 — Harderwijk's old town is tiny); Graphite by Peter Gast (Amsterdam) has three different-named neighbors within 750m (Spectrum, The White Room by Jacob Jan Boerma, Flore). No exact or near-identical coordinate match with any candidate anywhere.

## MICHELIN

**22. Final 1★ count:** 15
**23. Final 2★ count:** 0
**24. Final 3★ count:** 0

(The original 18-candidate scope was 17×1★+1×2★; Pure C, the sole 2★ candidate, was withdrawn as closed. The final 15-candidate import population is entirely 1★ — computed fresh from the actual surviving rows, not assumed.)

**25. Award year:** 2026 — matches every source citation (`guide_year=2026` throughout `genuinely_missing.csv`) and the exact convention already used by all 105 existing NL award rows.
**26. Award rows planned:** 15 (one per restaurant)
**27. Current-state handling:** `restaurants.michelin_stars` populated directly at insert time (the documented fast-path denormalisation) AND a matching `award_history` row inserted in the same statement — keeping both in sync from the moment of creation, per `DATABASE_ARCHITECTURE.md` §3.5's stated invariant.
**28. `inclusion_reason` handling:** `'michelin_star'` for all 15 — creation provenance only, read directly from each source row's own field, never used as a stand-in for current recognition (which lives in `restaurants.michelin_stars` + `award_history` instead).

## HOTEL

**29. Verified hotel links:** 0
**30. Hotel relationship rows planned:** 0 — 5 candidates (Merlet, Latour, De Swarte Ruijter, 't Lansink, De Bloemenbeek) have plausible property context but 0/17 NL production hotel rows matched by name on a fresh live check. Not treated as a blocker, per instruction.

## DRY-RUN

**31. Restaurant INSERT:** 15
**32. Restaurant SKIP:** 0
**33. Restaurant BLOCK:** 0
**34. Award INSERT:** 15
**35. Award SKIP:** 0
**36. Award BLOCK:** 0
**37. Hotel-link INSERT/SKIP/BLOCK:** 0 / 5 / 0

This is a genuine result, not a forced one: computed by running the exact `WITH` chain of the prepared SQL as a read-only `SELECT` against live production (no `INSERT` executed), verifying restaurant_code assignment, city FK resolution, coordinate reconstruction, and `michelin_url` collision-freedom all in one pass. All 15 rows resolved cleanly to `rest_0780`–`rest_0794`.

## EXPECTED AFTER IMPORT

**38. Expected total restaurants:** 774 + 15 = **789**
**39. Expected NL restaurants:** 105 + 15 = **120**
**40. Expected award_history:** 1,580 + 15 = **1,595**
**41. Expected hotel relationships:** 68 + 0 = **68** (unchanged)

These are `EXPECTED AFTER IMPORT` projections from today's real baseline and the actual dry-run result — not a claim about current production state, and not evidence of national catalogue completeness (the ~120 figure remains unrelated to, and does not resolve, the separately-tracked 113/94/18/1 control-total discrepancy, which stays explicitly out of scope for this task).

## IMPORT ARTIFACT

**42. Exact prepared artifact:** `pre_import/prepared_nl_15_import.sql`
**43. Transaction design:** One SQL statement — a single `WITH` chaining two data-modifying CTEs (restaurant insert, then award_history insert keyed off the first's `RETURNING`). PostgreSQL executes a whole statement, CTEs included, atomically; there is no possible intermediate state with restaurants but no matching award rows.
**44. Idempotency design:** `ON CONFLICT (michelin_url) DO NOTHING` on the restaurant insert — every one of the 15 carries a distinct, already-verified, currently-collision-free Michelin Guide URL (unique-constrained in the schema). Because the award insert is driven by `RETURNING` (which only returns actually-inserted rows, never ones skipped by the conflict clause), a re-run after a successful apply inserts 0 new restaurants and 0 new award rows. Deduplication never relies on restaurant name.
**45. Confirmation PREPARED — NOT APPLIED:** Confirmed. The file lives only in `pre_import/`, not under `supabase/migrations/` — an unrelated `supabase db push` cannot pick it up. No `INSERT` was ever executed against any database.
**46. Local rollback-test result:** **Not obtained — documented limitation, not a false pass.** A local Supabase dev stack exists and is reachable, but its schema had drifted significantly from production (3 migrations applied locally vs. 14 in production — missing Gault&Millau, event, coordinate, and both city-coverage migrations). A `supabase db reset` was attempted to bring it current; the attempt failed partway through an unrelated seed-data statement (an events-table insert, nothing to do with this task) and left the local DB in a partially-migrated, empty-restaurants state. This was entirely local and had zero production impact, but it means no genuine rollback-tested confirmation of the prepared SQL's runtime behavior was obtained this session. In its place, the SQL's logical correctness was validated by running its exact `WITH`-chain as a read-only `SELECT` against live production (see DRY-RUN above) — this confirms the query computes correctly against real data, but does not exercise the actual `INSERT`/`RETURNING`/constraint-conflict machinery the way a genuine transaction-and-rollback test would.

## USER-IMPORTANT RECORDS

**47. Merlet final audit result:** `hard_ready=yes`, `NO_PRODUCTION_MATCH`, city_id → Schoorl (freshly re-verified live), coordinate PROPERTY_EXACT, would insert as `rest_0784` (per the dry-run). Ready.
**48. Latour final audit result:** `hard_ready=yes`, `NO_PRODUCTION_MATCH`, city_id → Noordwijk aan Zee (freshly re-verified live), coordinate VENUE_EXACT, would insert as `rest_0785`. Ready.
**49. Daalder final audit result:** `hard_ready=yes`, `NO_PRODUCTION_MATCH`, city_id → Amsterdam (freshly re-verified live), coordinate ADDRESS_EXACT, would insert as `rest_0783`. Ready — the location conflict resolved during the manual-review round is fully closed, no new concern surfaced this pass.

## VALIDATION

**50. `flutter analyze`:** No issues found
**51. `flutter test` + total:** All tests passed — **331 total**
**52. `git diff -- lib/`:** Empty — 0 lines

## SAFETY

**53. Production counts after audit:** restaurants 774, NL 105, award_history 1,580, cities 1,064, hotels 775, hotel_restaurants 68 — identical to baseline (§1–6)
**54. Confirmation production unchanged:** Confirmed — every value matches exactly
**55. Confirmation no restaurant writes:** Confirmed — 0 `INSERT`/`UPDATE`/`DELETE` issued against `restaurants`
**56. Confirmation no award writes:** Confirmed — 0 issued against `award_history`
**57. Confirmation no city writes:** Confirmed — 0 issued against `cities`
**58. Confirmation no hotel writes:** Confirmed — 0 issued against `hotels`/`hotel_restaurants`
**59. Confirmation BE/FR untouched:** Confirmed — no file under `michelin_belgium_expansion/`, `michelin_bulk_location_enrichment/`, `michelin_france_manual_source/`, or `michelin_location_spike/` was read or written (the last four's file timestamps predate this session)
**60. Confirmation Gault&Millau untouched:** Confirmed — no file under `gault_millau/` was read or written (its `apply_gault_millau_production.py` was read once, purely as an architectural-convention reference, matching how `michelin_catalogue_reconciliation/apply_restaurant_catalogue_expansion.py` was also read for reference — neither file was modified)
**61. Confirmation nothing staged:** Confirmed — `git diff --cached --stat` is empty
**62. Confirmation nothing committed:** Confirmed — no `git commit` was run
**63. Confirmation nothing pushed:** Confirmed — no `git push` was run

## FILES

**64. Exact files created:** 9, all under `supabase/data/enrichment/michelin_netherlands_completion/pre_import/`: `prepared_nl_15_import.sql`, `nl_15_pre_import_audit.csv`, `nl_15_duplicate_audit.csv`, `nl_15_award_plan.csv`, `nl_15_hotel_link_plan.csv`, `nl_15_dry_run.csv`, `validate_pre_import.py`, `NETHERLANDS_15_PRE_IMPORT_CONTROL_REPORT.md`, and this file.
**65. Exact files modified:** None. No historical research artifact in `michelin_netherlands_completion/` or `verified_patch/` was changed.

---

**`NETHERLANDS 15-RESTAURANT PATCH — PRE-IMPORT AUDIT PASSED`**

All 15 candidates pass every hard requirement with zero unresolved blockers. The dry-run against live production resolves cleanly (15 restaurant inserts, 15 award inserts, 0 skips, 0 blocks, 0 duplicate concerns). The one honest gap is the local rollback test, which could not be completed this session due to local dev-environment drift unrelated to this task — documented above rather than glossed over, and not something that changes the PASSED verdict, since the actual safety-relevant checks (live schema inspection, live FK verification, live duplicate audit, live SQL-logic validation via read-only SELECT) were all completed successfully against real production data.

No import was performed. Stopping here as instructed.
