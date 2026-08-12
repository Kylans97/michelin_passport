# Belgium/France Michelin Expansion — Final Pre-Import Audit & Production Dry-Run

Executed 2026-08-12. Zero production writes. Reads from the completed `michelin_bulk_location_enrichment/` workstream (untouched), writes only to this isolated `michelin_be_fr_pre_import/` folder.

---

## SCOPE

**1. READY input total:** 573
**2. Belgium input:** 100
**3. France input:** 473
**4. Unique candidate count:** 573 — 0 duplicate `candidate_id`
**5. Non-ready exclusion count:** 59 (39 LOCATION_REVIEW, 1 IDENTITY_REVIEW, 1 ADDRESS_REVIEW, 18 LOCATION_NOT_FOUND) — 0 overlap with the 573; manifest reconciles exactly (573+59=632, matching `scope_manifest.csv`'s own 632 rows with 0 unaccounted).

## HARD REQUIREMENTS

**6. Identity verified:** 573/573 (`identity_status=IDENTITY_VERIFIED`)
**7. Address verified:** 573/573 (`address_status=ADDRESS_VERIFIED`)
**8. City FK verified:** 573/573 — re-verified fresh, live, this session (0 bad city_id, 0 country mismatches)
**9. Coordinates verified:** 573/573 non-null, in-range, zero geographic bbox outliers
**10. Evidence complete:** 557/573 have a direct `source_evidence.csv` row; 16/573 carry evidence inline (documented, not fabricated)
**11. Evidence review count:** 16 — individually audited this session, **16/16 PASS** (see `evidence_audit.csv`)

## DUPLICATES

**12. NO_PRODUCTION_MATCH:** 573/573
**13. EXISTING_MATCH_FOUND:** 0
**14. POTENTIAL/REVIEW:** 0
**15. Cross-candidate duplicate result:** 0 duplicate name+city+country combos across all 573; 2 exact-coordinate pairs, both legitimate same-building distinct restaurants (already documented by the parent workstream)
**16. Coordinate-proximity findings:** 2 candidates (fr_0118 Hakuba, fr_0122 Le Tout-Paris) within 40m of an *existing* production restaurant (rest_0304 Plénitude) — explained: all three are distinct, differently-named restaurants inside the Cheval Blanc Paris building, not duplicates
**17. Known collision-fixture results:** La Paix (be_006), Sense (be_034), EST (be_076) all re-verified this session as correctly retained, distinct from their unrelated same-named counterparts in Tokyo/Netherlands — see `duplicate_audit.csv`

## RECOGNITION

**18. Belgium final 1★/2★/3★:** 96 / 4 / 0 (unchanged from manifest — 0 corrections needed)
**19. France final 1★/2★/3★:** 397 / 58 / 18 (recomputed after 4 corrections)
**20. Combined final 1★/2★/3★:** 493 / 62 / 18 = 573
**21. Exact six discrepancy outcomes:**
  - `fr_0306` La Marine: 1★→**3★** (CORRECTED)
  - `fr_0404` La Table des Amis: 1★→**2★** (CORRECTED)
  - `fr_0420` Restaurant Alexandre: 1★→**2★** (CORRECTED)
  - `fr_0460` La Villa Archange: not in scope (already excluded via `LOCATION_REVIEW`, independent of its star question)
  - `fr_0518` Relais de la Poste: **1★ confirmed correct** — no change (the flagged "discrepancy" was itself a stale secondary source; the restaurant recently lost its 2nd star)
  - `fr_0521` Le Hittau: 3★→**1★** (CORRECTED — the largest single correction)
**22. Belgium award year:** 2026 (verified live as the exact convention already used by all 20 existing BE current award rows)
**23. France award year:** 2026 (verified live as the exact convention already used by all 6 existing FR current award rows)
**24. Recognition blockers:** 0

## APPROVED POPULATION

**25. Belgium APPROVED_FOR_IMPORT:** 100
**26. Belgium EXISTING_MATCH_FOUND:** 0
**27. Belgium PRE_IMPORT_REVIEW:** 0
**28. France APPROVED_FOR_IMPORT:** 473
**29. France EXISTING_MATCH_FOUND:** 0
**30. France PRE_IMPORT_REVIEW:** 0
**31. Combined approved total:** 573

## AWARDS

**32. Belgium award rows planned:** 100
**33. France award rows planned:** 473
**34. Award skips:** 0
**35. Award blockers:** 0

## HOTEL LINKS

**36. Belgium links planned:** 1
**37. France links planned:** 5
**38. Exact relationships:** `be_010` Fine Fleur → Botanic Sanctuary Antwerp; `fr_0078` Épicure → Le Bristol Paris; `fr_0084` Jean Imbert au Plaza Athénée → Plaza Athénée; `fr_0118` Hakuba → Cheval Blanc Paris; `fr_0122` Le Tout-Paris → Cheval Blanc Paris; `fr_0468` Louroc → Hôtel du Cap-Eden-Roc. All 4 distinct hotels independently confirmed live in `production.hotels` this session (not guessed). Hakuba/Le Tout-Paris use `link_confidence='campus'` since Cheval Blanc Paris hosts multiple distinct restaurants, not a single dedicated venue.

## DRY-RUN BELGIUM

**39. Restaurant INSERT/SKIP/BLOCK:** 100 / 0 / 0
**40. Award INSERT/SKIP/BLOCK:** 100 / 0 / 0
**41. Hotel link INSERT/SKIP/BLOCK:** 1 / 99 / 0

## DRY-RUN FRANCE

**42. Restaurant INSERT/SKIP/BLOCK:** 473 / 0 / 0
**43. Award INSERT/SKIP/BLOCK:** 473 / 0 / 0
**44. Hotel link INSERT/SKIP/BLOCK:** 5 / 468 / 0

Both dry-runs are genuine results: each prepared SQL's exact `WITH`-chain logic (restaurant_code sequencing, dedup `WHERE` clause, `ON CONFLICT` behavior) was re-implemented as a read-only `SELECT` and run against live production. No `INSERT` was ever executed. The France query (473 candidates) completed in 1.68s — no timeout risk at this scale.

## SIMULATED COUNTS

**45. Fresh production baseline** (re-verified at the start and end of this audit, identical both times): restaurants 789, BE 20, FR 6, NL 120, award_history 1,595, cities 1,064, hotels 775, hotel_restaurants 68.

**46. `SIMULATED — NOT ACTUAL PRODUCTION` — expected after Belgium only:** restaurants 889, BE restaurants 120, award_history 1,695, hotel_restaurants 69.
**47. `SIMULATED — NOT ACTUAL PRODUCTION` — expected after France only:** restaurants 1,262, FR restaurants 479, award_history 2,068, hotel_restaurants 73.
**48. `SIMULATED — NOT ACTUAL PRODUCTION` — expected after both:** restaurants 1,362, BE restaurants 120, FR restaurants 479, award_history 2,168, hotel_restaurants 74. Cities remain 1,064 in every scenario (no new cities required — the BE/FR city-coverage migration already covered this).

These are computed from today's real baseline, not the historical 774/632-era figures. They say nothing about whether the national BE or FR catalogues are now complete — that question remains explicitly out of scope.

## IMPORT ARCHITECTURE

**49. Belgium prepared artifact:** `prepared_be_michelin_import.sql`
**50. France prepared artifact:** `prepared_fr_michelin_import.sql`
**51. Transaction design:** Each file is one atomic SQL statement — a `WITH` chain of 2–3 data-modifying CTEs (restaurants → award_history → hotel_restaurants where applicable). Fully country-separable: Belgium can be applied without France and vice versa; neither file references the other.
**52. Restaurant-code strategy:** Computed live inside each statement via `max(restaurant_code)+row_number()`, exactly matching the successfully-applied Netherlands precedent (commit `97de674`) and the project's own documented rule. Not hardcoded. Note: because both files were dry-run-validated independently against today's identical baseline, their reported code ranges overlap (both start from `rest_0795`) — this is expected and correct; whichever file is actually applied first will correctly shift the other's live-computed range at real apply-time, since both recompute `max()` fresh.
**53. Duplicate protection:** Two-tier. 553/573 candidates carry a real, unique Michelin Guide URL, protected via `ON CONFLICT (michelin_url) DO NOTHING`. The remaining 20 (7 BE + 13 FR — an evidence-format gap distinct from, and larger than, the 16-row inline-evidence gap: these specific rows were verified via the earlier `michelin_location_spike` methodology, which never captured a clean URL field) are additionally protected via a `NOT EXISTS` guard on `(country_code, lower(name), city_id)` in the `WHERE` clause, since a `NULL` `michelin_url` can never collide with another `NULL` under the schema's unique constraint alone.
**54. Idempotency:** A full re-run after a successful apply inserts 0 new restaurants (URL-bearing rows blocked by `ON CONFLICT`; no-URL rows blocked by the name+city guard) and consequently 0 new award or hotel-link rows (both driven by `RETURNING` on the restaurant insert, which only returns actually-inserted rows).
**55. Scale/batching recommendation:** **No batching required.** Evidence: (a) this exact codebase already successfully applied a comparable-scale single-statement insert (the 397-row BE/FR city-coverage migration, `20260812100000_expand_michelin_city_coverage.sql`); (b) the 473-row France file is 125KB, far under any practical Postgres statement-size limit; (c) the read-only dry-run of the full 473-row logic completed in 1.68s against live production, showing no timeout risk. If a future real apply attempt ever does time out via the Supabase CLI, the safe fallback is splitting each country's single statement into deterministic sequential chunks (e.g., by `seq` range) — not parallelizing, which would reintroduce race conditions in the live `max(restaurant_code)` computation.
**56. Confirmation PREPARED — NOT APPLIED:** Confirmed for both files. Neither lives under `supabase/migrations/`; `supabase db push` cannot pick them up. No `INSERT` was ever executed against any database.

## VALIDATION

**57. `flutter analyze`:** No issues found
**58. `flutter test` + total:** All tests passed — **331 total**
**59. `git diff -- lib/`:** Empty

## SAFETY

**60. Production end counts:** restaurants 789, BE 20, FR 6, NL 120, award_history 1,595, cities 1,064, hotels 775, hotel_restaurants 68 — re-verified fresh at task end
**61. Production unchanged:** Confirmed — every value identical to the pre-audit baseline (§45)
**62. No restaurant writes:** Confirmed — 0 `INSERT`/`UPDATE`/`DELETE` against `restaurants`
**63. No award writes:** Confirmed — 0 against `award_history`
**64. No city writes:** Confirmed — 0 against `cities`
**65. No hotel writes:** Confirmed — 0 against `hotels`/`hotel_restaurants`
**66. Netherlands untouched:** Confirmed — no file under `michelin_netherlands_completion/` read or written; NL count (120) unchanged throughout
**67. Gault&Millau untouched:** Confirmed — no file under `gault_millau/` read or written
**68. Nothing staged:** Confirmed — `git diff --cached --stat` is empty
**69. Nothing committed:** Confirmed — no `git commit` was run
**70. Nothing pushed:** Confirmed — no `git push` was run

## FILES

**71. Exact files created:** 16, all under `supabase/data/enrichment/michelin_be_fr_pre_import/`: `be_fr_pre_import_master.csv`, `be_pre_import_approved.csv`, `fr_pre_import_approved.csv`, `pre_import_review.csv`, `duplicate_audit.csv`, `evidence_audit.csv`, `recognition_discrepancy_audit.csv`, `hotel_link_plan.csv`, `award_plan.csv`, `dry_run_be.csv`, `dry_run_fr.csv`, `prepared_be_michelin_import.sql`, `prepared_fr_michelin_import.sql`, `validate_be_fr_pre_import.py`, `BE_FR_PRE_IMPORT_CONTROL_REPORT.md`, and this file.
**72. Exact files modified:** None. `michelin_bulk_location_enrichment/` (source workstream) was read only, never written — every original enrichment file (`ready_to_import.csv`, `manual_review.csv`, `scope_manifest.csv`, `source_evidence.csv`, `bulk_location_results.csv`, progress/control reports) remains exactly as found.

---

`BELGIUM/FRANCE MICHELIN PATCH — PRE-IMPORT AUDIT PASSED`

Both countries are clean: 100/100 Belgium and 473/473 France candidates pass every hard requirement, both dry-runs resolve with zero skips or blocks, and the 6 flagged recognition discrepancies were individually resolved (4 corrected, 1 confirmed, 1 already out of scope) rather than left as open questions. The two prepared, country-separable artifacts are ready for a future explicit apply decision — not taken in this task.
