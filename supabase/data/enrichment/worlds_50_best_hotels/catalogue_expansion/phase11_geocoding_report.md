# Hotel Catalogue Expansion — Venue Identity + Geocoding Report

**Status: review checkpoint. No production connection, no remote SQL, no migration applied remotely, no Flutter change, no commit, no push. Deployment was NOT run against production — local only, per explicit instruction not to deploy partially.**

---

## 1–4. Hotels researched, READY / BLOCKED counts

| | Count |
|---|---|
| Hotels researched | **94** |
| READY_HIGH | **62** |
| READY_MEDIUM | **26** |
| **Total ready for deployment** | **88** |
| BLOCKED_COORDINATES | 4 |
| BLOCKED_ADDRESS | 1 |
| BLOCKED_AMBIGUOUS_PROPERTY | 1 |
| **Total blocked** | **6** |

**Exact unresolved hotels:**

| hotel_code | Hotel | Reason |
|---|---|---|
| hotel_706 | Kokomo Private Island | **BLOCKED_ADDRESS** — remote private-island resort, seaplane/helicopter access only. Its own official site's contact page gives no street address or P.O. Box, and none exists anywhere. Coordinates are solid. Needs a human decision on whether a descriptive location string is an acceptable `address` value, or whether this stays blocked. |
| hotel_715 | The Brando | **BLOCKED_COORDINATES** — address (Tetiaroa Private Island, French Polynesia) is solid; the only coordinate found anywhere is a Wikidata figure rounded to the nearest arc-minute (~1-2km precision), not reliable enough for a specific building on a small atoll. |
| hotel_723 | Suján Jawai | **BLOCKED_COORDINATES** — address is solid; a same-named village near a different city (Jodhpur, not Pali) is the only geocoder match, which would risk a materially wrong pin. Declined rather than substitute a nearby but unconfirmed feature. |
| hotel_733 | Soneva Secret | **BLOCKED_COORDINATES** — newest Soneva property (opened May 2024), not yet indexed anywhere with coordinates. Address/island identity is confirmed. |
| hotel_739 | One&Only Mandarina | **BLOCKED_COORDINATES** — address is well-corroborated across many sources; no reliable coordinate source located despite extensive search. |
| hotel_747 | Singita – Kruger National Park | **BLOCKED_AMBIGUOUS_PROPERTY** — see §6. |

## 5. Address coverage

**94/94** rows in the full review dataset carry an address value (including 5 of the 6 blocked hotels, whose address was independently resolved even though something else blocks them). **88/94** meet the actual NOT NULL production requirement in the deployment file (the 6 blocked hotels are deliberately left with a blank `address` cell there, not a placeholder).

## 6. Singita resolution

Returned to the original source: **theworlds50best.com's own listing, titled "Singita – Kruger National Park"** (ranked #15 in 2023, #40 in 2025), explicitly states its entry **"covers Singita Kruger National Park's lodges, Singita Lebombo and Singita Sweni"** — naming both, not one. `singita.com` confirms these are two separate, individually-bookable lodges sharing one concession and phone number. MICHELIN Guide maintains two separate listing pages for them (Lebombo and Sweni), implying separate Key tiers.

**This is a genuine collective/plural ranking entry, not a single physical building — it was not resolved to either lodge.** Two informal reference coordinates were found for a future reviewer only (Lebombo ≈ -24.45083, 31.9775; Sweni ≈ -24.450961, 31.977753 — both from a secondary source, ~20-40m apart, neither independently verified), but no selection was made.

**This requires a human product decision that was not made here, as instructed:** does Chasing Stars model "Singita – Kruger National Park" as (a) one umbrella property — which then has no single verifiable address, since none exists for a collective entry — or (b) two separate physical hotels, each needing its own `hotel_code`, address, coordinates, and Key-tier research? `hotel_747` remains blocked pending that decision.

## 7. Rosewood Mayakoba resolution

Fully resolved (previously missed entirely):

- **Identity**: the Rosewood-branded hotel inside the Mayakoba resort development, Playa del Carmen/Solidaridad, Quintana Roo, Mexico — one of four hotel brands (Rosewood, Fairmont, Banyan Tree, Andaz) sharing a 620-acre gated enclave. Address/coordinates are specific to the Rosewood property, not the shared complex.
- **Address**: Ctra. Federal Cancún–Playa del Carmen Km 298, Solidaridad, Quintana Roo, CP 77710 — corroborated by the hotel's own site, MICHELIN Guide, and multiple listings.
- **Coordinates**: 20.687928, -87.02013 — third-party source only (the hotel's own Maps link resolved to a malformed identifier with no embedded coordinates), geographically consistent with the stated location. Classified READY_MEDIUM rather than READY_HIGH for this reason.
- **MICHELIN Key status**: **confirmed 2 Keys**, awarded in the 2025 MICHELIN Guide Mexico selection — closing a gap left open in the previous pass.
- **World's 50 Best cross-check**: confirmed at rank #95, 2025 extended list (51-100) — consistent with the existing ranking-history data.

## 8. Address coverage — see §5.

## 9. Coordinate coverage

**89/94** hotels have latitude/longitude (the 88 ready hotels, plus Kokomo — which has valid coordinates but is blocked on address, not coordinates). **5/94** lack coordinates entirely (the other 5 blocked hotels).

## 10. Google Place ID coverage

**5/94** — deliberately conservative. Many research agents found Google Maps "CID" identifiers (a `!1sHEX:HEX` content-ID pair from a Maps URL) rather than a true Places API `place_id=` string; per the explicit guardrail against manufacturing or deriving Place IDs, **every CID was excluded from the `google_place_id` field** and kept only as corroborating evidence in the review file. Only an explicit `place_id=`/`query_place_id=` URL parameter was accepted:

| hotel_code | Hotel | Place ID |
|---|---|---|
| hotel_753 | Dusit Thani Bangkok | ChIJNR_QAkSf4jARbTRljQDBL70 |
| hotel_772 | Amangiri | ChIJq-qcNtwhNYcRazgIZDEKTIc |
| hotel_775 | Hotel Bel-Air | ChIJ4XfXK_G8woARbUYxTMpyDo8 |
| hotel_777 | The Beverly Hills Hotel | ChIJjWrkXge8woARQa2f1ewAZqA |
| hotel_778 | The Carlyle | ChIJEQ6D9pRYwokR5TXzH7ACo7I |

The other 89 hotels have `google_place_id = NULL` — the schema permits this (`google_place_id text unique`, no NOT NULL), so this does not block deployment.

## 11. Duplicate-coordinate / shared-Place-ID findings

**Zero duplicates found**, checked programmatically across all 94 rows: no two hotels share a coordinate pair (rounded to 5 decimal places, ~1m precision) and no two hotels share a Google Place ID. Coordinate range/plausibility validation (latitude ∈ [-90,90], longitude ∈ [-180,180], no (0,0), coordinate falls inside a country-level bounding box) also passed with **zero flagged issues** across all 89 hotels with coordinates.

## 12. Updated expected hotel INSERT count

**88** (up from 0 in the previous pass) — verified against a real local dry-run and confirmed by a real committed run.

## 13. Updated expected W50B history INSERT count

**155 new rows** (up from 0 previously insertable beyond the 34 already resolvable via existing catalogue hotels) — for a combined total of **189 of 200** ranking rows now represented in the database (34 pre-existing + 155 new).

## 14. Rows still blocked by unresolved hotels

**11 of 200** ranking rows remain `BLOCKED_DEPENDENT_HOTEL` — one per year-appearance for the 6 still-blocked hotels (Kokomo: 1 appearance, The Brando: 1, Suján Jawai: 2, Soneva Secret: 1, One&Only Mandarina: 3, Singita: 3). None were silently dropped or force-inserted.

## 15–18. Local testing results

All run against local Supabase, starting from the verified 687-hotel pre-expansion baseline (confirmed via direct query: 687 hotels, none in the new 688-781 range, no leftover test fixtures, before this pass began).

- **Dry-run**: classified 88 hotel `INSERT` / 6 `BLOCKED_MISSING_REQUIRED_FIELD`; 155 ranking `INSERT` / 34 `ALREADY_PRESENT` / 11 `BLOCKED_DEPENDENT_HOTEL`. All 10 post-deploy checks passed. Rolled back, 0 rows written.
- **Real run**: identical classification, **committed**: 88 new hotel rows, 155 new ranking rows. Local DB now holds 775 hotels, 189 `worlds_50_best_hotels` rows.
- **Idempotency**: a second dry-run and a second real run both reclassified everything as `ALREADY_PRESENT`, applied 0 new writes, all checks passed — both a repeat dry-run and a repeat real run are safe no-ops.
- **Conflict / rollback**: a real ranking row for an already-inserted hotel (`hotel_760`) was deliberately corrupted in the database (rank changed from 20 to 999) to simulate a future data divergence, then both a dry-run *and* a real (non-dry-run) deployment attempt were run against that corrupted state. Both correctly classified it `CONFLICT` and **the real run's transaction fully rolled back** — exit code 1, zero rows changed, the corrupted value was still 999 immediately afterward (proving the script didn't silently "fix" it, it genuinely rolled back everything). The corruption was then manually reverted to restore the correct value.

## 19. Invariant validation

All pass, confirmed by direct query after the real deployment: 775 total hotels; all 687 original hotels present and unchanged (verified numerically, not string-matched, after catching a padding artifact in my own verification query — see below); `hotel_restaurants` unchanged at 68 rows; no original hotel has a NULL `michelin_keys` (only new hotels can be NULL); every inserted hotel has non-null `address`/`location`; a NULL-Key W50B hotel (e.g. `hotel_760`, Jumeirah Marsa Al Arab) reads correctly through `hotels_full` with `michelin_keys = NULL` (never 0) and its `worlds_50_best_hotels` row resolves via FK to the correct hotel UUID — spot-checked directly.

*(One self-caught slip during this verification: my first invariant query used `hotel_1`..`hotel_687` string patterns and undercounted by 9 — the original catalogue's 1-99 range uses 2-digit zero-padding (`hotel_01`), not bare numbers. Fixed with a numeric comparison; all 687 confirmed present.)*

## 20. Exact files created/modified

```
supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
  phase11_geocoding_report.md                — NEW (this file)
  v2_union_catalogue/
    new_hotels_for_deployment.csv            — UPDATED IN PLACE (same 94 rows/hotel_codes,
                                                 88 now carry address/lat/long/place_id)
    new_hotels_geocoded_review.csv           — NEW, 94 rows, full research detail
    new_hotels_ready_for_deployment.csv      — NEW, 88 rows (READY_HIGH + READY_MEDIUM only)
    new_hotels_location_unresolved.csv       — NEW, 6 rows (blocked, with reasons)
```

No change to `scripts/apply_hotel_catalogue_expansion.py`'s logic — it already handled a partially-ready candidate file correctly (per its `BLOCKED_MISSING_REQUIRED_FIELD` path from the previous pass), so pointing it at the updated data required no code change, per the task's "if necessary" qualifier. No `hotels_master.csv` edit. No Flutter file touched.

## 21. Exact remote dry-run command that WOULD be used next — DO NOT RUN IT

```
export DATABASE_URL='<production connection string>'
python3 scripts/apply_hotel_catalogue_expansion.py --target remote --dry-run
```

**Not run.** Requires both prerequisite migrations to already be applied to the remote target first (neither has been — local only). Per explicit instruction, no partial deployment (e.g. "88 of 94") was decided or executed — that decision is reserved for review.

---

## Guardrail confirmation

No production connection was made. No remote SQL was run. Neither migration was applied anywhere but the local Supabase instance. `supabase db push` was never invoked. No file under `lib/` was modified. `hotels_master.csv` was not edited. Nothing was committed. Nothing was pushed.
