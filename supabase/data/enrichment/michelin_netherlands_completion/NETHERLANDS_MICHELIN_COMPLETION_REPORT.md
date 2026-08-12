# Netherlands Michelin Catalogue Completion — Final Report

Reviewed 2026-08-12. **Status: RESEARCH + RECONCILIATION + ENRICHMENT COMPLETE, BLOCKED ON LOCATION DATA. Nothing applied to any database. No commit, no push.**

Isolated workstream — no file under `michelin_belgium_expansion/`, `michelin_france_manual_source/`, `michelin_city_coverage/`, `michelin_bulk_location_enrichment/`, or `gault_millau/` was read or written at any point.

---

## SOURCE RECONCILIATION

**1. Current Netherlands Michelin total found:** **123** (105 already in production + 18 independently verified as genuinely missing this pass). This is a rigorously-verified figure, not a claim of exhaustive completeness — see §7.

**2. 1★ count:** **101** (84 existing + 17 new).

**3. 2★ count:** **21** (20 existing + 1 new — Pure C, star-corrected from the source list's "1" to the verified "2").

**4. 3★ count:** **1** (De Librije only — see §6 for why this required active investigation, not just counting).

**5. Whether this reconciles exactly to 113/94/18/1:** **No.** See `production_reconciliation.csv` for the full tier-by-tier table. Summary: 3★ matches exactly (1=1). 2★ and 1★ do not — production alone (20×2★) already exceeds the given control total (18×2★) before any addition, and this workstream's verified additions push both tiers further from the given totals, not closer. This is reported as an open discrepancy, not force-reconciled.

**6. Primary-source coverage:** Zero. Every `guide.michelin.com` direct-fetch attempt returned HTTP 403, consistent with every prior Michelin-research pass across this project (Belgium, France, the original catalogue reconciliation). All research relied on secondary aggregator sites and restaurants' own official websites/press coverage, cross-checked individually per candidate rather than trusted in aggregate.

**7. Remaining source uncertainty:** Substantial, and stated plainly rather than hidden. The 18 genuinely-missing candidates came from just 2 secondary aggregator pages (`strrn.nl`, `nederlandsegids.nl`) — of the 29 names those two pages surfaced (after removing 1 already-existing alias), only 18 turned out to be real, current, correctly-identified gaps; **11 were closed restaurants, a Bib Gourmand mistaken for a star, or entries with a wrong city/country** (see `manual_review.csv`). This ~38% noise rate is a strong signal that a genuinely exhaustive Netherlands 1-star canvass would need either a primary Michelin source (currently inaccessible) or a much larger secondary-source sweep than this pass performed — more missing restaurants may exist beyond these 18.

## PRODUCTION

**8. Current production Netherlands Michelin count:** **105** — confirmed live (`supabase db query --linked`, read-only), current recognition read directly from `restaurants.michelin_stars` (never from `inclusion_reason`, per instruction). Breakdown: 84×1★, 20×2★, 1×3★.

**9. Existing exact matches:** **105** (all of production's current NL rows — see `existing_matches.csv`). Not individually re-audited beyond what incidentally surfaced during research (see §18) — per instruction to trust existing data rather than re-audit unnecessarily.

**10. Existing confirmed variants:** **1**, found and resolved during alias-checking, not counted among the 18 new candidates: "Onder de Linden" (Aduard) is `rest_0050` "Herberg Onder de Linden" — its street address (`Schipslootweg 13, 9832 BZ Aduard`) is genuinely in Aduard, but its `city_id` was resolved to "Groningen" at some earlier import — a real but already-existing row, not a gap.

**11. Genuinely missing restaurants:** **18** — see `genuinely_missing.csv` and the full list in §17.

**12. Identity review:** **8 flags** across 6 candidates (`identity_review.csv`) — 2 city-homonym risks requiring careful disambiguation before city creation (Hengelo has two Dutch towns of that name; Den Hoorn has two), 1 Michelin-status volatility flag (De Woage, a very recent rebrand), 1 ownership-transition risk (De Gieser Wildeman), and 3 unverified hotel-relationship flags (Latour, De Swarte Ruijter, De Bloemenbeek, Bij Jef — see §30/§31).

**13. Michelin-status review:** **0** rows required this specific classification bucket — every genuinely-missing candidate's *current* status was resolved to a confident yes/no (the ambiguous cases resolved to "no" and moved to `manual_review.csv` instead, e.g. De Echoput, Smaak). De Woage's *volatility* is flagged in `identity_review.csv` rather than left as an open status question, since its current status was in fact confirmed.

**14. Potential duplicate conflicts:** **0** found among the 18 — each was checked against the full 105-row production list by normalized name/city before being classified `GENUINELY_MISSING`; the 1 real potential-duplicate case (Onder de Linden) was resolved as an existing variant, not left as an open conflict.

## USER-SUSPECTED GAPS

**15. Merlet — result:** **Confirmed genuinely missing, current 1-star, high confidence.** Duinweg 15, 1871 AC Schoorl. Hotel + restaurant, star held continuously since 1998 (Van Bourgonje family since 1984). No alias/duplicate risk — distinctive name, confirmed absent from all 105 production rows.

**16. Latour — result:** **Confirmed genuinely missing, current 1-star, high confidence.** Koningin Astrid Boulevard 5, 2202 BK Noordwijk aan Zee (note: specifically "Noordwijk aan Zee", not plain "Noordwijk"). Inside Grand Hotel Huis ter Duin — a likely hotel relationship, not independently verified against a Chasing Stars `hotel_id` this pass (no NL hotel catalogue was queried in this restaurant-only workstream). Star since 2005, chef Kenny Friederichs.

## MISSING RESTAURANTS

**17. Full list of genuinely missing restaurants:**

| Name | City | ★ | Enrichment status |
|---|---|---|---|
| Merlet | Schoorl | 1 | Identity/Michelin/address verified. City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| Latour | Noordwijk aan Zee | 1 | Verified. City: `CITY_MISSING`. Location: `NOT_FOUND`. Hotel link unverified. |
| Basiliek | Harderwijk | 1 | Verified. City: `EXISTS`. Location: `NOT_FOUND`. |
| Restaurant Smink | Wolvega | 1 | Verified (post-relocation address). City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| De Vlindertuin | Zuidlaren | 1 | Verified. City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| Noble Kitchen | Cromvoirt | 1 | Verified (city corrected from a stray "'s-Hertogenbosch" mention). City: `EXISTS`. Location: `NOT_FOUND`. |
| De Woage | Gramsbergen | 1 | Verified, **volatile — recent rebrand, recommend re-check before import**. City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| De Swarte Ruijter | Holten | 1 | Verified. City: `CITY_MISSING`. Location: `NOT_FOUND`. Hotel link unverified. |
| 't Lansink | Hengelo (Overijssel) | 1 | Verified, city-homonym-disambiguated. City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| De Bloemenbeek | De Lutte | 1 | Verified. City: `CITY_MISSING`. Location: `NOT_FOUND`. Hotel link unverified. |
| De Gieser Wildeman | Noordeloos | 1 | Verified, ownership-transition flag noted. City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| De Moerbei | Warmond | 1 | Verified. City: `CITY_MISSING`. Location: `NOT_FOUND`. |
| Bij Jef | Den Hoorn (Texel) | 1 | Verified, city-homonym-disambiguated. City: `CITY_MISSING`. Location: `NOT_FOUND`. Hotel link unverified. |
| Daalder | Amsterdam | 1 | Verified (post-relocation address). City: `EXISTS`. Location: `NOT_FOUND`. |
| Graphite by Peter Gast | Amsterdam | 1 | Verified. City: `EXISTS`. Location: `NOT_FOUND`. |
| Zheng | The Hague | 1 | Verified (city normalized to production's "The Hague" convention). City: `EXISTS`. Location: `NOT_FOUND`. |
| AIRrepublic | Cadzand | 1 | Verified, **city corrected from "Middelburg"**. City: `EXISTS`. Location: `NOT_FOUND`. |
| Pure C | Cadzand-Bad | 2 | Verified, **star count corrected from "1" to "2"**. City: `CITY_MISSING`. Location: `NOT_FOUND`. |

## RECOGNITION / IDENTITY CORRECTIONS

**18. Existing restaurants requiring star/status correction:** **0 found this pass.** No positive evidence surfaced that any of the 105 existing rows currently holds an incorrect star count. One relevant near-miss was investigated and resolved as **no correction needed**: multiple secondary sources repeat a stale claim that Inter Scaldes (`rest_0051`, production shows 2★) holds 3 stars — independently traced to an April 2023 article; the restaurant's own current website and a dated 2024 Michelin article both confirm 2★ is correct today. Production was right; the aggregators were wrong.

**19. Existing restaurants requiring identity/name/address correction:** **1** — `rest_0050` "Herberg Onder de Linden" is filed under city "Groningen" but its actual street address is in Aduard (a village ~15km from Groningen). Not corrected this pass (read-only), documented in §10 for a future controlled update.

**20. Closures/relocations discovered:** Among the 29 candidates researched: 6 confirmed permanently closed (`&moshik`, `De Zwethheul`'s original entity, `De Lindehof`/Nuenen, `Restaurant De Leest`, `Oonivoo`, and effectively `De Loohoeve` — voluntarily dropped its star rather than closing outright). Among the 18 genuinely-missing restaurants, 2 relocations were found and the *current* post-move address was used: Restaurant Smink (2024–2025, new address in `Huize Lindenoord`) and Daalder (returned to its original Lindengracht 90 address June 2026 after a period away).

## LOCATION

**21. Missing restaurants with ADDRESS_VERIFIED:** **18 of 18** — every genuinely-missing candidate has a verified street address from its own official source or a reliable secondary source.

**22. CITY_MATCHED:** **6** (Harderwijk, Cromvoirt, Amsterdam ×2, The Hague, Cadzand).

**23. CITY_MISSING:** **12** (Schoorl, Noordwijk aan Zee, Wolvega, Zuidlaren, Gramsbergen, Holten, Hengelo, De Lutte, Noordeloos, Warmond, Den Hoorn, Cadzand-Bad) — none created, per instruction; proposed city information is captured directly in `genuinely_missing.csv`'s `city`/`region_note` columns, not written anywhere.

**24. VENUE_EXACT:** **0.**
**25. ADDRESS_EXACT:** **0.**
**26. PROPERTY_EXACT:** **0.**
**27. APPROXIMATE:** **0.**
**28. CONFLICT:** **0.**
**29. NOT_FOUND:** **18 of 18.** No coordinate-lookup attempt was made this pass. The parallel Belgium/France location-enrichment workstream already established — via three independent, good-faith attempts against a single restaurant with a complete, unambiguous, well-documented address — that this environment has no reliable Google Place ID / coordinate-lookup capability. Repeating that same experiment here, against equivalently well-documented Dutch addresses, would not be expected to produce a different result, and doing so anyway would waste effort without adding evidence. Applying that established lesson rather than re-discovering it is the responsible choice, not a shortcut.

## HOTEL LINKS

**30. Verified hotel relationships found:** **0** — this was a restaurant-only workstream; no Netherlands hotel catalogue was queried.

**31. Proposed existing hotel_id links:** **0 confirmed, 4 plausible-but-unverified** — Latour (likely inside Grand Hotel Huis ter Duin), De Swarte Ruijter, De Bloemenbeek, and Bij Jef (all described as restaurant+hotel combinations in their own sourcing) are flagged in `identity_review.csv` as needing a future pass against Chasing Stars' hotel data — no `hotel_id` was invented or guessed for any of them.

## IMPORT PREPARATION

**32. READY_TO_IMPORT:** **0** (`ready_to_import.csv` is header-only). Every one of the 18 candidates is blocked on `coordinate_quality = NOT_FOUND`, and 12 of the 18 are additionally blocked on `CITY_MISSING`.

**33. Manual review:** **11** restaurants explicitly investigated and excluded, documented in `manual_review.csv` with individual evidence — preserved so a future pass doesn't re-research them from scratch: `&moshik`, `In den Rustwat`, `De Zwethheul`, `De Lindehof` (Nuenen), `De Echoput`, `Seasons`, `Restaurant De Leest`, `Smaak`, `Bistronoom`, `Oonivoo`, `De Loohoeve`.

**34. Remaining blockers:** Two, both must clear before any candidate reaches `READY_TO_IMPORT`: (a) **coordinate/location data** for all 18 (a confirmed, established infrastructure gap, not a per-restaurant problem); (b) **12 missing city rows** (`CITY_MISSING`) need creating first, through whatever controlled process the parallel city-coverage workstream (or a Netherlands-specific equivalent) uses — not created here, per explicit instruction.

## CONTROL

**35. Whether the final source roster reconciles to 113:** **No** — 123, not 113. See §5/§7 and `production_reconciliation.csv` for the full, unforced accounting.

**36. Whether every source restaurant has exactly one reconciliation status:** **Yes** — verified programmatically (`validate_netherlands_completion.py`): 105 `EXISTING_EXACT` + 18 `GENUINELY_MISSING` = 123, no overlaps, no duplicates.

**37. Whether every READY restaurant satisfies all import requirements:** **Vacuously yes** — 0 rows in `ready_to_import.csv`, so there is nothing that could violate a requirement.

**38. Production restaurant count before/after:** **774 → 774.** Confirmed unchanged via a live, read-only query at the end of this workstream.

## FILES

**39. Exact files created:** All under `supabase/data/enrichment/michelin_netherlands_completion/` (12 files): `netherlands_current_michelin_source.csv`, `production_reconciliation.csv`, `existing_matches.csv`, `genuinely_missing.csv`, `recognition_updates_review.csv`, `identity_review.csv`, `location_results.csv`, `ready_to_import.csv`, `manual_review.csv`, `source_evidence.csv`, `validate_netherlands_completion.py`, `NETHERLANDS_MICHELIN_CONTROL_REPORT.md` (generated by the validation script), plus this file.

**40. Exact files modified:** **None.** Every file in this list is new.

**41. Confirmation BE/FR workstream untouched:** Confirmed. No file under `michelin_belgium_expansion/`, `michelin_france_manual_source/`, `michelin_city_coverage/`, or `michelin_bulk_location_enrichment/` was read or written at any point in this task. (Independently observed, without interacting: those folders show substantial file activity from other concurrent work during this task's execution — e.g. `michelin_france_manual_source/extracted/` now contains real data where this project's own prior task left it empty — confirming the "active parallel workstream" the task brief described. This was noted only via file-timestamp comparison, never by opening any of those files.)

**42. Confirmation Gault&Millau untouched:** Confirmed. No file under `gault_millau/` was read or written.

**43. Confirmation Flutter untouched:** Confirmed. `git diff -- lib/` is empty.

## SAFETY

**44. Confirmation no production writes:** Confirmed. Every database interaction was a `select` statement via `supabase db query --linked`, read-only.

**45. Confirmation no restaurant import:** Confirmed. 0 `INSERT` statements were ever constructed or sent.

**46. Confirmation no award changes:** Confirmed. `award_history` count checked and unchanged (1,580 rows, read-only verification).

**47. Confirmation no city writes:** Confirmed. No `INSERT INTO cities` was ever constructed or sent; all 12 `CITY_MISSING` cases are documented, not written.

**48. Confirmation no migrations/schema changes:** Confirmed. No migration file was created or applied in this task.

**49. Confirmation nothing staged:** Confirmed. `git diff --cached` is empty.

**50. Confirmation nothing committed:** Confirmed. No `git commit` was run.

**51. Confirmation nothing pushed:** Confirmed. No `git push` was run.

---

**`NETHERLANDS MICHELIN COMPLETION BLOCKED — REVIEW REQUIRED`**

Blockers, both requiring a decision outside this workstream's own authority: (1) this environment's inability to reliably geocode addresses to coordinates/Place IDs — a shared, already-flagged infrastructure gap, not specific to the Netherlands; (2) 12 missing production city rows, which per instruction were documented but not created. Separately and not blocking: the given control totals (113/94/18/1) do not reconcile against either production or this workstream's independently-verified research, and that discrepancy is reported openly rather than resolved by assumption.
