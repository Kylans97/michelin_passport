# Architecture Review — `qualifies_for_catalogue = has_michelin_key OR has_worlds_50_best_hotel_history`

**Status: analysis only. No schema, no code, changed.**

This reviews what the proposed rule would touch, based on direct inspection of the current schema and the current Flutter codebase — not assumption.

---

## The core finding: `michelin_keys` is NOT NULL in two independent places, not one

`public.hotels.michelin_keys` is `smallint NOT NULL CHECK (BETWEEN 1 AND 3)` in the database (confirmed in the production schema migration). That much was already known from the prior report. What direct code inspection adds:

**`Hotel.michelinKeys` in the Flutter model is `final int` — not `final int?`.** This is a second, independent non-nullability, enforced by the Dart type system itself, not merely inherited from the database. The model's own comment states it explicitly: *"Unlike Restaurant.michelinStars, this is never null... every row in the catalogue holds at least one Michelin Key by definition."*

**Both would have to change together.** Making the database column nullable without also changing `final int michelinKeys` to `final int? michelinKeys` would just move the crash from the database to the app — every `Hotel.fromJson` call would throw the moment a real null reached `(json['michelin_keys'] as num?)?.toInt() ?? 0`... except that fallback already exists: `?? 0`. Today it's dead code (the DB guarantees non-null, so it never fires) — but it means a naive schema-only change would silently start rendering `0` for a Key-less hotel instead of correctly rendering "no Key," which is exactly the class of bug `DATABASE_ARCHITECTURE.md` already fought and won on the restaurant side (`michelin_stars` is nullable, never zero, and the interface contract is explicit that a null must never render as "no award"). The hotel side needs the identical discipline applied deliberately, not inherited by accident from a stale fallback expression.

---

## What would have to change, precisely

| Layer | Current state | Required change |
|---|---|---|
| `hotels.michelin_keys` (DB) | `NOT NULL CHECK (1-3)` | `ALTER COLUMN michelin_keys DROP NOT NULL`, keep the `CHECK` (a `CHECK` already permits NULL unless written otherwise) |
| `hotels_master.csv` / importer | Every row has a keys value; `insert_hotels()` never handles a blank | Importer needs a `nullif(col,'')`-style path for `michelin_keys`, mirroring exactly how `clean_stars()` already handles the restaurant side's 0→NULL conversion |
| `Hotel.michelinKeys` (Dart) | `final int`, `?? 0` fallback (currently dead code) | `final int? michelinKeys`, remove the `?? 0` fallback — a real null must surface as null, not silently become a fake zero |
| `KeyRow` widget | `List.generate(count, ...)` — `count` must be a real `int` | Every call site (`hotel_hero.dart`, `passport_hotel_card.dart`, `hotel_tile.dart` ×2, `hotel_ranking_card.dart`) needs a null-guard: render nothing, or a "World's 50 Best" badge instead of empty key icons |
| `hotel_tile.dart`'s `'${hotel.michelinKeys}🔑'` string | Would print literally `"null🔑"` for a Key-less hotel | Needs the same guard |
| `add_stay_sheet.dart`'s `keysAtVisit: widget.hotel.michelinKeys` | `visits.keys_at_visit smallint` (already nullable in the DB) | No DB change needed here — already correctly nullable; just needs the Dart-side type to flow through once `Hotel.michelinKeys` is nullable |
| `HotelKeysFilter` (Explore) | 4 cases: all/1/2/3 Keys, each mapping to a `keys` search param | Needs a 5th case mirroring `RestaurantAwardFilter.worlds50Best` / `.isWorlds50Best` exactly — **the restaurant side already solved this exact problem**; extending the hotel side is replicating a working pattern, not inventing one |
| `HotelRepository.search()` | `builder.eq('michelin_keys', keys)` | Needs an additional filter path for "has World's 50 Best history, any/no Keys" — same shape as how `RestaurantRepository.search()` already handles `worlds50BestOnly` independently of `stars` |
| `hotels_full` view | No World's 50 Best exposure at all (unlike `restaurants_full`, which already carries `worlds_50_best_rank`) | Needs an equivalent derived column once a hotel ranking table exists — see Phase 4 |
| `award_history` (DB) | Already polymorphic (`entity_type`/`entity_id`/`award_type`), already supports `'michelin_keys'` as an `award_type` value | **No change needed at all.** This table was already built hotel-ready. |
| `AwardHistoryRepository` (Dart) | `loadMichelinHistory({required entityType, ...})` already branches on `entityType == 'hotel'` to resolve `michelin_keys` as the award type — comment states *"a future hotel Award History screen would call this with 'hotel'"* | **No change needed at all.** Already built to support this. |
| Rankings | `HotelRankingCard` reads `hotel.michelinKeys` for display only | Same null-guard as `KeyRow`'s other call sites; no structural change |
| Passport | `PassportHotelCard` reads `hotel.michelinKeys` for display only | Same null-guard |
| Wishlist | Polymorphic `entity_type`/`entity_id` already, no direct `michelinKeys` reference found | **No change needed.** |
| Map | No direct `michelinKeys` reference found (coordinates come from `MapRepository`, independent of Keys) | **No change needed.** |

---

## What this means in practice

**Roughly half the codebase surface this rule touches is already built for it.** `award_history` and its Flutter repository were explicitly designed with hotel Key history in mind from day one — the comments in `award_history_repository.dart` say so directly, and nothing there needs to change. Wishlist and Map need nothing. The genuinely new work is narrower than "touches everything":

1. One nullable-column migration (`hotels.michelin_keys`), still not written per your instruction.
2. One Dart model field becoming nullable, with its dead-code `?? 0` fallback removed rather than relied on.
3. A handful of display call sites gaining a null-guard — the same shape of guard the restaurant side already has for `michelinStars` everywhere it's displayed.
4. One new Explore filter case and one new repository search path, both direct copies of a pattern the restaurant side already ships.
5. A hotel-side ranking table and its `hotels_full` exposure (Phase 4) — this is the one piece with no existing precedent to copy, because `worlds_50_best` today is restaurant-only by hard FK, not just by convention.

**Nothing here is proposed as done or scheduled.** This is the exact list of what would need review and its own implementation pass, should the scope-rule decision in Phase 5 ever be made.
