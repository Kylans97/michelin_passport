# Netherlands 18-Restaurant Verified Patch — Final Report

Reviewed 2026-08-12. Scope: the 18 `GENUINELY_MISSING` restaurants already established by the parent `michelin_netherlands_completion/` workstream. This task did not reopen national completeness, did not add candidates, and did not import anything.

Isolated to `supabase/data/enrichment/michelin_netherlands_completion/verified_patch/`. No file under `michelin_belgium_expansion/`, `michelin_france_manual_source/`, `michelin_city_coverage/`, `michelin_bulk_location_enrichment/`, or `gault_millau/` was read or written.

---

## SCOPE

**1. Expected candidates:** 18.
**2. Processed candidates:** 18.
**3. 1★ count:** 17.
**4. 2★ count:** 1 (Pure C).
**5. Merlet present:** Yes (nl_001).
**6. Latour present:** Yes (nl_002).

Scope integrity independently re-verified this pass: no duplicate `candidate_id`, no overlap with any of the 11 previously-rejected names in the parent folder's `manual_review.csv`. See `scope_18.csv`.

## CITY

**7. Existing production cities reused:** 5 distinct city rows (Amsterdam, Cadzand, Cromvoirt, Harderwijk, The Hague), covering 6 candidates (Amsterdam used twice: Daalder and Graphite).
**8. New city rows required:** 12.
**9. CITY_MATCHED:** 6.
**10. CITY_MISSING:** 12.
**11. CITY_REVIEW:** 0 — every city identity resolved unambiguously (including the two homonym-risk cases, Hengelo and Den Hoorn, both independently re-confirmed this pass via OSM geocoding landing in the correct province).
**12. Exact proposed city rows:** 12 — see `proposed_cities.csv`. Re-verified live against production with zero drift from the parent workstream's earlier audit.

## ADDRESS

**13. ADDRESS_VERIFIED:** 18 of 18 — every candidate's address was already sourced with citations in the parent workstream's `genuinely_missing.csv` and reused as authoritative input, per this task's explicit instruction not to re-run broad Michelin research.
**14. ADDRESS_REVIEW:** 0.
**15. ADDRESS_NOT_FOUND:** 0.

Note: "address verified" is distinct from "geocoder result consistent with that address" — 4 candidates have a verified address but an unresolved *location* discrepancy (see §21–29, §16).

## LOCATION

**16. Coordinates established:** 14 of 18 (the 4 `CONFLICT` candidates deliberately carry no coordinate rather than a guessed one).
**17. VENUE_EXACT:** 9 (Latour, Basiliek, De Vlindertuin, De Woage, De Gieser Wildeman, De Moerbei, Bij Jef, Graphite by Peter Gast, Zheng).
**18. ADDRESS_EXACT:** 1 (Restaurant Smink).
**19. PROPERTY_EXACT:** 4 (Merlet, De Swarte Ruijter, 't Lansink, De Bloemenbeek — all combined restaurant+hotel properties).
**20. APPROXIMATE:** 0.
**21. CONFLICT:** 4 (Noble Kitchen, Daalder, AIRrepublic, Pure C — see §23 and `location_results.csv` for full evidence per case).
**22. NOT_FOUND:** 0.

Geocoding used Nominatim/OSM, paced at 1.1s between requests (well under the 1 req/sec policy floor), with a fully isolated cache (`geocoding_cache.json`) — separate from the Belgium/France workstream's own cache. 24 total requests across the task (18 address queries + 18 venue queries with some short-circuited by cache hits, plus 6 narrow follow-up queries).

**The venue-vs-address safeguard was actively exercised, not just declared.** Two clear cases: Merlet's free-text venue search returned an unrelated "Merlet Training & Convention Centre" 44m from the correct hotel-restaurant — rejected on name-match-without-location-proof grounds. Daalder's venue search returned a result 2.5km from its source-cited current address, in a different Amsterdam neighborhood — rejected outright as the textbook case this rule exists to catch.

## IDENTITY / DUPLICATES

**23. IDENTITY_VERIFIED:** 16 of 18.
**24. IDENTITY_REVIEW:** 2 — Noble Kitchen and Pure C, both because an address-level geocode of their given address resolves to a **different-named** restaurant (`Nami` and `Demain` respectively), not the candidate itself.
**25. POTENTIAL_EXISTING_MATCH_REVIEW:** 0 — see §26.
**26. Newly discovered production matches:** 0 confirmed, but 2 genuine near-misses were investigated and ruled out. Both `Nami` and `Demain` — the two names that unexpectedly surfaced during geocoding — **already exist in production** (`rest_0070` Nami, Cromvoirt; `rest_0043` Demain, Cadzand). Each was individually checked against its own OSM-returned coordinate: `Nami` (production) is 4.12km from Noble Kitchen's given address; `Demain` (production) is 1.75km from Pure C's given address, on a distinct Michelin municipality slug (`/cadzand/` vs. Pure C's `/cadzand-bad/`). Both are confirmed **not** the same restaurant — this was a duplicate scare that resolved cleanly, not a duplicate. The underlying identity/location question for Noble Kitchen and Pure C themselves remains open regardless (§24).

## MICHELIN

**27. Star-count conflicts discovered:** 0 — no primary evidence encountered this pass contradicted any of the 18 candidates' stored star counts.
**28. MICHELIN_STATUS_REVIEW:** 0 newly raised this pass. The pre-existing `identity_review.csv` flag on De Woage (recent Jan 2026 rebrand, `FLAGGED_NOT_BLOCKED`) is carried forward unchanged — nothing in this pass's location research either confirmed or contradicted it further.

## USER-FLAGGED

**29. Merlet final enrichment result:** `PROPERTY_EXACT` location (52.6996668, 4.6942853), city `Schoorl` proposed (not yet in production) → **`LOCATION_READY_CITY_PENDING`**. Passed every other gate (identity, address, duplicate safety) cleanly; the only blocker is the pending city row.
**30. Latour final enrichment result:** `VENUE_EXACT` location (52.2412489, 4.4276191), city `Noordwijk aan Zee` proposed (not yet in production) → **`LOCATION_READY_CITY_PENDING`**. Hotel relationship to Grand Hotel Huis ter Duin remains plausible but unverified against production's hotel catalogue (0 matches found among 17 NL hotels) — not a blocker per the task's own rules (§15).

Neither was treated as automatically ready — both were run through the identical gates as all 18.

## HOTEL

**31. Verified hotel relationships:** 0.
**32. Proposed hotel_id links:** 0. Checked 7 candidates with plausible property context (Merlet, Latour, De Swarte Ruijter, 't Lansink, De Bloemenbeek, Bij Jef, AIRrepublic) by name against all 17 NL rows in production's `hotels` table — zero matches. Production's current NL hotel catalogue simply does not yet include any of these properties. See `hotel_link_review.csv`.

## FINAL POPULATIONS

**33. READY_TO_IMPORT:** **3** — Basiliek (Harderwijk), Graphite by Peter Gast (Amsterdam), Zheng (The Hague). See `ready_to_import.csv`.
**34. LOCATION_READY_CITY_PENDING:** **11** — Merlet, Latour, Restaurant Smink, De Vlindertuin, De Woage, De Swarte Ruijter, 't Lansink, De Bloemenbeek, De Gieser Wildeman, De Moerbei, Bij Jef. Every field satisfied except an existing production `city_id`. See `location_ready_city_pending.csv`.
**35. MANUAL_REVIEW:** **4** — Noble Kitchen, Daalder, AIRrepublic, Pure C — each blocked by a genuine, evidence-based identity or location conflict, not by missing effort. See `manual_review.csv` for the specific blocker and recommended next step per candidate.
**36. Remaining blockers:** (a) 12 city rows need creating before 11 of the 18 can become fully `READY_TO_IMPORT` — artifact prepared, not applied (§37–39); (b) 4 candidates need a fresh, narrowly-scoped re-verification of their exact current name/address before any import decision — this task's scope did not permit resolving those guesses.

## CITY DEPLOYMENT

**37. Whether a city migration/artifact was prepared:** Yes — `prepared_nl_cities_migration.sql`.
**38. Exact city rows it would create:** 12 — `('NL','Schoorl',NULL)`, `('NL','Noordwijk aan Zee',NULL)`, `('NL','Wolvega',NULL)`, `('NL','Zuidlaren',NULL)`, `('NL','Gramsbergen',NULL)`, `('NL','Holten',NULL)`, `('NL','Hengelo','Overijssel')`, `('NL','De Lutte',NULL)`, `('NL','Noordeloos',NULL)`, `('NL','Warmond',NULL)`, `('NL','Den Hoorn','Noord-Holland')`, `('NL','Cadzand-Bad',NULL)`. Idempotent via `ON CONFLICT (country_code, name, coalesce(region,'')) DO NOTHING`, matching the schema's real unique index and the exact syntax convention of the precedent Belgium/France city-coverage migration (read for convention reference only).
**39. Confirmation it was NOT applied:** Confirmed. The file lives only in `verified_patch/`, not under `supabase/migrations/`; `supabase db push` cannot see it. No `INSERT` was ever sent to production.

## CONTROL

**40. 18/18 classified exactly once:** Confirmed by `validate_verified_patch.py` — 3 + 11 + 4 = 18, no overlaps.
**41. All READY rows satisfy hard requirements:** Confirmed — all 3 have city_id, lat/lon, and an acceptable coordinate_quality.
**42. All LOCATION_READY_CITY_PENDING rows satisfy everything except existing city_id:** Confirmed — all 11 have lat/lon and an acceptable coordinate_quality; only `city_id` is pending.
**43. No suspicious coordinate outliers:** Confirmed — all 14 resolved coordinates fall within the Netherlands' geographic bounds and match their stated province/region.
**44. No duplicate candidate IDs:** Confirmed.

Validation run: **28 OK, 0 ISSUES.** See `NETHERLANDS_VERIFIED_PATCH_CONTROL_REPORT.md`.

## SAFETY

**45. Production restaurant count before/after:** 774 / 774 — unchanged (774 total, 105 NL). Verified live at the end of this task; matches the figure recorded at the end of the parent workstream, with no writes in between.
**46. Production city count before/after:** 1,052 / 1,052 total — unchanged. (70 of these are NL, recorded for reference; no prior NL-specific baseline existed to compare against, but the total figure is unchanged and no `INSERT` was ever issued.)
**47. Confirmation no remote writes:** Confirmed — every database interaction was a read-only `select` via `supabase db query --linked`.
**48. Confirmation no restaurant import:** Confirmed — 0 `INSERT` statements constructed or sent.
**49. Confirmation no award changes:** Confirmed — `award_history` count checked, unchanged (1,580 rows).
**50. Confirmation no city writes:** Confirmed — `prepared_nl_cities_migration.sql` was written to disk only, never executed.
**51. Confirmation no migration applied:** Confirmed — no file was placed under `supabase/migrations/`, no `supabase db push` was run.
**52. Confirmation BE/FR workstream untouched:** Confirmed — no file under `michelin_belgium_expansion/`, `michelin_france_manual_source/`, `michelin_city_coverage/`, or `michelin_bulk_location_enrichment/` was read or written.
**53. Confirmation Gault&Millau untouched:** Confirmed — no file under `gault_millau/` was read or written.
**54. Confirmation Flutter/tests untouched:** Confirmed — `git diff --stat -- lib/` is empty.
**55. Confirmation nothing staged:** Confirmed — `git diff --cached --stat` is empty.
**56. Confirmation nothing committed:** Confirmed — no `git commit` was run.
**57. Confirmation nothing pushed:** Confirmed — no `git push` was run.

## FILES

**58. Exact files created:** 19 total, all under `supabase/data/enrichment/michelin_netherlands_completion/verified_patch/`: `scope_18.csv`, `city_reconciliation.csv`, `proposed_cities.csv`, `geocode_nl_patch.py`, `geocode_raw_results.json`, `geocoding_cache.json`, `followup_queries.py`, `geocode_followup_results.json`, `location_results.csv`, `hotel_link_review.csv`, `duplicate_check.csv`, `source_evidence.csv`, `ready_to_import.csv`, `location_ready_city_pending.csv`, `manual_review.csv`, `prepared_nl_cities_migration.sql`, `validate_verified_patch.py`, `NETHERLANDS_VERIFIED_PATCH_CONTROL_REPORT.md`, and this file (`NETHERLANDS_VERIFIED_PATCH_REPORT.md`).

**Exact files modified:** None. Every file above is new.

---

`NETHERLANDS 18-RESTAURANT VERIFIED PATCH — MANUAL REVIEW REQUIRED`

Material restaurant-level blockers remain: 4 of the 18 candidates (Noble Kitchen, Daalder, AIRrepublic, Pure C) have a genuine, evidence-based identity or location conflict that a purely mechanical geocoding pass cannot resolve responsibly — each needs a short, targeted re-verification of its actual current name/address before any import decision, not a guess between two plausible coordinates. The remaining 14 are in good shape: 3 are fully `READY_TO_IMPORT` today, and 11 more need only the prepared (not applied) city migration to follow.
