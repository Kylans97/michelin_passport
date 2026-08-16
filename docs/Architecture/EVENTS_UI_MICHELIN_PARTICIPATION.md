# Events UI Consistency Step 1 — Editorial Event Detail + Attendance + Michelin Restaurant Participation

Status: implemented, validated, **not committed** — pending physical-device review. No production migration required or deployed by this task (see §4). The Preuvenemint pilot's one approved link (Tout a Fait) is live in production and verified — see `docs/Architecture/EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md` and `supabase/data/enrichment/event_participants/preuvenemint/`. Step 1A (below) polishes the Michelin participant row's layout on top of Step 1 — still uncommitted.

---

## MICHELIN PARTICIPANT ROW POLISH — STEP 1A

Applied on top of Step 1 after physical-device review of the live Tout a Fait link: the section itself read well, but the star(s) sitting on their own line below the restaurant name wouldn't scale gracefully once an event has many Michelin-starred participants. Target direction: name and stars read as one identity cluster on the primary line, with city and country flag as quiet supporting context underneath.

### Root cause of the stars-under-name layout

`MichelinAtEventSection` originally rendered each participant via the shared `LinkedVenueRow` (`lib/core/widgets/linked_venue_row.dart`), passing `StarRow` as its `recognition` slot. `LinkedVenueRow`'s layout is a `Column` — name `Text`, then (if present) the `recognition` widget directly beneath it with a 4px gap. That shape is correct and already physically approved for `LinkedVenueRow`'s two other call sites (Restaurant Detail's "AT THIS HOTEL", Hotel Detail's "DINING") — the stars-below-name look wasn't a bug in that component, it was simply the wrong shape for what Event Detail's Michelin section specifically needed.

### Shared-component decision

`LinkedVenueRow` was **not modified**. Grep-confirmed it has exactly three call sites: `restaurant_detail_screen.dart`, `hotel_restaurants_card.dart` (Hotel Detail's DINING), and Event Detail's own HOTELS section (`event_detail_screen.dart`) — the first two are already-approved Restaurant/Hotel Detail screens outside this task's scope entirely, and changing `LinkedVenueRow`'s core layout to produce "stars inline with name" would either alter those two screens' approved appearance or require a mode-flag branch that leaves one shape effectively dead code in a component meant to stay simple. A new, Event-specific row was the lower-risk, clearer architecture. `git diff --stat lib/core/widgets/linked_venue_row.dart` shows zero changes; Event Detail's own HOTELS section still uses `LinkedVenueRow` completely unchanged.

### New component: `MichelinParticipantRow`

`lib/features/events/widgets/michelin_participant_row.dart` — used only by `MichelinAtEventSection`, which now renders this instead of `LinkedVenueRow`.

- **Name + stars inline**: one `Text.rich` paragraph, name as a `TextSpan`, stars as a `StarRow` wrapped in a trailing `WidgetSpan`. This is a genuine inline flow, not a `Row` with the stars pinned to the far trailing edge — if the name is short, the stars sit right after it on the same line; if the name is long enough to wrap, the wrapped line's last word is still immediately followed by the stars, never leaving them stranded far to the right with an artificial gap.
- **No line cap, no ellipsis on the name+star cluster**: Event Detail's content column already sits inside a scrolling `CustomScrollView`, so an unusually long name simply makes the row taller rather than needing to be truncated — the stars must never be lost to an ellipsis cutting off before they render, which a `maxLines`+`TextOverflow.ellipsis` cap could do for a pathological name length.
- **Secondary line**: city (from `Restaurant.cityName`, omitted entirely — not shown as blank/placeholder — when empty) followed by the country flag (`Restaurant.flagEmoji`, already a plain, pre-resolved String field on the canonical `Restaurant` model — see §"Country/flag source" below), in `AppColors.taupe`, clearly subordinate to the primary line.
- **Whole row stays tappable**: `Material`/`InkWell` wrapping, same forest-green splash/highlight treatment as the rest of Event Detail, `chevron_right_rounded` in taupe (never gold) as the tap affordance.
- **Color rule maintained**: only `StarRow`'s icons are gold; name, city, and chevron were audited (dedicated test) to confirm none of them are.

### City/country source — canonical, not event-derived

City and country come from `Restaurant.cityName`/`Restaurant.countryCode`/`Restaurant.countryName`/`Restaurant.flagEmoji` — the exact same canonical fields Restaurant Detail's own hero metadata line reads, resolved server-side on `restaurants_full` (joined from the `countries` table, confirmed via schema audit). **Never** the event's own country (`Event.countryCode`) — an international participant at a Dutch event must show its own country, not the event's, which matters the moment a non-Dutch restaurant is ever linked. No country was inferred from city; both are read as stored.

### Flag implementation

`Restaurant.flagEmoji` already exists as a plain String field (populated from `restaurants_full.flag_emoji`) — confirmed via a repo grep before writing anything new; this is the "country-code → flag helper" the task asked to audit for, and it already exists as pre-resolved canonical data rather than a code-side ISO-3166 mapping function. No new helper, no hardcoded per-country flag table, no image asset, no package dependency — the row simply renders the field's existing emoji value as plain text next to the city.

### Accessibility

The emoji flag is decorative/supporting only, never the sole signal for country — screen readers don't reliably or consistently announce regional-indicator emoji as a country name. The whole row is wrapped in one `Semantics(button: true, excludeSemantics: true, label: ...)` combining name, city (if present), country name (falling back to the country code only if the name wasn't resolved), and a correctly-pluralized star count into a single accessible label — e.g. `"De Librije, Zwolle, Netherlands, 3 Michelin stars"` or `"Tout a Fait, Maastricht, Netherlands, 1 Michelin star"` — rather than letting a screen reader read the name, the flag glyph, and the star icons as separate, disconnected nodes.

### Multi-restaurant scalability

Between rows: a tight hairline (`AppColors.taupe` at 0.4 alpha, 0.75px — the same color/thickness *token* `SectionDivider` uses) via a plain `Divider`, not the `SectionDivider` component itself, whose `CsSpacing.lg` (20px each side) vertical margin is sized for major section boundaries and would make a list of many participants feel sparse rather than dense and scannable. Row padding is a compact `CsSpacing.sm` (8px) vertical — enough for a comfortable tap target without excessive whitespace. Verified structurally with 1 restaurant (no hairline at all), 4 restaurants across NL/AT/FR with mixed name lengths and star counts, and a 12-restaurant dense-list fixture (all inside a scrollable ancestor, matching real Event Detail usage) — all render without overflow, all hairline counts are exactly `n - 1`.

### Files changed (Step 1A, on top of Step 1's own file list)

**Added:** `lib/features/events/widgets/michelin_participant_row.dart`.

**Modified:** `lib/features/events/widgets/michelin_at_event_section.dart` (renders `MichelinParticipantRow` instead of `LinkedVenueRow`; hairline changed from a plain `SizedBox` gap to a `Divider` using `SectionDivider`'s color/thickness tokens).

**Untouched (confirmed via `git diff --stat`):** `lib/core/widgets/linked_venue_row.dart`, `lib/features/restaurants/restaurant_detail_screen.dart`, `lib/features/hotels/widgets/hotel_restaurants_card.dart`, `lib/features/events/event_detail_screen.dart`'s HOTELS section, `lib/models/restaurant.dart`, all `event_restaurants`/enrichment-standard artifacts, and every other Event Detail section (attendance, admission, about, location).

### Tests (Step 1A)

`test/event_detail_redesign_test.dart` grew from 46 to 67 tests in this file (682 passing repo-wide, up from 661): a new `MichelinParticipantRow` group (17 tests — inline stars vs. secondary-line placement, 1★/2★/3★ counts, city rendering, correct NL/AT flags, missing-city and missing-flag omission, long-name wrapping without losing stars, tap-fires-callback, combined accessibility semantics for both plural and singular star wording, non-gold name/chevron audit, 320px/390px/1.6× responsiveness) and 4 new tests added to the existing `MichelinAtEventSection` group (hairline count for multiple rows, zero hairlines for a single row, a 4-restaurant NL/AT/FR fixture with mixed name lengths and star counts, a 12-restaurant dense-list scalability check). `flutter analyze`: clean.

---

## 1. Why

Event Detail was still on the app's older visual generation
(`AppTypography`/`AppColors.background`/`AppColors.card`, the shared
`DetailHero`/`SectionLabel`/`DetailCard` primitives) while Restaurant/Hotel
Detail had already moved onto the current editorial system
(`CsTypography`/`CsSpacing`/`CsRadius`, ivory content canvas, forest-green
typography, taupe secondary text, gold reserved for Michelin
stars/Keys only, `SectionDivider` hairlines). This pass brings Event Detail
onto that same system and adds one new capability: highlighting
Michelin-starred restaurants participating in an event, tapping through to
the canonical `RestaurantDetailScreen`. All existing event functionality —
attendance, admission, linked-venue resolution, Friend Profile/Trip
navigation — is preserved in substance; only presentation changed, plus the
one new Michelin-participation display.

## 2. Previous Event UX (audit findings)

- **Old design system throughout**: `EventDetailScreen` used `DetailHero`
  (shared with both Award History screens — never modified, see §5),
  `AppTypography.metadata`/`body`, `AppColors.background`/`gold`,
  `SectionLabel`/`DetailCard` (from `restaurants/widgets/detail_section.dart`).
  `EventGoingButton`'s "Going" state used `AppColors.gold` — a direct
  violation of the project's own color rule (gold reserved for Michelin
  stars/Keys only), inherited from before that rule existed.
- **Meta facts boxed in a `DetailCard`**: date/time, address, and admission
  all sat inside one bordered card — the current system's own guidance is
  "reduce unnecessary nested rounded cards... use a card only where it has
  semantic value" (matching how Restaurant/Hotel Detail already dropped
  their own equivalent card boundary).
- **"RESTAURANTS (n)" / "HOTELS (n)"**: every linked restaurant/hotel
  rendered via `RestaurantTile`/`HotelTile` — Explore's own *dark-canvas,
  card-styled* discovery tiles (`AppColors.card`, `VenueThumbnail`),
  visually mismatched against an otherwise ivory-canvas redesign, and with
  no distinction between Michelin-starred and unstarred participants.
- **Hero badge stack**: event type, free-entry, and cancelled all rendered
  as boxed `HeroBadge` chips inside the hero — workable, but heavier than
  the "curated, not marketplace" direction this pass targets.

## 3. Target positioning

Curated gastronomic events (festivals, chef collaborations, guest-chef
dinners, Michelin-related culinary events) — never a ticket marketplace or
generic listing app. The visual language should communicate curation even
when an event is free to attend. This shaped several concrete decisions
below: no pricing-style badges, a restrained (not full-width) attendance
control, and a simplified "stars only" Michelin recognition display.

## 4. Data model audit — no migration needed

Before writing any migration, the existing schema was inspected. **A
suitable relationship already exists and is already live in production**:

```sql
-- supabase/migrations/20260810160000_create_events.sql
create table public.event_restaurants (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  unique (event_id, restaurant_id)
);
create table public.event_hotels (
  id       uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  unique (event_id, hotel_id)
);
```

Confirmed live via `supabase migration list --linked` (20260810160000 is
synced local↔remote) and via a direct read-only query — `public.
event_restaurants`/`event_hotels`/`events` all carry a single public-read
RLS policy (`for select to anon, authenticated using (true)`) and **no
insert/update/delete policy for any client role**: normal users are
read-only, exactly the "editorial/public catalogue data, only trusted
backend mechanisms write it" requirement. No RLS change was made or is
needed.

**This deliberately uses a plain FK junction table, not
entity_type/entity_id polymorphism** — the migration's own original
comment explains why: unlike `visits`/`wishlist`/`planned_venues` (each
addresses exactly one venue of one type), an event can link both
restaurants and hotels at once, so two type-specific join tables (each a
real, cascading FK) are the cleaner shape, matching the existing
`hotel_restaurants` precedent.

**Conclusion: no new migration was created or is required for this
feature.** The relationship, its RLS, and the repository method to resolve
it (`EventsRepository.loadLinkedVenues`) all already existed; this task's
work was UI/filtering on top of them, not schema.

**No seed participation data was written.** `select count(*) from
event_restaurants` on production returns `0` — no event has any real
participating restaurant today, for `'t Preuvenemint` or any other event.
Per the task's explicit instruction, no fabricated participant rows were
inserted anywhere, including locally; the feature was built and tested
entirely against in-test fixtures (`test/event_detail_redesign_test.dart`).
Real participation data is a future editorial/data task, not part of this
UI pass.

## 5. Restaurant canonical source & Michelin-star canonical source

`MichelinAtEventSection` (`lib/features/events/widgets/
michelin_at_event_section.dart`) reads `Restaurant.michelinStars`/
`Restaurant.hasMichelinStar` — the exact same fields `RestaurantDetailScreen`
itself reads off `restaurants_full` — **never a value duplicated onto
`event_restaurants`**. `EventsRepository.loadLinkedVenues` already resolves
full `Restaurant` rows (one batched `restaurants_full` query, not N+1), so
the star count shown here is always the restaurant's live, current
recognition — the same canonical source every other screen in the app
reads, with no second source of truth to drift out of sync.

## 6. Historical-star limitation (documented, not solved)

For a future/current event, showing the restaurant's *current* Michelin
stars is reasonable. For a genuinely historical event, current stars may
differ from what a restaurant held at the time. **This app only surfaces
upcoming/current events today** (`EventStatus` has no distinct handling for
long-past editions beyond `completed`, and `EventsRepository`'s own
query methods are date/country scoped for discovery, not built around
browsing a historical archive) — so reading current stars is an acceptable
simplification for this MVP. No historical event-award snapshot table was
built; if the product ever needs to browse genuinely historical event
editions with period-accurate recognition, that requires its own dedicated
data model (mirroring how `Visit.roomRating`/`keysAtVisit` already capture
a point-in-time snapshot elsewhere in this app) — out of scope here.

## 7. Event Detail — new hierarchy

`EditorialBackButton` (in hero) → hero (real photo or branded monogram
placeholder, event type eyebrow, name, city/country, compact date range) →
**EVENT META** (flat icon rows: cancelled-status if applicable, date/time
range, venue name, admission) → hairline → **ATTENDANCE** (`EventGoingButton`,
only if `canAttendEvent`) → hairline → **ABOUT** (conditional, reusing
`VenueAboutSection` outright with `event.description`) → hairline →
**MICHELIN AT THIS EVENT** (conditional, Michelin-starred linked restaurants
only) → hairline → **HOTELS** (conditional, preserved existing
functionality, reskinned onto `LinkedVenueRow`) → hairline → **LOCATION**
(address + Website/Tickets links, conditional as a whole unit — no orphan
hairline when nothing follows it, matching Restaurant/Hotel Detail's own
established rule).

City/country appears once (hero); the precise date/time range appears once
in EVENT META, distinct in detail level from the hero's compact range — no
fact is shown twice at the same level of detail.

## 8. Hero

New `EventDetailHero` (`lib/features/events/widgets/event_detail_hero.dart`)
— a fresh, Cs-token-based primitive, deliberately **not** a modification of
the shared `DetailHero` (`detail_hero.dart`), which stays exactly as-is:
that widget is also used by both Award History screens, out of scope here,
and editing it would risk changing their appearance too. This mirrors
exactly how `VenueDetailHero` was built as its own parallel component for
Restaurant/Hotel Detail rather than editing `DetailHero` in place.

Unlike `VenueDetailHero` (whose no-photo fallback is a plain gradient,
since no restaurant/hotel photo exists in the catalogue at all), events
already have a real `image_url` column and an established branded-monogram
fallback — `EventDetailHero` always renders whatever `backgroundImage`
widget it's given (a real `Image.network` with its own `CsImagePlaceholder`
`errorBuilder`, or the placeholder directly when no URL exists), reusing
the exact same `_heroLogoScale = 0.22` constant the previous implementation
established.

Deliberately minimal: no badge stack. Event type, free-entry, and
cancelled status are no longer boxed hero chips — event type is one quiet
eyebrow-style line above the title; free-entry/cancelled moved into EVENT
META below, where they read as facts, not marketplace badges.

## 9. Event image behavior — unchanged rule, reused fallback

Real image → `Image.network(event.imageUrl)`, `BoxFit.cover`. No image, or
a failed load → the existing branded `CsImagePlaceholder` (never a broken-
image icon, never stock/scraped imagery, never restaurant imagery
standing in for the event). This logic is untouched from the previous
implementation — only where it renders (inside `EventDetailHero` instead of
`DetailHero`) changed.

## 10. Admission — editorial treatment, unchanged semantics

`EventMetaSection` renders one flat icon row: the admission type's own
label (`'Free entry'`, `'Ticketed'`, `'Free entry, optional ticket'`) as
the primary line, with `admissionNote` (when present) as a smaller taupe
supporting line beneath it — e.g. for `'t Preuvenemint`: **"Free entry,
optional ticket"** / *"Free general admission. The optional 't
PreuveneMeet' networking evening is separately ticketed."* No loud
marketplace-style badge; `EventAdmissionType`'s four values
(`free`/`paid`/`mixed`/`unknown`) and their semantics are completely
unchanged — this is a display change only.

## 11. Attendance

`EventGoingButton` (`lib/features/events/widgets/event_going_button.dart`)
was rewritten in place (same file, same class name, same public API —
`going`/`busy`/`onTap` — so every existing call site needed zero changes)
as a **compact, intrinsically-sized pill**, not a
`SizedBox(width: double.infinity, height: 46)` booking button. Both states
are forest-green: outlined + "I'm going" when not attending, filled +
"Going" when attending — never gold, fixing the pre-existing color-rule
violation noted in §2. State is still never color-only (distinct icon +
label per state, same as before). Tapping while attending still removes
attendance directly — no confirmation dialog, unchanged (a low-stakes
personal toggle, not a destructive action). A `Semantics(button: true,
label: ...)` wrapper was added for clearer screen-reader behavior than the
plain `FilledButton`/`OutlinedButton` semantics it replaced.

`canAttendEvent(event, {now})` — the exact function gating whether the
control renders at all — is completely unchanged: still `!event.
isCancelled && event.endAt.isAfter(now ?? DateTime.now())`. A past or
cancelled event still shows no attendance control; the EVENT META section's
own cancelled-status row (§10 sibling) already explains why, so no
additional "attendance closed" copy was added.

## 12. Attendance privacy — untouched

No new UI exposes or changes attendance visibility. `event_attendance`'s
default visibility (`friends`), its RLS (`user_id = auth.uid()` OR
`visibility = 'friends' AND is_friend(user_id)`, a live subquery so
unfriending/blocking revokes access on the next read), and the repository
methods (`getMyAttendance`/`markGoing`/`removeAttendance`) are all
completely unmodified — this task only changed how the resulting
going/not-going state is *rendered*, never how it's read, written, or
authorized. No visibility toggle was added to Event Detail (none existed
before); inventing one was explicitly out of scope for this pass.

## 13. Aggregate attendance count — audited, deliberately left unwired

`get_event_attendance_count(target_event_id uuid)` was audited: `security
definer`, counts across all attendance rows regardless of the caller's own
friendships, returns the exact count only once ≥5 unique attendees exist
(else `NULL`), `anon` execute explicitly revoked, `authenticated` execute
granted. Fully deployed, fully correct, and — confirmed via
`grep -rn "get_event_attendance_count" lib/ test/` — **still zero call
sites anywhere in the app**.

**Decision: left unwired in this MVP.** Reasoning: (1) the ≥5 threshold
means it would show nothing for effectively every event today, including
`'t Preuvenemint`, since real attendance is far below that bar for a brand
new feature with no real usage yet; (2) this task's two substantial asks
— the editorial redesign and Michelin participation — were the priority;
(3) wiring a signal that will read as blank in virtually every real case
today adds a repository call, a loading state, and test surface for
near-zero current visible benefit; (4) nothing about today's decision
blocks wiring it in later — the RPC, its grants, and its threshold
behavior need no further changes whenever real usage justifies it. This
satisfies the task's own explicit "if no clear design value, leave
unwired and document the decision" instruction.

## 14. Michelin participation — architecture & display

`MichelinAtEventSection` reuses `LinkedVenueRow` (`lib/core/widgets/
linked_venue_row.dart`) — the exact same primitive Restaurant/Hotel
Detail's own "AT THIS HOTEL"/"DINING" sections already use for an
identical shape (name + recognition + tap-through to the canonical detail
screen) — rather than inventing a parallel row widget for a structurally
identical UI need. `StarRow` supplies the recognition, and is the **one**
legitimate place gold appears on Event Detail — confirmed via a dedicated
gold-audit test asserting the section title, chevron, and every other
element are never gold.

`michelinStarredParticipants(List<Restaurant>)` — a pure, top-level,
directly-unit-tested function — filters to `restaurant.hasMichelinStar`
and sorts most-decorated first (3★ before 2★ before 1★), alphabetically
within the same star count for a deterministic order (the underlying
`inFilter` query has no natural ordering of its own). A restaurant linked
to the event without a current star is not shown in this section at all —
the relationship itself is untouched at the data level (§4); this is a
display filter only, matching the task's explicit "intentionally
simplified for visual impact" instruction. Zero starred participants →
the entire section renders nothing (`SizedBox.shrink()`) — never a "No
Michelin restaurants participating." placeholder, mirroring
`VenueAboutSection`'s own established empty-state convention.

Section title: **"MICHELIN AT THIS EVENT"** (the task's preferred option;
no alternative wording was needed).

## 15. Canonical navigation

`MichelinAtEventSection.onTapRestaurant` and the preserved Hotels section
both push straight to the existing `RestaurantDetailScreen`/
`HotelDetailScreen` — no `EventRestaurantDetailScreen`, no wrapper, no
duplicate route. Tapping a participating restaurant from Event Detail
behaves identically to opening the same restaurant from Explore, Passport,
Wishlist, Guides, or a Friend Profile: the viewer can Wishlist it, Plan a
visit, inspect its awards, and see their own visit history, all through
the one real screen. Verified by a dedicated test asserting the exact
`Restaurant` instance tapped is the one passed to the callback.

## 16. Non-starred participants & hotels

The relationship may contain restaurants without a current Michelin star,
and/or linked hotels — neither is deleted or altered at the data level.
Non-starred restaurants are simply not rendered in the Michelin section
(§14). Linked hotels are preserved as their own conditional "HOTELS"
section — existing functionality, kept working, reskinned onto
`LinkedVenueRow` (no Keys shown per the hard color-scope rule: "No Michelin
Keys exist in Events unless a hotel-related future feature is explicitly
added") instead of the old dark-canvas `HotelTile` card, which would have
visually clashed against the new ivory canvas.

## 17. Event overview card — audited, deliberately unchanged

`EventCard` (`lib/features/events/widgets/event_card.dart`) is used by
three different screens — the Events browse list, Trip Detail's "WHAT'S
ON" section, and (indirectly, via its own separate tile) Explore's event
search results, which already has its own doc comment warning against a
global `EventCard` redesign "unless absolutely necessary." **Decision: no
Michelin indicator was added to the card, and the card's visual language
was not touched in this pass.** Reasoning: (1) zero participation data
exists in production today, so any indicator would render nothing on
every real card right now; (2) `EventCard` is reused across three
screens with different contexts — a Michelin indicator meaningful on the
main Events browse list could read as noise on a Trip's own "what's
nearby" card; (3) the task's own guidance explicitly permits keeping
restaurant detail on Event Detail only, documenting why, when adding a
card-level indicator risks visual crowding — that condition applies here.
Event Detail already surfaces Michelin participation prominently; the
card doesn't need to duplicate it. `EventsScreen`/`EventFilterBar` were
similarly left untouched — genuinely out of this pass's scope (Event
Detail, not the browse list).

## 18. Color system — audit result

Grep across every file touched by this pass for `gold`/`AppColors.gold`
found **zero** matches outside `star_row.dart` (untouched, pre-existing) —
confirming `MichelinAtEventSection`'s `StarRow` usage is the only gold on
the redesigned screen. `EventGoingButton`'s pre-existing gold "Going"
state (§2/§11) was the one violation found and fixed. `EventMetaSection`'s
cancelled-status row uses `AppColors.error`, not gold, matching the
existing `EventCard._CancelledBadge` precedent elsewhere in this feature.

## 19. Hairlines

`SectionDivider` — the same primitive and token (`AppColors.taupe` at 0.4
alpha, 0.75px) Restaurant/Hotel Detail already established — placed at
exactly the section boundaries listed in §7, each one conditional on the
section it precedes actually rendering (no orphan hairline when an
adjacent optional section is empty), mirroring the exact pattern already
validated there.

## 20. Files changed

**Added:**
- `lib/features/events/widgets/event_detail_hero.dart`
- `lib/features/events/widgets/event_meta_section.dart`
- `lib/features/events/widgets/michelin_at_event_section.dart`
- `test/event_detail_redesign_test.dart`
- `docs/Architecture/EVENTS_UI_MICHELIN_PARTICIPATION.md` (this file)

**Modified:**
- `lib/features/events/event_detail_screen.dart` (full redesign — see §7)
- `lib/features/events/widgets/event_going_button.dart` (reskinned in
  place — same file, same class name, same public API)
- `test/event_going_button_test.dart` (updated for the new implementation;
  added a compact-pill-size test and a gold-audit test)

**Deleted:** none. `RestaurantTile`/`HotelTile` usage inside Event Detail
was replaced by `LinkedVenueRow`, but neither widget itself was deleted —
both remain actively used by Explore.

**Untouched (confirmed, Category C):** `lib/core/widgets/detail_hero.dart`
(shared with both Award History screens), `lib/features/events/widgets/
event_card.dart` (§17), `lib/features/events/events_screen.dart`, `lib/
features/explore/widgets/explore_event_result_tile.dart`, `lib/data/
repositories/event_attendance_repository.dart`, `lib/data/repositories/
events_repository.dart`, `lib/models/event.dart`, `lib/models/
event_trip_match.dart`, the `event_attendance`/`events`/`event_restaurants`/
`event_hotels` schema and RLS.

## 21. Tests

Baseline 634 passing (end of the Restaurant/Hotel Detail workstream).
`test/event_detail_redesign_test.dart` adds 25 new tests: `EventDetailHero`
(real-image vs. monogram placeholder, title/event-type/city-country/date
content, back-action semantics, 320px/390px/1.6× responsiveness);
`EventMetaSection` (date/time always shown, venue row present/absent, all
four admission variants including the mixed-with-note case, cancelled
status row color/copy, non-gold audit); `MichelinAtEventSection` +
`michelinStarredParticipants` (starred-only filtering, empty-result
omission for both a fully-empty list and an all-unstarred list, 1★/2★/3★
rendering, most-decorated-first sort with alphabetical tiebreak, tap-fires-
callback-with-exact-restaurant, gold-audit, 3-restaurant/long-name
responsiveness). `test/event_going_button_test.dart` gained 2 tests (compact-
pill sizing, non-gold audit) on top of its existing 7. Final total: **661
passing**, `flutter analyze` clean.

`canAttendEvent` (`test/can_attend_event_test.dart`),
`EventAttendance`/`AttendanceVisibility` (`test/
event_attendance_model_test.dart`), `FriendGoingTile` (`test/
friend_going_tile_test.dart`), and the Friend Profile GOING section (`test/
friend_profile_going_section_test.dart`) all continue to pass unmodified —
none of the code they cover changed.

`EventDetailScreen` itself remains untestable directly (a `StatefulWidget`
that calls `Supabase.instance.client` in `initState`, and this project has
no Supabase mocking harness — the same established constraint documented
since the Restaurant/Hotel Detail workstream) — coverage targets the
extracted presentational primitives instead, exactly the same strategy
used there.

## 22. Regression verification

- **Friend Profile GOING**: `FriendGoingTile.onTap` still pushes the
  canonical, unmodified `EventDetailScreen(eventId: eventId)` — confirmed
  by reading the current source; its own test suite passes unmodified.
- **Trip event discovery**: `eventMatchesTrip`/`eventsMatchingTrip`
  (`lib/models/event_trip_match.dart`) were not touched; `TripDetailScreen`
  still renders matching events via the untouched `EventCard` and still
  navigates to `EventDetailScreen(eventId: event.id)` on tap.
- **`ExploreEventResultTile`**: untouched; still its own separate,
  already-Cs-token tile, unaffected by any change in this pass.
- **Navigation call sites**: `grep -rn "EventDetailScreen("` across `lib/`
  shows the same four call sites as before this pass (Explore, Friend
  Profile, Trip Detail, Events overview), each still passing only
  `eventId` — the constructor's public API is unchanged.

## 23. Deferred / explicitly out of scope

Per the task's own hard boundaries: Friends/Community redesign, friend
identities/counts on Events (only the identity-free aggregate RPC was even
considered, and left unwired — §13), Friends score/visited intelligence,
Guides typography polish, Trips booking-status evolution, Private Chefs,
NL phone enrichment, Award History Journey redesign, About enrichment,
Restaurant people/editorial model. None of these were started.
