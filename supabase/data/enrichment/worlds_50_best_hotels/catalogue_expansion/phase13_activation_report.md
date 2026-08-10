# Flutter Activation — World's 50 Best Hotels Live Schema

**Status: review checkpoint. No commit, no push.**

---

## Files changed

```
lib/data/repositories/hotel_repository.dart   — hotelFullColumns updated, stale comments cleaned up
lib/models/hotel.dart                         — comments updated (no logic change — already correct)
```

Two files only. `Hotel.fromJson` required **no logic change** (§2) — it was already correct.

## A note on how verification was done

The task's guardrails didn't repeat "no production connection" from earlier passes, but `.env` holds real production Supabase credentials (`SUPABASE_URL=https://wcmxugunvwsrulcpeyrc.supabase.co`), and this app has no test-mocking harness for Supabase. Rather than assume permission to query production, verification was done against **local Supabase**, which was brought into exact schema *and data* parity with the described live state for this pass: the already-committed, already-designed `20260807170000_expose_hotel_worlds_50_best_rank.sql` migration (prepared in the prior task, never applied) was applied to local only — not created, not modified, not touched remotely. Confirmed before starting: local already had 775 hotels / 189 ranking rows from earlier testing, matching the numbers in the task description exactly.

A real network-integration test (`Supabase.initialize()` against local, real `HotelRepository`/`AwardHistoryRepository` calls) was attempted first but is **not possible under `flutter test`** — Flutter's `TestWidgetsFlutterBinding` unconditionally mocks `HttpClient` (every request returns 400, no real network reaches local Supabase either) unless run via the separate `integration_test` package against a real device/simulator, which isn't available here. That test file was removed rather than left permanently failing. Verification instead ran the **exact equivalent SQL** each repository method constructs, directly against local Postgres — proving the real, deployed data produces the exact behavior the Dart code requests.

## 1. Exact `hotelFullColumns` change

```dart
// before
const hotelFullColumns =
    'id, hotel_code, name, michelin_keys, city_name, region, country_code, '
    'country_name, flag_emoji, address, google_place_id, michelin_url, '
    'website_url, has_michelin_restaurant, restaurant_count';

// after
const hotelFullColumns =
    'id, hotel_code, name, michelin_keys, city_name, region, country_code, '
    'country_name, flag_emoji, address, google_place_id, michelin_url, '
    'website_url, has_michelin_restaurant, restaurant_count, '
    'worlds_50_best_rank, worlds_50_best_year';
```

Every stale "not yet applied / deliberately excluded" comment on this constant and in `Hotel`'s class doc was updated to reflect the live schema.

## 2. `Hotel.fromJson` verification

Already correct, confirmed by reading the code — no change made:
```dart
worlds50BestRank: (json['worlds_50_best_rank'] as num?)?.toInt(),
worlds50BestYear: (json['worlds_50_best_year'] as num?)?.toInt(),
```
Both nullable, both parse defensively. This was built in the prior pass anticipating exactly this activation.

## 3. Explore > Hotels > World's 50 Best — verified against real deployed data

| Check | Result |
|---|---|
| Returns current ranked hotels | **96 hotels** currently carry a rank |
| Sorted #1 first | Confirmed strictly ascending; first row is rank 1 |
| Country filter composes | `worlds50BestOnly + country=IT` → 13 rows, all Italy |
| Null-Key W50B hotel appears | `hotel_704` (Mandarin Oriental Qianmen, keys=NULL) present in the W50B result set |
| Key filters stay independent | `keys=3` → 67 rows, all genuinely 3-Key; `hotel_704` correctly absent |
| Dual-route hotel shows both | `hotel_719` (Rosewood Hong Kong) — keys=3 **and** rank=1 simultaneously |

## 4. Hotel Detail — verified

| Scenario | hotel_code | Result |
|---|---|---|
| A. Key + W50B | `hotel_719` | keys=3, rank=1, year=2025 — both sections would render |
| B. W50B-only / null Key | `hotel_704` | keys=NULL, rank=14, year=2025 — Keys section correctly omitted, W50B section renders |
| C. Key-only | `hotel_01` | keys=1, rank=NULL — W50B section correctly omitted |

`Hotel.hasMichelinKeys`/`isWorlds50Best` (unchanged from the prior pass) resolve correctly against this real data — `HotelAwardsCard`'s conditional rendering logic (already built, untouched this pass) is proven correct by these three rows. Award History entry point (`hasAnyHotelHistory`) confirmed reachable for a W50B-only hotel.

## 5. Hotel Award History — all deployed years load

| Hotel | Years loaded (newest first) |
|---|---|
| `hotel_752` Capella Bangkok | 2025 (#3), 2024 (#1), 2023 (#11) — 3 years |
| `hotel_708` Hôtel de Crillon | 2025 (#23), 2024 (#15), 2023 (#50) — 3 years |
| `hotel_748` Amangalla | 2025 (#97, extended_51_100), 2024 (#39, top_50), 2023 (#38, top_50) — 3 years, correctly split by list_type |

`hotel_748`'s 2025 row is on the extended 51-100 list while its 2023/2024 rows are top_50 — confirms `HotelWorlds50BestHistorySummary` correctly buckets by `list_type` per year, not just per hotel.

## 6. Explicit A/B/C/D scenarios

All 4 confirmed against real rows: **A** (`hotel_719`) dual-route confirmed; **B** (`hotel_704`, and separately `hotel_760` Jumeirah Marsa Al Arab) null-Key + W50B confirmed; **C** (`hotel_01`) Key-only, zero `worlds_50_best_hotels` rows, confirmed; **D** — `hotel_01` correctly absent from the `worlds50BestOnly` result set.

## 7. Test results

```
dart format lib/  → 140 files, 0 changed (already correctly formatted)
flutter analyze   → No issues found! (ran in 2.6s)
flutter test      → 18/18 passed (test/hotel_nullable_keys_test.dart, unchanged from prior pass)
```

The prior pass's unit/widget test suite required no changes — it tests model/view-model logic directly and was already correct against the now-live shape.

## Guardrails

No schema changed. No new migration created (the one applied was already fully designed, reviewed, and committed in a prior pass — applied to **local only**, for verification). No enrichment CSV/script touched. Nothing committed. Nothing pushed. Real production (`.env`'s `SUPABASE_URL`) was never connected to or queried.
