# Events Recognition V2 — Multi-Guide Participant Recognition

Status: implemented, validated, backend unchanged. Extends the
Michelin-only `AT THIS EVENT` section (Events UI Consistency Step 1/1A,
Events V2 Step 3's entity-neutral rename) to also recognize a canonical
Restaurant's current World's 50 Best rank or Hall of Fame membership —
without duplicating any recognition data onto `event_restaurants`, and
without any backend/schema change.

## PREVIOUS (V1) BEHAVIOR

`event_restaurants` → canonical `Restaurant` → `AtThisEventSection` →
Michelin-starred participants only (`michelinStarredParticipants`,
`MichelinParticipantRow`). A verified participant with real gastronomic
recognition — Gault&Millau, or World's 50 Best without also holding a
Michelin star — was correctly linked in the database but invisible on
Event Detail.

## CANONICAL RECOGNITION SOURCES — AUDITED, NOT ASSUMED

Read live from `information_schema.columns`/migration source, not from
historical documentation, before writing any code:

- **Michelin**: `Restaurant.michelinStars` (`int?`, null = no current
  star, never coerced to 0) / `Restaurant.hasMichelinStar`. Sourced from
  `restaurants_full.michelin_stars`. Unchanged by this workstream.
- **World's 50 Best**: `Restaurant.worlds50BestRank` (`int?`) /
  `Restaurant.isWorlds50Best`, plus the separate `Restaurant.isHallOfFame`
  (`bool`, always non-null). Sourced from `restaurants_full.
  worlds_50_best_rank`/`is_hall_of_fame`. **Current-only, confirmed by
  reading the view's own derivation**: `worlds_50_best_rank` joins only
  the most recent year with a non-null rank
  (`w.year = (select max(year) from worlds_50_best where rank is not
  null)`) — a restaurant not ranked in that year gets `NULL`, never a
  stale historical rank presented as current. `is_hall_of_fame` derives
  from `worlds_50_best.list_type = 'hall_of_fame'` specifically, never
  from `inclusion_reason` (a known prior bug this field's own doc comment
  already documents having fixed).
- **Gault&Millau: NOT implemented in V2.** `public.gault_millau_awards`
  (41 rows) and `gault_millau_special_awards` (58 rows) exist and are
  live in production, but a direct live query of
  `restaurants_full`'s own column list confirms it exposes **no**
  Gault&Millau column at all — `Restaurant` has no field to read one
  from. Exposing it would require either a `restaurants_full` view
  change (a migration — explicitly out of this task's backend-unchanged
  scope) or a second, Events-specific data-fetching path bypassing the
  canonical Restaurant loading this section already receives (not "the
  smallest necessary application-layer change" the task asked for). Per
  the task's own explicit instruction — "It is acceptable for V2 to
  support fewer recognition types correctly rather than three
  incorrectly" — this was the correct call, not a shortcut. Extending
  `restaurants_full`/`Restaurant` to expose Gault&Millau's own score/
  toque/recognition-type shape is a separate, future, backend-touching
  task.

## ELIGIBILITY RULE

`isRecognizedEventParticipant(Restaurant)` — one small, directly
unit-tested predicate (`lib/features/events/widgets/
at_this_event_section.dart`), the single place this decision is made:

```dart
bool isRecognizedEventParticipant(Restaurant restaurant) =>
    restaurant.hasMichelinStar ||
    restaurant.isWorlds50Best ||
    restaurant.isHallOfFame;
```

## WHAT REPLACED `michelinStarredParticipants()`

`recognizedEventParticipants(List<Restaurant>)` — filters via
`isRecognizedEventParticipant`, defensively deduplicates by
`Restaurant.id` (the `event_restaurants` table's own
`unique(event_id, restaurant_id)` constraint and `restaurants_full`'s
one-row-per-id shape mean a duplicate should never actually reach this
function, but the guarantee is now explicit and directly tested rather
than merely assumed), then sorts. Exactly one implementation exists —
`AtThisEventSection.build` calls this and nothing else; no eligibility or
sort logic is duplicated anywhere else.

## SORTING

Preserved exactly, not redefined: most Michelin-decorated first
(`michelinStars ?? 0` — a restaurant with no current star sorts as `0`,
i.e. after every starred one), alphabetical fallback within the same
star count. **No arbitrary cross-guide prestige score was introduced** —
this is the same single metric (Michelin star count) the section already
used before V2, simply extended to treat "no Michelin star" as a
legitimate, neutral value rather than a reason for exclusion. A
World's-50-Best-only or Hall-of-Fame-only restaurant is never ranked
*above* a Michelin-starred one by virtue of that other recognition, and
never compared against Gault&Millau (not implemented) or against another
guide's own internal ranking — satisfying the task's explicit "avoid
Michelin > Gault&Millau > World's 50 Best without product justification."

## UI PRESENTATION

`MichelinParticipantRow` → renamed `EventParticipantRow` (same rename
reasoning Events V2 Step 3 already applied to the section itself:
recognition is a contextual attribute of the participant, not what the
component is named for). Visual hierarchy is an **extension**, not a
redesign:

- **Primary line** (unchanged in shape): restaurant name, with Michelin
  stars (`StarRow`) inline immediately after the name — exactly as
  before, present only when `hasMichelinStar`.
- **Secondary line** (extended): previously always exactly `city + flag`.
  Now: `[recognitionLabel, city].join(' · ')` then the flag —
  `recognitionLabel` is `'Hall of Fame'` or `"World's 50 Best · #N"`
  (Hall of Fame takes priority if, improbably, both are true for the
  same restaurant — a rare-to-never real combination, since a Hall of
  Fame legend is by construction retired from the annual ranking that
  produces a current rank), reusing the **exact existing terminology**
  `RestaurantHero` already established for these two signals (never
  competing/invented wording), and `null` (omitted from the join
  entirely) when the restaurant has neither. **For every Michelin-only
  restaurant — including all 6 of Andorra Taste's real linked
  restaurants — `recognitionLabel` is `null`, so the secondary line
  renders exactly `city` + flag, byte-for-byte the same string as before
  V2.** No new row, no badge, no pill, no logo — a restrained inline text
  addition to a line that already existed, per the task's own explicit
  "avoid giant badges/colorful award pills/logo clutter" instruction and
  dark-green/ivory design language.

## MULTIPLE RECOGNITIONS, ONE ROW

A restaurant that is both Michelin-starred and World's-50-Best-ranked (or
Hall of Fame) still produces exactly one `EventParticipantRow` — stars
stay on the primary line, the World's 50 Best/Hall of Fame label joins
the secondary line alongside city — never two rows, never a duplicate
participant entry. Directly tested (`Michelin + World's 50 Best`,
`Michelin + Hall of Fame` fixture cases).

## ACCESSIBILITY

The combined semantic label ordering is unchanged for every existing
case (`name, city, country, N Michelin star(s)`) — the World's 50
Best/Hall of Fame phrase is appended last, only when present, so no
existing screen-reader string changes for a Michelin-only restaurant.

## NAVIGATION

Unchanged — every row still pushes to the canonical
`RestaurantDetailScreen` via the same `onTapRestaurant` callback; no
recognition text is a separate tap target.

## ANDORRA TASTE 2026 REGRESSION

Andorra Taste's 6 real linked restaurants (Cocina Hermanos Torres,
Rote Wand Chef's Table, LÚ Cocina y Alma, Paco Roncero, Iván Cerdeño, Le
Prince Noir - Vivien Durand — 3+2+2+2+2+1 stars, none currently holding
World's 50 Best or Hall of Fame recognition) are covered by a dedicated
regression group in `test/event_detail_redesign_test.dart` using an
in-test fixture matching that real profile (name/star count/city only —
never the live production UUIDs). All 6 remain visible, in the exact
same sort order, with the exact same star counts, zero World's 50
Best/Hall of Fame text (since none of the six currently hold it), 5
hairlines, and correct tap-through — proving the section this task's
own primary regression case depends on renders identically to before V2.

## BACKEND

No changes. `event_restaurants` schema/RLS untouched. No migration
created. No production data written or modified by this workstream (the
only production write in this whole thread was the prior, separate
Andorra Taste event-creation workstream — see `EVENT_PARTICIPANT_
ENRICHMENT_STANDARD.md` and that event's own enrichment report).

## FILES

**Added:**
- `lib/features/events/widgets/event_participant_row.dart` (was
  `michelin_participant_row.dart`/`MichelinParticipantRow`)
- `docs/Architecture/Events/EVENTS_RECOGNITION_V2.md` (this file)

**Modified:**
- `lib/features/events/widgets/at_this_event_section.dart`
  (`isRecognizedEventParticipant` added, `michelinStarredParticipants` →
  `recognizedEventParticipants`, doc comments updated)
- `lib/features/guides/widgets/guide_venue_card.dart` (one comment
  reference updated to the new row name — no behavior change)
- `test/event_detail_redesign_test.dart` (renamed references throughout;
  25 new tests added: eligibility predicate, sorting/dedup, row-level
  World's 50 Best/Hall of Fame presentation, section-level multi-guide
  fixture matrix, dedicated Andorra Taste regression group)

**Deleted:**
- `lib/features/events/widgets/michelin_participant_row.dart` (superseded
  by `event_participant_row.dart`)

**Untouched:** `event_restaurants`/`events`/`restaurants_full` schema and
RLS; `EventsRepository.loadLinkedVenues`; `Restaurant` model; every other
Event Detail section; Restaurant/Hotel Detail's own recognition
presentation (`RestaurantHero`, `LinkedVenueRow`).

## TESTS

`test/event_detail_redesign_test.dart` grew from 62 to 87 tests (all
existing tests preserved, renamed only where the widget/function itself
was renamed — zero behavior change to any pre-existing assertion). Full
repository suite: 1717 → 1742 (`flutter test`), `flutter analyze` clean.

## PHYSICAL-DEVICE VALIDATION

Deployed to the user's iPhone ("kylan", iOS 26.6) for a courtesy visual
check of Andorra Taste. Since Andorra's own 6 restaurants are all
Michelin-only, their rendering is proven byte-for-byte unchanged by the
automated regression suite above — device inspection here is
confirmatory, not a hard gate the way N2.6's genuinely-new UI was.
Production currently contains no World's 50 Best-only or Hall of
Fame-only linked participant to inspect on-device (the only
`event_restaurants` rows with real Michelin-adjacent recognition are
Andorra's own 6, all Michelin-starred) — per the task's own explicit
instruction, no fake production data was created solely to exercise
that path on a physical screen; the automated fixture-based tests above
are the coverage for it.
