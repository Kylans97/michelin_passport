# Flutter Nullable Keys + World's 50 Best Hotels — Implementation Report

**Status: review checkpoint. No production connection, no migration applied, no commit, no push.**

---

## 1. Files changed

**Modified (11):**
```
lib/models/hotel.dart
lib/data/repositories/hotel_repository.dart
lib/data/repositories/award_history_repository.dart
lib/features/explore/explore_screen.dart
lib/features/explore/models/explore_filters.dart
lib/features/explore/widgets/hotel_tile.dart
lib/features/hotels/hotel_detail_screen.dart
lib/features/hotels/widgets/hotel_hero.dart
lib/features/passport/widgets/passport_hotel_card.dart
lib/features/rankings/widgets/hotel_ranking_card.dart
lib/features/wishlist/widgets/wishlist_card.dart
```

**New (9):**
```
lib/models/worlds_50_best_hotel_entry.dart
lib/data/repositories/hotel_worlds_50_best_repository.dart
lib/features/hotels/award_history_screen.dart
lib/features/hotels/award_history/keys_history_view_model.dart
lib/features/hotels/award_history/worlds_50_best_hotels_history_view_model.dart
lib/features/hotels/widgets/hotel_awards_card.dart
lib/features/hotels/widgets/worlds_50_best_hotels_history_section.dart
supabase/migrations/20260807170000_expose_hotel_worlds_50_best_rank.sql
test/hotel_nullable_keys_test.dart
```

No file under `supabase/data/enrichment/` or `hotels_master.csv` was touched. No production connection was made.

## 2. Every nullable-Key call site found

Direct `grep -rn "\.michelinKeys" lib/` sweep, re-verified after all edits — **6 real usages, all now guarded**, plus one confirmed non-issue:

| Site | Before | After |
|---|---|---|
| `hotel_hero.dart:25` | `KeyRow(count: hotel.michelinKeys, ...)` | `hotel.hasMichelinKeys ? KeyRow(count: hotel.michelinKeys!, ...) : SizedBox.shrink()` |
| `passport_hotel_card.dart:93` | unconditional `KeyRow` | wrapped in `if (hotel.hasMichelinKeys)` |
| `hotel_tile.dart:62` | unconditional `KeyRow` | wrapped in `if (hotel.hasMichelinKeys)` |
| `hotel_ranking_card.dart:91` | unconditional `KeyRow` | wrapped in `if (hotel.hasMichelinKeys)` |
| `wishlist_card.dart:40` | unconditional `KeyRow` | ternary → `null`, mirroring the restaurant branch's existing `hasMichelinStar ? StarRow(...) : null` pattern |
| `add_stay_sheet.dart:132` | `keysAtVisit: widget.hotel.michelinKeys` | **unchanged** — `Visit.keysAtVisit`/`markHotelStay`'s param were already `int?`; nullable-to-nullable type-checks with no cast |

**A correction to the two prior audits** (`phase6_flutter_key_nullability_audit.md`, `phase10_flutter_production_readiness_addendum.md`): `wishlist_card.dart` was missed by both — it wasn't part of either's file list. Found this pass by re-running the grep fresh against current code rather than trusting the earlier lists. All 5 display call sites are now confirmed and fixed; nothing outstanding.

## 3. Hotel model change

`Hotel.michelinKeys`: `int` → `int?`. Removed the dead `?? 0` fallback in `Hotel.fromJson` — a real `NULL` now surfaces as `null`, never a fake `0`. Added `hasMichelinKeys` getter (mirrors `Restaurant.hasMichelinStar`) so every call site reads intent, not a raw null check. Added `worlds50BestRank`/`worlds50BestYear` (nullable, mirrors `Restaurant.worlds50BestRank`) and `isWorlds50Best` getter — see §11 for why these resolve to `null` for every hotel today regardless of real data.

## 4. Explore behavior

`HotelKeysFilter` gained a 5th case, `worlds50Best`, structurally identical to `RestaurantAwardFilter.worlds50Best` (independent of `keysParam`, own `isWorlds50Best` getter). `HotelRepository.search()` gained a `worlds50BestOnly` param: `.not('worlds_50_best_rank', 'is', null)` plus `.order('worlds_50_best_rank', ascending: true)` when active — exact mirror of `RestaurantRepository.search()`, including the same "`ascending` must be explicit" footgun note. `explore_filter_bar.dart` needed **zero changes** — it already iterates `HotelKeysFilter.values`, so the new chip appears automatically. `HotelTile` gained a `showWorlds50BestRank` prop and a gold rank line, shown whenever `hotel.isWorlds50Best` — **deliberately not conditioned on `hasMichelinKeys`**, unlike `RestaurantTile`'s equivalent line (which requires `hasMichelinStar` too) — a Key-less World's 50 Best hotel needs its recognition visible in the tile precisely because it has no Key badge competing for that space. Confirmed behavior: 2 Keys + W50B → appears under both filters; NULL Keys + W50B → appears only under World's 50 Best and "All Hotels", never under 1/2/3 Keys (the `eq('michelin_keys', keys)` filter naturally excludes a `NULL` row). Country filter composes with either unchanged — untouched code path.

## 5. Hotel Detail behavior

`HotelHero`: `awardBadge` is now conditional (`SizedBox.shrink()` when no Key), and gained an `extraBadges` `HeroBadge` for World's 50 Best rank (`"World's 50 Best · #4"`) — mirrors `RestaurantHero` exactly. Below the hero, new `HotelAwardsCard` (mirrors `RestaurantAwardsCard`) shows a Keys row (if present) and a `"#4 · 2025"` World's 50 Best row (if present) — omits itself entirely (`SizedBox.shrink()`) only in the currently-unreachable case of neither. A hotel with only World's 50 Best shows only that row, no "0 Keys" anywhere.

## 6. Hotel Award History behavior

New `HotelAwardHistoryScreen`, structurally identical to `AwardHistoryScreen` (restaurants): reuses `MichelinAwardTimeline`/`detectAwardTransitions` completely unchanged, with a new `keysTransitionLabel` formatter ("First Key", "Promoted to 2 Keys", "No longer holds a MICHELIN Key" — Keys/Key pluralization instead of stars). Every ranked World's 50 Best year is shown via new `HotelWorlds50BestHistorySection`, newest first, with the same "N appearances · Best ranking: #N" summary line. **No Hall of Fame block exists in this screen at all** — not hidden by a conditional, structurally absent: `HotelWorlds50BestHistorySummary` has no `hallOfFameYear` field for a screen to even reference. Wired into `HotelDetailScreen` via a new `_hasAwardHistory`/`_checkAwardHistory`/`AwardHistoryAction` triple, reusing the restaurant feature's existing `AwardHistoryAction` widget directly rather than duplicating it (it's a 6-line generic wrapper).

## 7. W50B repository/model architecture

`HotelWorlds50BestEntry` + `HotelWorlds50BestListType` (`worlds_50_best_hotel_entry.dart`) — a **new, separate** model from the restaurant `Worlds50BestHistoryEntry`/`Worlds50BestListType`, not a reuse. The restaurant enum carries a `hallOfFame` value with no hotel equivalent; giving hotels a type that can even represent Hall of Fame would leave a reachable nonsense state. The hotel enum has exactly 2 members, structurally. `AwardHistoryRepository` gained `loadWorlds50BestHotelsHistory(hotelId)` and `hasAnyHotelHistory(hotelId)`, querying `public.worlds_50_best_hotels` (hotel_id-keyed) — a fully separate table from `public.worlds_50_best` (restaurant_id-keyed, hard FK, cannot reference a hotel at all).

## 8. Rankings implementation/status

**Repository/view-model foundation only — no new screen or tab.** Built `HotelWorlds50BestRepository.getRanking({year, listType})`: queries `worlds_50_best_hotels` for one year/list_type, resolves real `Hotel` rows via `hotels_full` (so a tap could open the existing `HotelDetailScreen` directly, same as every other ranking card), sorted rank ascending. `availableYears = [2025, 2024, 2023]` — hardcoded to years actually researched, never computed as "current year," per the explicit guardrail against fabricating 2026 data.

**Why no UI slice:** inspected `RankingsScreen` — exactly 2 tabs exist, "My Rankings" (personal, `PersonalRankingsTab`) and "Community" (`CommunityRankingsTab`, backed by `public.restaurant_rankings` — **restaurant-only, user-generated average ratings, unrelated to any official award list**). Neither is the right home for an official, externally-curated World's 50 Best Hotels list: forcing it into "Community" would misrepresent what that tab already means (and that tab has no hotel equivalent at all today), and there's no third tab to add one to without a UI-structure decision beyond this pass's scope. Per the task's own explicit permission to scope this down rather than force a bad structure, this is exactly what was done — the data layer is complete and ready; the screen is a follow-up decision.

## 9. Stay-history null behavior

**No code change was needed.** `VisitedRepository.markHotelStay`/`_insertVisit` already declared `keysAtVisit` as `int?` and wrote it via `'keys_at_visit': ?keysAtVisit` (Dart's null-aware map-entry spread) — a null was always going to insert `NULL`, never `0`, even before this task. `add_stay_sheet.dart:132`'s `keysAtVisit: widget.hotel.michelinKeys` now passes a genuinely nullable value where the parameter was already nullable — confirmed by `flutter analyze` passing with zero errors and by test group G.

## 10. Wishlist/Passport/Map/Planning regression result

- **Wishlist** (`wishlist_card.dart`) — fixed (§2), now null-safe.
- **Passport** (`passport_hotel_card.dart`) — fixed (§2), now null-safe.
- **Map** (`venue_preview_sheet.dart`) — grep-confirmed zero `michelinKeys` references; only reads name/city/country. No change needed, no regression possible.
- **Planning** (`plan_venue_sheet.dart`) — grep-confirmed zero `michelinKeys` references; only reads `hotel.id`/`cityName`/`countryName`. No change needed.
- **Rankings card** (`hotel_ranking_card.dart`) — fixed (§2).

A synthetic null-Key `Hotel` was exercised through `HotelTile`, `HotelHero` (via `HotelAwardsCard`), `PassportHotelCard`'s logic, `HotelRankingCard`'s logic, and `WishlistCard`'s logic in `test/hotel_nullable_keys_test.dart` groups A–F — 18/18 tests pass, zero crashes, zero "0 Keys" text found (`find.text('0')` asserted empty in the relevant test).

## 11. Migration added

`20260807170000_expose_hotel_worlds_50_best_rank.sql` — additive `CREATE OR REPLACE VIEW` on `hotels_full`, adding `worlds_50_best_rank`/`worlds_50_best_year` (derived from a `left join` against `worlds_50_best_hotels` on the max ranked year, exact mirror of `restaurants_full`'s existing pattern, plus a `worlds_50_best_year` column restaurants_full doesn't have — needed here because Hotel Detail's award card explicitly shows the year, `"#4 · 2025"`). **A real ordering bug was caught and fixed before finalizing this file**: `CREATE OR REPLACE VIEW` fully replaces the view, it does not layer on top of a different migration's own `CREATE OR REPLACE VIEW` — since `20260807140000_add_venue_coordinates.sql` independently redefines the same view to add `latitude`/`longitude`, and the two migrations may apply in either order, my first draft would have silently dropped whichever ran first. Fixed by including both migrations' added columns in one `SELECT` list, so either application order converges on the same final view. Syntax- and correctness-verified in a rolled-back local transaction (confirmed all 27 expected columns present, including `latitude`/`longitude`/`worlds_50_best_rank`/`worlds_50_best_year` together) — **not applied**, matching every other migration in this workstream.

## 12. `flutter analyze` result

```
dart format lib/ test/   → 4 files reformatted, 141 unchanged
flutter analyze          → No issues found! (ran in 3.1s)
flutter test             → 18/18 passed
```

## 13. Exact remaining blocker before database remote dry-run

**`hotelFullColumns` does not request `worlds_50_best_rank`/`worlds_50_best_year` yet, and cannot until three things are true on the target database, in order:**

1. `20260807150000_hotel_michelin_keys_nullable.sql` applied
2. `20260807160000_create_worlds_50_best_hotels.sql` applied
3. `20260807170000_expose_hotel_worlds_50_best_rank.sql` applied (this pass's new migration)

Only after all three does adding `worlds_50_best_rank, worlds_50_best_year` to `hotelFullColumns` become safe — doing it before any one of them ships throws PostgREST 42703 (`column does not exist`) and takes down **every** hotel-catalogue caller across the whole app (Explore, Passport, Rankings, Detail, Wishlist), not just the World's 50 Best-specific code paths. This is why the change is deliberately split: the Flutter code (models, repositories, screens, filters) is complete and ready today, entirely inert with respect to World's 50 Best data until that one small follow-up column-list edit — which itself must wait for all three migrations. Until then, **every hotel in the app continues to behave exactly as it did before this task** — Key display, sorting, filtering, stay-saving — none of it regresses, because `Hotel.worlds50BestRank`/`worlds50BestYear` simply resolve to `null` for everyone, and `hotel.hasMichelinKeys` is `true` for all 687 existing hotels exactly as before.

Once the three migrations are applied and `hotelFullColumns` is updated, no further Flutter code change is needed — the Explore filter, Hotel Detail badge, Award History screen, and Rankings repository all light up from that one edit alone.
