# Flutter / Model / Query Assumptions Requiring `michelin_keys` Nullability

**Status: audit only. Nothing in `lib/` changed. Re-verified against the current working tree (not the earlier Phase 3 pass) to catch any drift.**

The inclusion rule is now decided: a hotel qualifies via Michelin Keys, World's 50 Best, or both. `michelin_keys` will eventually need to hold NULL. This is the exact list of what breaks, or must change, before that's safe — confirmed by direct grep against the current codebase, not carried over unchecked from the earlier Phase 3 review.

---

## Database

| Object | Current state | Required change |
|---|---|---|
| `public.hotels.michelin_keys` | `smallint not null check (michelin_keys between 1 and 3)` (`20260805141519_production_schema_v1.sql:126`) | Drop `NOT NULL`. The `CHECK` needs no change — it already only evaluates non-null values. Migration prepared: `20260807150000_hotel_michelin_keys_nullable.sql`. **Not applied.** |
| `hotels_country_keys_idx` (`country_code, michelin_keys`) | btree index | No change needed — Postgres indexes NULLs without issue; they simply never match an equality lookup, which is the correct behavior for "no Key." |
| `public.hotels_full` view | `select h.*, ...` | No change needed — a `SELECT *`-based view inherits the underlying column's new nullability automatically. |

## Dart model

| File | Current state | Required change |
|---|---|---|
| `lib/models/hotel.dart:23` | `final int michelinKeys;` | → `final int? michelinKeys;` |
| `lib/models/hotel.dart:64` | `michelinKeys: (json['michelin_keys'] as num?)?.toInt() ?? 0,` | Remove the `?? 0` fallback. Today it's dead code (the DB guarantees non-null). Left in place, it would silently turn a real "no Key" hotel into a fake zero-Key hotel the moment the DB column goes nullable — exactly the bug class `DATABASE_ARCHITECTURE.md` already fought and won on the restaurant side (`michelin_stars` is nullable, never zero). |

## Display call sites — confirmed via `grep -rn "michelinKeys" lib/` against the current tree

5 sites read `hotel.michelinKeys` directly, all via the `KeyRow` widget:

1. `lib/features/hotels/widgets/hotel_hero.dart:14` — `KeyRow(count: hotel.michelinKeys, size: 18)`
2. `lib/features/passport/widgets/passport_hotel_card.dart:93` — `KeyRow(count: hotel.michelinKeys, size: 14)`
3. `lib/features/explore/widgets/hotel_tile.dart:65` — `KeyRow(count: hotel.michelinKeys, size: 11)`
4. `lib/features/rankings/widgets/hotel_ranking_card.dart:91` — `KeyRow(count: hotel.michelinKeys, size: 11)`
5. `lib/features/stays/widgets/add_stay_sheet.dart:132` — `keysAtVisit: widget.hotel.michelinKeys` (target field `visits.keys_at_visit smallint` is already nullable in the DB — only the source-side Dart type needs to flow through)

`lib/core/widgets/key_row.dart:8` — `final int count;`, then `List.generate(count, ...)` at line 18. This crashes on a null `count`. Every one of the 5 call sites above needs a null-guard before reaching `KeyRow` — render nothing, or a World's 50 Best badge in its place, once the design for a Key-less hotel's card is decided (not part of this research pass).

*(Correction from the earlier Phase 3 pass: that report also flagged a `'${hotel.michelinKeys}🔑'` string interpolation in `hotel_tile.dart`. Re-checked directly against the current file — that interpolation is not present; the file's only `michelinKeys` reference is the `KeyRow` call above. Concurrent, uncommitted work on `hotel_tile.dart` and several other hotel/restaurant widgets is visible in `git status` — noted at the end of this report — and may be why the earlier note no longer matches. This audit reflects what the file actually contains right now.)*

## Explore filters

`lib/features/explore/models/explore_filters.dart`:
- `HotelKeysFilter` (line 49): currently `all` / `oneKey` / `twoKeys` / `threeKeys`, each mapping to an `int? keysParam` (line 62-65).
- The restaurant side already has the exact pattern needed: `RestaurantAwardFilter.worlds50Best` (line 22) with `isWorlds50Best` (line 43), applied independently of `stars`.
- **Required change:** add a 5th `HotelKeysFilter` case (or a parallel independent filter, matching whichever shape `RestaurantAwardFilter` uses) so "has World's 50 Best history" can be selected regardless of Key count, including zero/null Keys.

## Repository / query layer

`lib/data/repositories/hotel_repository.dart`:
- Line 18 — `hotelFullColumns` selects `michelin_keys` directly; no change needed, a nullable column selects the same way.
- Line 73 — `builder.eq('michelin_keys', keys)` is the only Key-based filter today. **Required change:** an additional, independent filter path for "has World's 50 Best history," mirroring how `RestaurantRepository.search()` already applies `worlds50BestOnly` independently of `stars`.

## Already hotel-ready — confirmed, no change needed

- `public.award_history` — already polymorphic (`entity_type`/`entity_id`/`award_type`), already accepts `'michelin_keys'` as an `award_type` value (`20260805141519_production_schema_v1.sql:201`).
- `lib/data/repositories/award_history_repository.dart` — `loadMichelinHistory({required entityType, ...})` already branches on `entityType == 'hotel'` to resolve the Key award type; the code comment states this was built with a future hotel Award History screen in mind.
- Wishlist and Map — no direct `michelinKeys` reference found in either (`grep -rn "michelinKeys" lib/features/wishlist lib/features/map` returns nothing).

## Not yet built — needs its own migration if/when this ships

- A `worlds_50_best_hotels` table to store ranking history for hotels (design and exact DDL already produced in `phase4_worlds_50_best_hotels_schema.md` — illustrative only, not written as a migration file; out of scope for this pass, which was scoped specifically to `michelin_keys` nullability).
- `hotels_full`'s equivalent of `restaurants_full.worlds_50_best_rank` — depends on the table above existing first.

---

## Net effect

The migration in `20260807150000_hotel_michelin_keys_nullable.sql` is safe to write and review today, but should not be applied until at minimum: the Dart model field is nullable, the 5 display call sites are null-guarded, and the two filter/query additions above exist — otherwise a null Key reaching a still-non-nullable `Hotel.fromJson` or a still-unguarded `KeyRow` would crash the app the moment one Key-less hotel is inserted.
