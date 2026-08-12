# Manual Review Resolution Addendum

Follow-up to `NETHERLANDS_VERIFIED_PATCH_REPORT.md`. Resolves the 4 `MANUAL_REVIEW` candidates via short, narrowly-scoped re-verification (their own flagged conflict only — no broader Michelin research, no new candidates added, no national-completeness work reopened).

## Outcome

| Candidate | Original blocker | Resolution | New status |
|---|---|---|---|
| Noble Kitchen (Cromvoirt) | Address resolved to a different-named restaurant ("Nami") | Rebranded to Nami on 2026-05-02, same address, same chef, star retained — **not a new restaurant** | Withdrawn — already exists in production (`rest_0070`) |
| Daalder (Amsterdam) | Address-level geocode showed a different current tenant ("féline"); venue search was 2.5km off | Confirmed via 5+ Dutch trade-press sources: officially reopened at Lindengracht 90 on 2026-06-05/06-10, ten years after its original opening there. OSM was simply stale on both counts. | **Moved to READY_TO_IMPORT** |
| AIRrepublic (Cadzand) | Given address (marina) vs. official-website-implied property (Strandhotel) diverged ~374m | **Closed permanently 2024-03-30** (Sergio Herman's departure from Cadzand); official domain now 301-redirects to an unrelated business | Withdrawn — not a current Michelin restaurant |
| Pure C (Cadzand-Bad) | Address resolved to a different-named restaurant ("Demain") | **Closed 2023-09-23** (same Sergio Herman departure); the address reopened in 2024 as Demain, a different restaurant/chef with its own separate 1★ recognition | Withdrawn — not a current Michelin restaurant |

Only 1 of the 4 flagged candidates (Daalder) was a genuine restaurant-still-missing case with a resolvable location conflict. The other 3 turned out to not be genuinely missing at all — 1 already exists in production under a new name, 2 are closed.

## Revised scope: 18 → 15 genuinely-missing candidates

Removing Noble Kitchen, AIRrepublic, and Pure C from the import-eligible population (documented in `removed_not_genuinely_missing.csv`, not silently deleted) leaves **15** of the original 18 as still genuinely missing and import-eligible — all 1★ (Pure C was the dataset's only 2★ candidate, and it is now confirmed closed).

## Updated final populations

| Population | Was | Now |
|---|---|---|
| `READY_TO_IMPORT` | 3 | **4** (+Daalder) |
| `LOCATION_READY_CITY_PENDING` | 11 | 11 (unchanged) |
| `MANUAL_REVIEW` | 4 | **0** (resolved — file retained as a historical log, see `manual_review.csv`) |
| `REMOVED_NOT_GENUINELY_MISSING` | — (new) | **3** |

18 = 4 + 11 + 3. Re-validated: **31 OK, 0 ISSUES** (`NETHERLANDS_VERIFIED_PATCH_CONTROL_REPORT.md`).

## Two new findings surfaced incidentally (not corrected — production is read-only)

Resolving these 4 conflicts naturally surfaced evidence about **existing** production rows, documented in `existing_data_quality_flags.csv` per the established `EXISTING_IDENTITY_UPDATE_REQUIRED` / `EXISTING_RECOGNITION_UPDATE_REQUIRED` vocabulary, and left uncorrected:

- **`rest_0070` (Nami)** — likely wrong address in production (`Molenstraat 7`, Cromvoirt) vs. multiple sources placing it on the Bernardus Golf estate (`Deutersestraat 39B/D`), 4.1km away. Cromvoirt has only 2 restaurants total, making two same-named fine-dining venues implausible.
- **`rest_0043` (Demain)** — one source reports it closing 2026-05-31 (~2.5 months before this check), and its production address (`Visserijweg 1`, Cadzand) also doesn't match the multiple sources placing it inside Strandhotel Cadzand on Boulevard de Wielingen, 1.75km away.

Neither was corrected — this task has read-only production access and these fall outside its scope (resolving the 4 flagged candidates). Recommend a future controlled data-quality pass.

## Files added/changed this round

**New:** `removed_not_genuinely_missing.csv`, `existing_data_quality_flags.csv`, this addendum.
**Updated:** `ready_to_import.csv` (+1 row), `manual_review.csv` (rewritten as a resolution log), `location_results.csv` (4 rows updated with resolution evidence), `duplicate_check.csv` (4 rows updated), `source_evidence.csv` (+5 source rows), `validate_verified_patch.py` (updated population logic), `NETHERLANDS_VERIFIED_PATCH_CONTROL_REPORT.md` (regenerated).
**Unchanged:** everything else in `verified_patch/`, and every file outside it. Production still reads 774 total / 105 NL restaurants, 1,052 cities, 1,580 award_history rows — identical to before this round. Nothing staged, committed, or pushed.

---

`NETHERLANDS 18-RESTAURANT VERIFIED PATCH — MANUAL REVIEW RESOLVED, READY FOR DEPLOYMENT REVIEW`

All material restaurant-level blockers are cleared. What remains is exactly the controlled, ordinary deployment sequence the original report anticipated: apply `prepared_nl_cities_migration.sql` (12 rows, still not applied) to unlock the 11 `LOCATION_READY_CITY_PENDING` candidates, then review and import in the normal way. No further research is needed on any of the 15 remaining candidates.
