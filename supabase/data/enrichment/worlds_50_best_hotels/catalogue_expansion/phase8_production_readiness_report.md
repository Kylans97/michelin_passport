# Hotel Catalogue Expansion — Production-Readiness Report

**Status: review checkpoint. No production connection, no remote SQL, no migration applied anywhere, no Flutter change, no commit, no push.**

The inclusion rule is decided: `qualifies_for_hotel_catalogue = has_michelin_key OR has_worlds_50_best_hotels_history`. This report is the final preparation pass before deployment — exact hotel_codes, corrected Key semantics, individually-researched fields for all 94 new candidates, a finalized schema, a tested deployment mechanism, and exhaustive validation. It stops at the review checkpoint the task asked for.

---

## 1–6. Exact final counts

| Metric | Count |
|---|---|
| Total unique hotels in the proposed catalogue | **781** |
| Existing hotels (unchanged) | **687** |
| Genuinely new hotel candidates | **94** |
| Distinct World's 50 Best-qualified hotels | **115** |
| Ranking-history rows (2023–2025, all preserved) | **200** |
| Hotels qualifying via MICHELIN Keys | **765** (687 existing + 78 new dual-route) |
| Overlap (both routes) | **99** (21 existing already-matched + 78 new dual-route) |
| New hotels with a **confirmed** numeric Key tier | **78** |
| New hotels **confirmed absent** from their market's Key programme | **2** (Desa Potato Head, The Datai) |
| New hotels with Key status genuinely **unknown** | **14** |
| New countries added to the catalogue | **25** (not 26 — see §7's correction) |

**Arithmetic reconciliation:** Key-qualified (765) + W50B-qualified (115) − overlap (99) = **781**. Verified directly against the CSVs, not asserted.

## 7. All unresolved hotels / fields

**14 hotels with genuinely unknown Key status** (Guide-listed in most cases, tier or presence not confirmable from available evidence):

| Hotel | Note |
|---|---|
| Hoshinoya Tokyo | Guide page exists; michelinkeyhotels.com labels it "Selected," not a Key tier |
| Six Senses Ibiza | Guide page exists, tier not recoverable |
| The Tokyo EDITION Toranomon | Not named in Michelin's own Tokyo roundup (non-exhaustive — not proof of absence) |
| Mandarin Oriental Qianmen | China's 2025 Key launch confirmed (64 hotels); this specific property not individually confirmed |
| Four Seasons Tamarindo | See country correction below; no Guide listing found either way |
| Kokomo Private Island | Fiji has Oceania-rollout Key coverage; this specific hotel not confirmed |
| Soneva Secret | Guide page confirms "Key Selected," exact tier not surfaced |
| **Rosewood Mayakoba** | **Never individually researched this pass — a transcription gap in batch assignment, corrected during validation (see below); genuinely unresolved, not guessed** |
| Singita – Kruger National Park | **Identity ambiguous** — the candidate doesn't specify Lebombo vs. Sweni, two separate Guide listings with likely different tiers |
| Eden Rock | No Guide listing page found; not confirmed absent, genuinely unresolved |
| Maçakızı | Guide page exists (its restaurant is separately 1-Starred); no hotel-level Key tier found |
| Jumeirah Marsa Al Arab | Guide page exists, absent from Michelin's own Dubai Key-hotels article — likely too new (opened March 2025) but not a stated exclusion |
| Equinox Hotel New York | Guide page confirmed, no tier text surfaced |
| San Ysidro Ranch | Guide page exists; only its restaurant's recognition found, not the hotel's |

**2 hotels confirmed absent** from their market's Key selection (a real negative, not an unknown): Desa Potato Head (Bali — excluded from Indonesia's 33-hotel list), The Datai (Langkawi — excluded from Malaysia's inaugural 4-hotel list, see country correction below).

**Data-quality correction found this pass:** the original World's 50 Best 2025 source lists "Four Seasons Tamarindo" under Costa Rica. Direct verification against the hotel's own website confirms it is actually in La Manzanilla, **Jalisco, Mexico** — likely an editorial mix-up in the source between the Four Seasons Tamarindo brand and the unrelated Costa Rican beach town of the same name (Four Seasons' actual Costa Rica property is the separate Peninsula Papagayo resort). **Corrected**: this hotel is now filed under Mexico. This removes Costa Rica from the new-country list entirely (it had no other candidate) and is why the count is 25 new countries, not 26.

**Country-level Key coverage corrections found this pass:**
- **Malaysia** joined the MICHELIN Key programme in October 2025 (4 hotels: Four Seasons Resort Langkawi, Four Seasons Kuala Lumpur, Else Kuala Lumpur, The RuMa). The earlier report's claim of "no programme at all" is now outdated. The Datai is confirmed specifically excluded from that list.
- **Oman and Sweden** — previously unresolved — are now **confirmed covered**, both from the 8–9 October 2025 global launch. Six Senses Zighy Bay (Oman) and Ett Hem (Sweden) are each individually confirmed with 1 Key.

**A process error found and fixed during validation:** while transcribing the 82 new-country candidates into 4 research-agent prompts, a hotel ("Rosewood Mayakoba") was dropped at the batch B→C boundary, shifting every subsequent `candidate_id` label in batches C and D down by one relative to the authoritative `candidate_catalogue_union.csv`. The researched *content* (names, websites, Key findings) was correct throughout — only the id printed next to it in the raw batch files was wrong, which would have silently attached the wrong hotel's data to the wrong `hotel_code` had it gone uncaught. Caught by cross-referencing a spot-check against the source CSV during dataset validation, before any file was finalized. Fixed by re-matching every researched hotel to its true `candidate_id` by name against the ground-truth CSV, not by trusting the batch labels. `research_batch_C_morocco_uae.md` and `research_batch_D_uk_us.md` carry correction notices; `new_hotels_for_deployment.csv` is the corrected, authoritative source. Rosewood Mayakoba itself — the hotel that caused the shift — was never actually researched by any batch, and is correctly `unknown` in the final dataset rather than silently dropped.

## 5. hotel_code strategy used for the 94 new hotels

**`hotel_%03d`, continuing the existing sequence exactly.** `DATABASE_ARCHITECTURE.md` §11 documents `hotel_code` as a frozen external key, `hotel_` plus 3 digits — confirmed by direct inspection that the existing 687 codes run `hotel_01` through `hotel_687` with no gaps and no duplicates (values 1–99 are 2-digit, e.g. `hotel_01`; values 100+ are the documented 3-digit form). The 94 new hotels take the next 94 sequential values, unpadded beyond 3 digits like every code ≥100 already is: **`hotel_688` through `hotel_781`**, assigned deterministically (12 Phase-1 hotels first, alphabetically, then the 82 new-country hotels, alphabetically by country then name). No collision, no invented convention.

## 6 / 7. Schema changes prepared

| Change | File | Status |
|---|---|---|
| `hotels.michelin_keys` → nullable | `supabase/migrations/20260807150000_hotel_michelin_keys_nullable.sql` | Finalized, syntax-verified, **applied to local only** |
| `public.worlds_50_best_hotels` table | `supabase/migrations/20260807160000_create_worlds_50_best_hotels.sql` | Finalized, syntax-verified, **applied to local only** |

**Objects checked for a `NOT NULL michelin_keys` assumption** (indexes, views, functions, triggers, RLS policies, import scripts) — confirmed via direct migration-file inspection, not assumed: `hotels_country_keys_idx` (btree index — nullable columns index fine, unaffected), `hotels_full` (`select h.*` — inherits nullability automatically), no functions/triggers/RLS reference `michelin_keys` at all. `import_catalogue.py` (the empty-DB importer) is untouched and out of scope — it's for a different workflow entirely and was never going to run against a populated database.

**One dependency the original conceptual order didn't anticipate, found by inspecting the actual schema**: `hotels.address` and `hotels.location` are both `NOT NULL` (not just `michelin_keys`). See `phase9_deployment_order.md` for the full corrected 6-step order — the short version: **0 of the 94 new hotels can be inserted today**, regardless of how well-researched their Key status is, because none has independently verified coordinates, and this script will never fabricate them.

## 7. `worlds_50_best_hotels` final schema

```sql
create table public.worlds_50_best_hotels (
  id         uuid primary key default gen_random_uuid(),
  hotel_id   uuid not null references public.hotels(id) on delete cascade,
  year       smallint not null,
  rank       smallint,
  list_type  text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100')),
  unique (hotel_id, year)
);

create unique index worlds_50_best_hotels_year_rank_uidx
  on public.worlds_50_best_hotels (year, rank)
  where rank is not null;

create index worlds_50_best_hotels_hotel_idx
  on public.worlds_50_best_hotels (hotel_id);
```

No Hall of Fame `list_type` — confirmed, again, that none exists for hotels. `public.worlds_50_best` (restaurants) is completely untouched by this migration.

## 8. Deployment script behaviour

`scripts/apply_hotel_catalogue_expansion.py` — sibling to `apply_catalogue_enrichment.py`, same transaction/rollback/dry-run discipline, different job: it's the only one of the three catalogue scripts that ever inserts a new `hotels` row.

- Resolves existing hotels by `hotel_code`.
- Classifies each of the 94 candidates: `INSERT` (has every NOT NULL field), `BLOCKED_MISSING_REQUIRED_FIELD` (missing address/lat/long — reported, never fabricated), `ALREADY_PRESENT` (idempotent rerun, identical data), or `CONFLICT` (same `hotel_code`, different data — stops the deployment).
- Resolves/inserts `countries`/`cities` rows automatically, only for a hotel actually being inserted this run — never speculatively.
- Classifies each of the 200 ranking rows: `INSERT`, `ALREADY_PRESENT`, `CONFLICT`, or `BLOCKED_DEPENDENT_HOTEL` (its hotel wasn't inserted this run — reported, never silently dropped, never inserted with a fabricated `hotel_id`).
- One transaction. `--dry-run` runs the real classify/apply/validate path, then unconditionally rolls back. A real run commits only if every post-deploy check passes.
- Remote requires `--confirm-remote-hotel-expansion APPLY-HOTEL-CATALOGUE-EXPANSION` exactly.
- Refuses to run at all if the target hasn't already had both migrations applied (`check_target_schema_ready`) — it does not apply them itself.

**A real bug found and fixed by testing, not by inspection:** the first version classified a hotel whose `hotel_code` already exists in production as an unconditional `CONFLICT` — correct for a genuinely different candidate colliding with a code, but wrong for the ordinary idempotent-rerun case (a hotel this script already inserted, run again against the same file), which would have made every rerun after a real deployment fail outright. Fixed to compare the existing row's name/keys/city against the candidate: identical → `ALREADY_PRESENT`; different → `CONFLICT`. Verified with a dedicated test (§13).

## 9. Exact expected production write counts — today, against the real 94-hotel dataset

- **0** new `hotels` rows (all 94 `BLOCKED_MISSING_REQUIRED_FIELD` — no verified address/coordinates exists for any of them yet).
- **34** new `worlds_50_best_hotels` rows (ranking history for the 21 hotels already in the catalogue — resolvable via existing `hotel_code`, independent of the 94 new hotels).
- **166** ranking rows `BLOCKED_DEPENDENT_HOTEL` (their hotel isn't in production yet — reported, not dropped, not force-inserted).
- **0** new `countries`/`cities` rows (none needed, since 0 hotels are being inserted).

This is the single most important finding of this pass: **Key-status research doesn't unblock deployment — coordinates research does.** 78 of 94 hotels now have a confirmed Key tier, but that has no bearing on insertability, because `hotels.address`/`.location` are the actual gate, and this pass deliberately never touched geocoding (per "never guess coordinates").

## 10–13. Local testing results

All run against local Supabase (container already up, DB pre-populated with the real 687-hotel/774-restaurant baseline — confirmed via direct query before testing began).

1. **Migration application** — both migrations applied for real (committed) to local. `michelin_keys` confirmed nullable; `worlds_50_best_hotels` confirmed present.
2. **Dry-run (real data)** — classified 94 `BLOCKED_MISSING_REQUIRED_FIELD`, 34 ranking `INSERT`, 166 `BLOCKED_DEPENDENT_HOTEL`; all 10 post-deploy checks passed; rolled back, 0 rows written. Matches §9 exactly.
3. **Real run (real data)** — same classification, committed: **34 `worlds_50_best_hotels` rows now exist in local**, 687 hotels unchanged. Local DB currently reflects exactly what a real deployment would do today.
4. **Second dry-run / second real run (idempotency)** — reclassified the same 34 rows as `ALREADY_PRESENT`, applied 0, all checks passed, both a repeat dry-run and a repeat real run are safe no-ops.
5. **Conflict / rollback** — a dedicated synthetic-fixture test (clearly-labeled fake hotels, never written to the real candidate files, cleaned up after) proved: a real insert of a Key hotel *and* a NULL-Key W50B hotel both succeed and commit; the NULL-Key hotel's `michelin_keys` is confirmed `NULL` in the database (never `0`) and its `worlds_50_best_hotels` row is retained; a second pass against the same fixtures is idempotent; a deliberately conflicting ranking row (same hotel/year, different rank) is correctly classified `CONFLICT` and a rollback leaves the prior data completely untouched; a hotel-level conflict (same `hotel_code`, different Key value) is also correctly detected. This is also where the `ALREADY_PRESENT`-vs-`CONFLICT` bug in §8 was found and fixed.

Local DB state after this pass: 687 hotels (unchanged), 34 `worlds_50_best_hotels` rows (from the real run in step 3), no leftover test fixtures (verified — 0 `test_fixture_%` rows remain).

## 14. Invariant validation results

14/14 automated checks pass against the final dataset (§1–6's numbers, duplicate `hotel_code`/identity/ranking-row checks, every ranking row resolves to exactly one hotel, every new hotel has ≥1 qualifying route, no `michelin_keys = 0` anywhere, arithmetic reconciliation). Plus, from the local deployment runs themselves: existing 687 hotels' Keys/address/place_id/location unchanged, `hotel_restaurants` unchanged, existing current `award_history` rows unchanged — confirmed by snapshot comparison, not assumed.

## 15. Flutter nullability impact — read only

Full detail: `phase6_flutter_key_nullability_audit.md` (original) + `phase10_flutter_production_readiness_addendum.md` (this pass — corrects one item, confirms Wishlist/Map/Stay Detail/Rankings-sort already behave correctly for a NULL-Key hotel with zero code changes, and flags that a World's 50 Best Hotels filter doesn't exist yet anywhere in the app). No file under `lib/` was read beyond what grep needed, and none was modified. Unrelated, uncommitted design work is visible in `lib/` this session (`git status`) and was left completely untouched.

## 16. Exact files created / modified

```
supabase/migrations/
  20260807150000_hotel_michelin_keys_nullable.sql   — finalized, applied to LOCAL only
  20260807160000_create_worlds_50_best_hotels.sql   — NEW, applied to LOCAL only

scripts/
  apply_hotel_catalogue_expansion.py                — NEW deployment script

supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/
  phase7_end_state_report.md                        — corrected (NULL-Key semantics)
  phase8_production_readiness_report.md             — NEW (this file)
  phase9_deployment_order.md                        — NEW
  phase10_flutter_production_readiness_addendum.md  — NEW
  phase6_flutter_key_nullability_audit.md           — unchanged, still current
  v2_union_catalogue/
    new_hotels_for_deployment.csv                   — NEW, 94 rows (authoritative)
    new_worlds_50_best_hotels_rows.csv               — NEW, 200 rows (authoritative)
    research_batch_A_priority_australia_greece.md    — NEW
    research_batch_B_hongkong_mexico.md              — NEW
    research_batch_C_morocco_uae.md                  — NEW, correction notice added
    research_batch_D_uk_us.md                        — NEW, correction notice added
```

Nothing under `hotels_master.csv`, restaurant data, unrelated enrichment files, or `lib/` was created or modified.

## 17. Exact proposed remote dry-run command — DO NOT RUN IT

```
export DATABASE_URL='<production connection string>'
python3 scripts/apply_hotel_catalogue_expansion.py --target remote --dry-run
```

Not run in this task. Would require both migrations to already be applied to the remote target first (the script checks and refuses otherwise) — which are themselves not applied anywhere but local in this pass.

## 18. Confirmation

No production connection was made. No remote SQL was run. Neither migration was applied anywhere but the local Supabase instance. `supabase db push` was never invoked. No file under `lib/` was modified — the concurrent, uncommitted Flutter/design work visible in `git status` was left completely untouched. `hotels_master.csv`, `restaurants_master.csv`, and all previously-existing enrichment files outside this task's new files are unchanged. Nothing was committed. Nothing was pushed.
