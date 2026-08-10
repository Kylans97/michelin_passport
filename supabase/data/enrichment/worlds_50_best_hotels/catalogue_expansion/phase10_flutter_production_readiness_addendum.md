# Flutter Nullability Audit — Production-Readiness Addendum

**Status: read-only inspection. No file under `lib/` was modified. This addendum extends `phase6_flutter_key_nullability_audit.md` with the specific feature areas and product-behavior requirements from this task; it does not repeat what that file already covers correctly.**

Uncommitted, unrelated design work is in progress under `lib/` this session (visible in `git status`: `app_theme.dart`, `hotel_tile.dart`, several new `core/theme` and `core/widgets` files, etc.). None of it was read for this audit beyond what grep needed to locate `michelinKeys` references, and none of it was touched.

---

## One correction to phase6's own call-site list

Phase6 listed `add_stay_sheet.dart:132` (`keysAtVisit: widget.hotel.michelinKeys`) among the sites needing a null-guard. Re-checked against `lib/models/visit.dart:61` — **`Visit.keysAtVisit` is already `final int?`**. Once `Hotel.michelinKeys` becomes `int?`, this assignment is nullable-to-nullable and type-checks with no change required. It does not belong on the "needs a guard" list; only the 5 `KeyRow`-based display sites do, because `KeyRow.count` (`lib/core/widgets/key_row.dart:8`) is `final int`, non-nullable, and `List.generate(count, ...)` throws on null.

## Per-area findings

**Hotel Detail** (`hotel_hero.dart`) — covered in phase6 (display call site #1). No new finding.

**Explore** — `hotel_tile.dart` (display call site #3) covered. Confirmed separately: `HotelRepository.search()` (`lib/data/repositories/hotel_repository.dart:56-79`) only adds `builder.eq('michelin_keys', keys)` when the caller passes an explicit `keys` filter — the default, unfiltered search and `getAll()` never filter on `michelin_keys` at all. **A NULL-Key hotel is included in generic/unfiltered Explore results today, and will continue to be after the migration, with no code change required.** It is excluded only from a *specific* Key-count filter (1/2/3 Keys) — correctly, since it doesn't hold that specific value — and would need the new "has World's 50 Best history" filter (not yet built, see below) to be independent of Keys, exactly as `RestaurantRepository.search()`'s `worlds50BestOnly` already is independent of `stars`.

**Rankings** — `hotel_ranking_card.dart` (display call site #4) covered. Separately confirmed: `RankingsView`'s sort (`lib/features/rankings/rankings_view_model.dart:64-73`) orders by the user's own `averageScore` / `ratedVisitCount` / recency / name — never by `michelinKeys`. **No sort-stability or null-ordering risk exists here**; a NULL-Key hotel sorts exactly like any other hotel, by the user's own rating data.

**Wishlist** — confirmed again, no `michelinKeys` reference anywhere in `lib/features/wishlist/`. Entity-agnostic by its polymorphic `entity_type`/`entity_id` design. **Nothing to change; a NULL-Key hotel cannot be excluded by something that never looks at the Key value.**

**Map** — confirmed again, no `michelinKeys` reference anywhere in `lib/features/map/` or `lib/data/repositories/map_repository.dart`. Coordinates drive map placement, independent of award status. **Nothing to change.**

**Stay Detail** (`lib/features/stays/stay_detail_screen.dart`) — **already fully null-safe, no change needed.** Line 136, `final keys = stay.keysAtVisit;`, already operates on the nullable `Visit.keysAtVisit` field and is presumably rendered conditionally further down — this screen was already built for a hotel stay with no recorded Key value (e.g., a stay logged before Keys existed at all), which is the same shape of "no value" a NULL-Key W50B hotel will have going forward.

**Key filters** (`HotelKeysFilter`, `lib/features/explore/models/explore_filters.dart:49-65`) — covered in phase6: needs a 5th case. No new finding.

**World's 50 Best Hotels filters — does not exist yet, anywhere.** Unlike Keys, there is currently no `HotelWorlds50BestFilter` concept in the codebase at all — this isn't a nullability fix, it's new filter surface that needs designing from scratch once `worlds_50_best_hotels` (the table designed in `phase4_worlds_50_best_hotels_schema.md` / migrated in `20260807160000_create_worlds_50_best_hotels.sql`) has data to query against. The restaurant side's `RestaurantAwardFilter.worlds50Best` is the pattern to follow, not copy verbatim — hotels have no `hall_of_fame` list_type to accommodate.

**Hotel Award History** — confirmed again in phase6: `award_history` and `AwardHistoryRepository.loadMichelinHistory()` are already hotel-ready, no change needed. Still true. **A hotel World's 50 Best history screen is separate** (needs a hotel-side sibling to `loadWorlds50BestHistory(String restaurantId)`, which is currently hardcoded restaurant-only) — new work, not a nullability fix, tracked since the original World's 50 Best Hotels report.

## The 5 explicit product-behavior requirements, checked against current code

| Requirement | Current state |
|---|---|
| Must render normally | Not yet — depends on the 5 `KeyRow` call sites being null-guarded (phase6) and the model going nullable. Today it would crash, not render. |
| Must NOT show "0 Keys" | Depends on removing the dead `?? 0` fallback in `Hotel.fromJson` (phase6) before the DB migration ships — confirmed still present, unchanged. |
| Must NOT show an empty `KeyRow` | Depends on the same 5 call sites gaining a guard — an unguarded `KeyRow(count: null, ...)` throws, it doesn't render empty, so this is actually a crash risk today, not a cosmetic one. |
| Must NOT disappear from generic hotel searches | **Already true, confirmed above** — no code change needed for the *default* search path. |
| Must NOT crash sorting/filtering | **Already true for Rankings** (confirmed above, sorts on user data, not Keys) and **already true for the default Explore search** (ordered by `name`). Would need to be true for the *new* W50B filter once it's built, since it doesn't exist yet to check. |
| Must NOT be excluded from Wishlist or Map | **Already true, confirmed above** — neither feature reads `michelinKeys` at all. |
| Must NOT be described as having no Michelin recognition unless actually known | Not a code question today — no copy currently renders any Key-status string for a hotel beyond the `KeyRow` icon count and the `hotel_tile.dart` interpolation area. This is a copy/design requirement for whoever implements the null-guards, not something this audit can mark done or not-done in advance. Flagged here so it isn't lost. |

## Net picture

Of the 3 features named that weren't in phase6's scope (Wishlist, Map, Stay Detail), **all 3 already behave correctly for a NULL-Key hotel with no code change** — confirmed by direct inspection, not assumed. The two genuinely new pieces of work this addendum surfaces are: the World's 50 Best Hotels filter (doesn't exist yet, is new surface, not a nullability fix) and the hotel-side World's 50 Best history screen/repository method (same). Both are scoped to the `worlds_50_best_hotels` migration existing with data in it — appropriately out of scope for this research-and-preparation pass.
