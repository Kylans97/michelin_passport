# Hotel Catalogue Expansion — End-State Report (Union Inclusion Rule)

**Status: research and data preparation only. Review checkpoint. Not deployed, not migrated, not committed, not pushed.**

Inclusion rule, as decided: a hotel qualifies for Chasing Stars if it holds 1-3 MICHELIN Keys, OR has appeared in The World's 50 Best Hotels (2023-2025), OR both. Every number below is computed directly from the underlying CSVs in this pass — `candidate_catalogue_union.csv` and `ranking_history_all_routes.csv` — not carried over from earlier estimates.

---

## 1. Total unique hotels qualifying via MICHELIN Keys

**699** — the existing 687-hotel catalogue (unchanged, all Key-qualifying) plus the 12 hotels identified in the earlier Phase 1 pass, all of which hold a confirmed MICHELIN Key (9 with an exact 1/2/3-Key tier confirmed, 3 with Key-program presence confirmed but exact tier still unresolved — see §7).

## 2. Total unique hotels qualifying via World's 50 Best

**115** — 21 hotels already present in the catalogue and already matched to a W50B ranking (from the earlier matching pass), plus the 12 Phase 1 hotels, plus 82 newly-identified hotels from countries the catalogue didn't cover at all.

## 3. Overlap between the two routes

**33** — the 21 already-matched existing-catalogue hotels plus the 12 Phase 1 hotels. Every one of these 33 has both a MICHELIN Key and a World's 50 Best appearance, and remains one hotel with both award histories preserved, per the deduplication requirement.

## 4. World's 50 Best-qualified hotels with MICHELIN Key status unknown

**82.** *(Corrected framing — see the production-readiness pass that follows this report, `phase8_production_readiness_report.md`: the original heading here, "World's 50 Best-only hotels, with no MICHELIN Key," overstated what was actually established. These 82 hotels were never individually checked against a MICHELIN Key programme — their correct state is `michelin_keys = UNKNOWN`, not "confirmed zero Keys." A later pass resolved Key status for a meaningful subset of them; see `phase8_production_readiness_report.md` §3 for the outcome.)* Each is a `NEW_HIGH_CONFIDENCE` candidate through the World's 50 Best route alone, with `michelin_keys` left explicitly `NULL`/unresolved rather than assumed zero or guessed at any tier. `NULL` here means "no confirmed Key value currently stored" — never "zero Keys" — and this must not delay catalogue inclusion.

## 5. Total unique hotels in the proposed expanded catalogue

**781** = 687 (existing) + 12 (Phase 1, dual-route) + 82 (new World's 50 Best-only). Verified by direct row count in `candidate_catalogue_union.csv`.

| inclusion_reason | count |
|---|---|
| `michelin_key` | 666 |
| `worlds_50_best` | 82 |
| `michelin_key_and_worlds_50_best` | 33 |
| **Total** | **781** |

## 6. Countries covered after expansion

**47** — the existing 21 countries, plus 26 newly-covered countries/territories carried entirely by the 82 World's 50 Best-only hotels:

United States (11), United Kingdom (9), France (8), Mexico (7), Thailand (7), Hong Kong (5), India (5), Australia (4), Indonesia (3), Maldives (3), United Arab Emirates (3), Morocco (2), South Africa (2), China (1), Costa Rica (1), Fiji (1), French Polynesia (1), Greece (1), Malaysia (1), New Zealand (1), Oman (1), Peru (1), Sri Lanka (1), St. Barthélemy (1), Sweden (1), Turkey (1).

*(This reconciled, hotel-level count of 82/26 supersedes the earlier country-level estimate of "88 hotels" from the prior report — that number was a coarser approximation before the actual hotel-by-hotel identity work in this pass; the refinement is expected and the new number is the one to build from.)*

## 7. Unresolved / ambiguous hotels

- **Exact Key tier unresolved (3):** Hoshinoya Tokyo, Six Senses Ibiza, The Tokyo EDITION Toranomon. All 3 are confirmed present in MICHELIN's Key selection, so they correctly carry `inclusion_reason = michelin_key_and_worlds_50_best` — but the numeric 1/2/3 value cannot be written to `michelin_keys` until the exact tier is confirmed. Left as text placeholders in `candidate_catalogue_union.csv`, not guessed.
- **Country-level Key coverage still unresolved for Oman and Sweden** (carried over from the prior report). This does not block either country's hotel from entering the catalogue under the World's 50 Best route — it only means we don't yet know whether Six Senses Zighy Bay (Oman) or Ett Hem (Sweden) might *also* hold a Key.
- **Borgo Santandrea's city on record** — "Amalfi" (W50B source) vs. "Conca dei Marini" (MICHELIN's own listed city) — unresolved, carried over from the prior report.
- **Malaysia has no MICHELIN Key programme presence at all**, per the October 2025 global launch coverage explicitly not naming it — The Datai enters solely via the World's 50 Best route; there is nothing to reconcile it against. This is a *confirmed absence*, not an unknown — it rests on evidence the programme doesn't exist there yet, not on a failed search for this one hotel.
- No hotel-identity collisions were found in the final 781-row union (checked directly: zero duplicate `name + city` pairs across the full candidate set).

## 8. Exact schema changes required to support Key-less hotels

Full detail: `phase6_flutter_key_nullability_audit.md`. Summary:

| Layer | Change | Status |
|---|---|---|
| `public.hotels.michelin_keys` | Drop `NOT NULL`; `CHECK` unchanged | Migration **prepared**, not applied: `supabase/migrations/20260807150000_hotel_michelin_keys_nullable.sql` |
| `hotels_country_keys_idx`, `hotels_full` view | — | No change needed (verified) |
| `Hotel.michelinKeys` (Dart) | `final int` → `final int?`; remove dead `?? 0` fallback | Not implemented |
| 5 display call sites (`hotel_hero`, `passport_hotel_card`, `hotel_tile`, `hotel_ranking_card`, `add_stay_sheet`) | Null-guard `KeyRow`/`keysAtVisit` | Not implemented |
| `HotelKeysFilter` (Explore) | New case mirroring `RestaurantAwardFilter.worlds50Best` | Not implemented |
| `HotelRepository.search()` | New independent "has W50B history" filter path | Not implemented |
| `award_history`, `AwardHistoryRepository`, Wishlist, Map | — | **Already hotel-ready, confirmed, no change needed** |
| `worlds_50_best_hotels` table (ranking history storage) | Exact DDL designed in `phase4_worlds_50_best_hotels_schema.md` | Design only, not written as a migration file — outside this pass's scope (which was specifically the `michelin_keys` nullability migration) |

## 9. Exact data / import files ready for the next deployment step

```
supabase/migrations/
  20260807150000_hotel_michelin_keys_nullable.sql   — NEW, prepared, NOT applied

supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
  phase6_flutter_key_nullability_audit.md           — NEW
  phase7_end_state_report.md                        — NEW (this file)
  v2_union_catalogue/
    candidate_catalogue_union.csv                   — NEW, 781 rows
    ranking_history_all_routes.csv                  — NEW, 200 rows (every year/rank
                                                        appearance preserved, for all
                                                        115 World's-50-Best-route hotels)
```

`candidate_catalogue_union.csv` columns: `candidate_id, name, city, country, inclusion_reason, michelin_keys, key_confidence, w50b_appearances, status`. `candidate_id` is the existing `hotel_code` for the 687 already-catalogued hotels, and a new `p1_XX` / `p2_XXX` id for the 94 new candidates — deliberately not a `hotel_code`, since none of these have been assigned one or imported yet.

`ranking_history_all_routes.csv` columns: `catalogue_hotel_code, candidate_id, canonical_name, canonical_city, canonical_country, route, year, rank, list_type, source, confidence, evidence` — every one of the 200 raw World's 50 Best row-appearances (2023+2024+2025 combined) is preserved and traceable to exactly one of the 115 distinct hotels, satisfying the "preserve complete ranking history" requirement without collapsing multi-year data into a single row.

**Neither file has been imported.** No `hotels_master.csv` row was added, no `hotel_code` was assigned, no production connection was made, nothing was committed or pushed. This is the review checkpoint the task asked to stop at.
