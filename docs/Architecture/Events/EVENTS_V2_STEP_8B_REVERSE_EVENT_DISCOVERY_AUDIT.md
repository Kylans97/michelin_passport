# EVENTS V2 STEP 8B — REVERSE EVENT DISCOVERY ARCHITECTURE AUDIT

Read-only architecture audit for showing Events a Restaurant/Hotel/Private
Chef genuinely HOSTS (`is_host = true`) on that entity's own Detail page.
Nothing was implemented, migrated, staged, committed, or pushed — every
finding below is derived from a fresh read of production schema, live
production relationship data, and the current Dart Detail-screen
implementations.

## CURRENT RELATIONSHIP MODEL

`event_restaurants`/`event_hotels`/`event_chefs` are structurally
identical: `id uuid PK (gen_random_uuid())`, `event_id uuid NOT NULL FK →
events(id) ON DELETE CASCADE`, `restaurant_id`/`hotel_id`/`chef_id uuid
NOT NULL FK → restaurants(id)`/`hotels(id)`/`private_chefs(id) ON DELETE
CASCADE`, `is_host boolean NOT NULL DEFAULT false`, `is_venue boolean NOT
NULL DEFAULT false`. Each has a `UNIQUE (event_id, entity_id)`
constraint (so one entity can't be linked to the same Event twice) and
two non-unique indexes: one on `event_id`, one on the entity foreign key
alone (`event_restaurants_restaurant_idx` etc. — NOT composite with
`is_host`). All three have RLS enabled with exactly one policy each:
`SELECT ... USING (true)`, no `roles` restriction — fully public read,
identical shape across all three tables.

**Reverse lookup (`entity_id → Events where is_host = true`) is already
efficiently supported by the existing schema.** The entity-id index
narrows to that one entity's own (inherently small) relationship-row set
before `is_host` is even evaluated — no schema change needed.

## PRODUCTION HOST DATA

Read all `event_restaurants` rows directly (`event_hotels`/`event_chefs`
are both empty — 0 rows in each). 9 total `event_restaurants` rows exist:

| Event | Restaurant | is_host | is_venue |
|---|---|---|---|
| 't Preuvenemint | Tout a Fait | false | false |
| **4 Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre** | **Flore** | **true** | **true** |
| 4 Hands Dinner: Bas van Kranen x Sang Hoon Degeimbre | L'air du temps | false | false |
| Vergeet Mij Niet Gala | De Librije | false | false |
| Vergeet Mij Niet Gala | De Treeswijkhoeve | false | false |
| Vergeet Mij Niet Gala | Inter Scaldes | false | false |
| Vergeet Mij Niet Gala | Restaurant Smink | false | false |
| Vergeet Mij Niet Gala | Ciel Bleu | false | false |
| Vergeet Mij Niet Gala | De Bokkedoorns | false | false |

**Exactly one genuine host relationship exists in all of production
today: Flore on the date-only pilot, confirmed `is_host=true,
is_venue=true` exactly as expected.** L'air du temps is confirmed
`is_host=false, is_venue=false` — a pure participant, exactly as
expected. Every other relationship in production (Tout a Fait, and all 6
Vergeet Mij Niet Gala restaurants) is also participant-only. This gives
Step 8B exactly one real production Restaurant-hosted Event to build
against, and a rich, unambiguous negative-case dataset (7 participant-only
relationships) to prove exclusion against — no fixture data needed for
the Restaurant case at all. Hotel and Private Chef have zero
relationships of any kind today.

## RESTAURANT DETAIL

`RestaurantDetailScreen` (590 lines): `RestaurantHero` (sliver) → padded
`Column`: city/country line + award-history action → `SectionDivider` →
`VenueUtilityActions` (Directions/Website/Call/Michelin) →
`SectionDivider` → "PLAN YOUR VISIT" eyebrow + `SubtleTextAction` →
`SectionDivider` (if signed-in + has a visit) → score strip →
`SectionDivider` (if about text — currently always null, no such column
exists yet) → `SectionDivider` → "YOUR VISITS" eyebrow row +
`RestaurantVisitsCard` → `SectionDivider` (if latest visit) → "PERSONAL
PHOTOS" → `SectionDivider` (if `hasHotelBadge`) → "AT THIS HOTEL" eyebrow
+ `LinkedVenueRow` → `SectionDivider` (if address) → `RestaurantInfoCard`.

**Recommended insertion point:** a new conditional `EVENTS` section,
same pattern as every other section here (`SectionDivider` + eyebrow +
content), inserted directly before the final `SectionDivider` +
`RestaurantInfoCard` block — i.e. immediately after "PERSONAL PHOTOS"
(or after "AT THIS HOTEL" when that's present), in the same relative
slot "AT THIS HOTEL" already occupies: the established "related content
lives just before the closing Info/Location card" position. This is
purely additive — one new `final Future<List<Event>>` loaded alongside
the existing personal-state/award-history loads in `initState`, one new
conditional block in `build()`. No restructuring of anything above it.

## HOTEL DETAIL

`HotelDetailScreen` (516 lines) mirrors `RestaurantDetailScreen`'s
structure almost exactly, but is NOT identical — confirmed by reading
both directly rather than assuming: `HotelHero` → city/country + award
history → `SectionDivider` → `VenueUtilityActions` (no `onCall` — Hotel
has no `phone` field at all, a real, pre-existing gap unrelated to this
audit) → `SectionDivider` → "PLAN YOUR STAY" → `SectionDivider` (if
stay) → score strip → `SectionDivider` (if about — also always null
today) → `SectionDivider` → "YOUR STAYS" + `HotelStaysCard` →
`SectionDivider` (if latest stay) → "PERSONAL PHOTOS" → `SectionDivider`
(if `hotel.hasMichelinRestaurant`) → "DINING" eyebrow + `HotelRestaurantsCard`
→ `SectionDivider` (if address) → `HotelInfoCard`.

**Recommended insertion point:** identical relative slot — a new
`EVENTS` section immediately before the final Info/Location card, in the
same position "DINING" already occupies (after Personal Photos, before
Info). Hotel's own linked-restaurants future
(`_linkedRestaurantsFuture`) is loaded lazily only `if
(widget.hotel.hasMichelinRestaurant)`; the new hosted-Events future
should follow that exact same lazy/conditional-future pattern, not an
unconditional load every Hotel Detail visit doesn't need.

## PRIVATE CHEF DETAIL

`PrivateChefDetailScreen` (377 lines) uses a structurally different,
cleaner pattern: a `sections = <Widget>[...]` list built conditionally
(`if (hasBiography) _aboutSection(...)`, `if (hasBackground)
_backgroundSection()`, `PrivateChefExperienceSection` unconditionally,
`if (hasInstagram || hasWebsite) PrivateChefConnectSection(...)`), then
rendered via a `for` loop inserting `SectionDivider` between every
consecutive pair. The screen's own doc comment documents an explicit
canonical hierarchy: "HERO → ABOUT → BACKGROUND → THE EXPERIENCE →
CONNECT."

**Recommended insertion point:** append a new conditional
`if (hasHostedEvents) _hostedEventsSection()` entry to the `sections`
list, positioned AFTER `PrivateChefConnectSection` — the least
disruptive placement relative to the screen's own already-documented,
explicit 4-section canonical order. Given zero `event_chefs` rows exist
in production today, this section simply never renders yet — the
architecture should still be built and covered by fixture/widget tests
(§26/§27), not skipped.

## HOST SEMANTICS

Confirmed non-negotiable and consistent with production data: only
`is_host = true` qualifies, for either table, regardless of `is_venue`.
`is_venue = true` alone (a physical-venue-only relationship) does NOT
qualify — no such row exists in production today to test against
directly, but the rule is unambiguous from the schema/task and will be
covered by a widget/fixture test. `is_host = false, is_venue = false`
(participant-only) does NOT qualify — directly, richly proven by all 7
production participant-only rows (Tout a Fait, De Librije, De
Treeswijkhoeve, Inter Scaldes, Restaurant Smink, Ciel Bleu, De
Bokkedoorns, and L'air du temps). `is_host = true, is_venue = true`
(Flore) DOES qualify — a real host+venue Event is valid, not required to
be host-only.

## UPCOMING / PAST DECISION

**Recommend: upcoming/active only for MVP (Option A).** Rationale:
entity Detail is discovery/actionable surface — a user reading a
Restaurant's page wants to know what they could attend, not a historical
log of everything it once hosted. A past-hosted-Events archive is a
legitimate future idea (editorial history, Passport context) but adds
real product surface area (a second section, or an expand/toggle) for
zero current production benefit — Flore's own pilot Event is itself
still upcoming, so MVP doesn't even have a past-hosted-Event case to
design against yet. Revisit once there's a real past-hosted Event to
design the archive experience around, rather than speculatively building
it now.

## DATE-ONLY COMPATIBILITY

Must reuse the exact canonical Event Time Precision architecture, never
raw `start_at`/`end_at` as a required filter. Because the row count per
entity is inherently small (a venue hosting Events is not a
high-frequency pattern this product targets — Flore's own row is 1 of
1), the recommended design fetches ALL of one entity's own host-Events
in a single unfiltered-by-date query, then applies the existing
Dart-side `eventHasEnded`/`eventEndReferenceInstant` helpers
(`lib/core/utils/event_time.dart`) per row — exact instant when known,
else the local-day-end of `endDate` in the Event's own `timezone` — to
decide upcoming-vs-past, and `Event.isCancelled` to decide
cancelled-vs-not. This is MORE precise than `EventsRepository.loadEvents`'
own conservative ±1-day-widened SQL window (Phase C), which exists
specifically to solve a scale/international-date-boundary problem that
doesn't apply here at all, since there's no large table-wide SQL scan to
protect against — the entire candidate set for one entity is already
tiny before any date logic runs. Flore's pilot Event (`start_date=
end_date=2026-10-19`, `start_time=end_time=start_at=end_at=NULL`,
`timezone='Europe/Amsterdam'`) is exactly the DATE_ONLY shape this must
handle correctly, and does — `eventEndReferenceInstant` already computes
its local-day-end boundary the same way for any caller.

## QUERY DESIGN

**Recommend adding 3 new methods directly to the existing
`EventsRepository`** (`lib/data/repositories/events_repository.dart`),
not a new dedicated repository — this repository already centralizes
every Event-query shape (`loadEvents`, `loadEventById`,
`loadLinkedVenues`, `loadEventsForCountry`), and these three are equally
"give me Events matching a criterion." Fragmenting Event-query logic
across repositories would be inconsistent with how this codebase is
already organized.

Conceptual shape (not implemented), mirroring `loadLinkedVenues`'s own
established "batch the join-table ids, then one batched lookup" pattern
— exactly 2 queries per call, reversed:

```
Future<List<Event>> loadHostedEventsForRestaurant(String restaurantId) async {
  final relRows = await _client.from('event_restaurants')
      .select('event_id').eq('restaurant_id', restaurantId).eq('is_host', true);
  final eventIds = [for (row in relRows) row['event_id'] as String];
  if (eventIds.isEmpty) return const [];
  final rows = await _client.from('events').select().inFilter('id', eventIds);
  final events = [for (row in rows) Event.fromJson(row)];
  // upcoming/not-cancelled filter (eventHasEnded, Event.isCancelled) +
  // compareEventChronology sort happens here, in Dart.
  return events;
}
```

`loadHostedEventsForHotel`/`loadHostedEventsForChef` mirror this exactly
against `event_hotels`/`hotel_id` and `event_chefs`/`chef_id`. **Exactly
2 queries per Detail-page load** (relationship-id fetch, then batched
Event fetch) — no N+1, matching the codebase's own established
convention.

## RLS

**No RLS change, no SECURITY DEFINER function needed.** The 2-query
pattern naturally respects existing RLS at each step: the first query
reads `event_restaurants`/`event_hotels`/`event_chefs`, whose own RLS
(`USING (true)`, all roles including anonymous) permits the read
unconditionally; the second query reads `events` directly, whose own
RLS (`moderation_status = 'published'`) is enforced automatically —
a relationship row pointing at a draft/rejected/archived Event simply
returns no corresponding row in the second fetch, with zero extra
application-level filtering required. This is the exact same
RLS-composition safety `EventsRepository.loadLinkedVenues` already
relies on today for the forward direction (Event → its
restaurants/hotels), just reversed.

## INDEXES

Current indexes (`event_restaurants_restaurant_idx` etc.) are a single
column on the entity FK alone, not composite with `is_host`. **No new
index is justified, at any realistic scale.** The relevant scale axis
for this query is never "total Events in the system" — it's "how many
relationship rows does ONE entity have." Even at 10,000 total Events
system-wide, one Restaurant/Hotel/Chef's own hosted-Event count would
realistically stay in the single digits to low dozens (this product
curates genuine host organizers, not a high-frequency events platform) —
the existing entity-FK index already narrows to that tiny row set before
`is_host` is evaluated at all, so a composite index would only matter if
a single entity accumulated thousands of its own relationship rows,
which isn't a realistic pattern here. Revisit only if that assumption is
ever contradicted by real data.

## SECTION UX

**Recommend the section title `EVENTS`**, not "UPCOMING EVENTS" or
"HOSTED EVENTS" — matching the product preference and the established
naming convention on both Restaurant/Hotel Detail, where every section
eyebrow states the CONTENT plainly ("YOUR VISITS," "DINING," "AT THIS
HOTEL," "PERSONAL PHOTOS") without explaining the underlying
relationship mechanics to the user. "HOSTED EVENTS" would be the one
naming choice that leaks an internal distinction (host vs. venue vs.
participant) the user was never shown anywhere else. Never "MICHELIN
EVENTS"/"STAR EVENTS" — recognition is unrelated to hosting, exactly as
directed.

## CARD REUSE

**Recommend Option C — a small new card built from existing Cs atoms,
not direct or "compact mode" reuse of `EventCard`.** Two independent
reasons, both found directly in the code, not assumed: (1) `EventCard`
(`lib/features/events/widgets/event_card.dart`) is built entirely on the
OLDER `AppTypography`/`AppColors.card`/raw `GoogleFonts.inter` system —
it predates the Cs-token redesign both Event Detail and Restaurant/Hotel
Detail have already migrated onto (`CsTypography`, `CsSpacing`,
`SectionDivider`). Dropping it in unchanged (or lightly modified) would
visually clash with the page around it. (2) `EventCard` carries genuine
feed-specific chrome that doesn't belong on an entity's own Detail page
at all: a `EventRelevanceReason` row (Step 8A's own ranking-explanation
UI — meaningless once you're already looking at the actual host), a
`CANCELLED` badge (cancelled Events are excluded from this surface
entirely per this audit's own recommendation, so the badge would never
render), and a 16:9 banner-first layout sized for a scrolling discovery
feed, not a compact in-page section. The right shape is closer to
`LinkedVenueRow`'s own existing pattern (a simple, Cs-token-based,
tappable row) extended with a date/admission line — small, consistent
with the page it lives on, and easy to build without inheriting
feed-specific concerns.

## DISPLAY CONTENT

Recommend: Event title, precision-aware date/time
(`formatEventDateAndTime`), admission (only when NOT `unknown` — same
"never show a placeholder" rule `EventMetaSection` already follows), and
the existing placeholder/image treatment when relevant. **Do not repeat
the entity's own name** — Flore hosting its own Event at Flore would
read "Restaurant Flore" redundantly on a card already living on Restaurant
Flore's own page; venue/city is only useful when it differs from "here"
(rare for a genuine host — a host almost always hosts at or near its own
premises), so it's reasonable to omit venue text entirely on this card
and let the tap → Event Detail surface it if the user wants it.

## NAVIGATION

Tap → existing `EventDetailScreen(eventId: event.id, sourceSurface: ...,
sourceContext: ...)` — no duplicate detail implementation, no new
screen. Back navigation is Flutter's own default `Navigator.push` stack
behavior (matching every other Detail→Detail navigation already in this
codebase, e.g. Restaurant→Hotel via `_openHotel`) — returns to the
originating entity Detail automatically, no special handling needed.

## EMPTY / FAILURE STATE

**Recommend: render NO section at all when zero upcoming hosted Events
exist, and NO section (fail silently) if the reverse query itself
fails** — matching this codebase's own repeatedly-established
convention (`_hasAwardHistory`'s own catch-and-hide pattern in both
Restaurant and Hotel Detail; `EventDetailScreen`'s own
"failure-isolated" personalization loads). Hosted Events are enhancement
content, never a reason for the rest of Detail to look broken or show a
raw error. No "No upcoming events" copy anywhere — that would put a
permanent, mostly-empty section on the vast majority of Restaurant/Hotel/
Chef pages today (only 1 of many production restaurants currently
qualifies), which is exactly the clutter the task's own instruction
warns against.

## ANALYTICS

**No taxonomy gap — `AnalyticsSourceSurface.hostProfile` (wire value
`'host_profile'`) already exists in `analytics_properties.dart`, defined
but never yet used as a `sourceSurface` value anywhere in the codebase**
(confirmed via a fresh grep — it only appears in its own enum/switch
definitions and inside the unrelated `AnalyticsEvent.hostProfileOpened`
event name). It reads as though it was reserved in advance for exactly
this reverse-discovery case. No existing `AnalyticsSourceContext` value
cleanly describes "genuinely hosted by the profile you're viewing" —
`followedHost` is adjacent but semantically distinct (a Step 8A
personalization signal requiring the viewer to follow the host, not an
inherent property of this navigation path). Recommend `sourceContext:
null` for this new opening path, matching the codebase's own established
"omit rather than force a bad taxonomy fit" convention (already used
identically for Step 8A's own "no clean existing match" cases). No
analytics contract change needed.

## FOLLOW CONSISTENCY

Not changed. Confirmed semantically consistent: Step 8A's own "Followed
Host" ranking signal is already keyed off exactly `is_host = true` on
these same three relationship tables (the same rule this audit's whole
Host Semantics section describes) — Step 8B's reverse surface uses the
identical `is_host = true` definition, so "a Restaurant a user follows
can rank as Followed Host in the feed" and "that same Restaurant's own
Detail page shows the Events it hosts" are provably the same underlying
fact, viewed from two directions, never two different rules that could
drift apart.

## FUTURE PARTICIPANT SURFACE

Documented only, not built: a future `FEATURED AT`/`APPEARING AT`/
`PARTICIPATING IN` surface for `is_host = false, is_venue = false` rows
— e.g. L'air du temps "participating in" the Bas van Kranen dinner, or
each of the 6 Vergeet Mij Niet Gala restaurants "participating in" the
Gala. This is a distinct, separate future surface — Step 8B's `EVENTS`
section must never merge host and participant rows together.

## FUTURE VENUE SURFACE

Documented only, not built: `is_venue = true, is_host = false` rows may
someday warrant an "Events at this venue" surface (a hotel that
physically hosts an Event it doesn't organize). No production example
exists today. `HOSTED EVENTS` and `EVENTS AT THIS VENUE` are
semantically different claims and must stay two distinct future
surfaces, never merged.

## DATABASE DECISION

No migration. No schema change. No RLS change. No new SQL function. No
new index. Every piece of schema Step 8B needs already exists and
already permits a safe, RLS-respecting, N+1-free reverse lookup.

## IMPLEMENTATION SCOPE

Smallest safe shape for a future implementation pass: (1) 3 new
`EventsRepository` methods (§ Query Design); (2) one small shared
`HostedEventsSection`-style widget (Cs-token-based, per § Card Reuse);
(3) one new conditional section wired into `RestaurantDetailScreen`; (4)
the same into `HotelDetailScreen`; (5) the same, appended after Connect,
into `PrivateChefDetailScreen`; (6) navigation via the existing
`EventDetailScreen`, `sourceSurface: AnalyticsSourceSurface.hostProfile`;
(7) tests per § Test Plan. No navigation restructuring. No production
data writes. Each of the three Detail-screen integrations is
independent and could ship separately if desired.

## TEST PLAN

**Repository/domain**: Restaurant `is_host=true` → included. Restaurant
`is_venue=true, is_host=false` → excluded. Restaurant participant-only
→ excluded (7 real production shapes to model fixtures on). Hotel
`is_host=true` → included. Hotel venue-only → excluded. Chef
`is_host=true` → included. Cancelled hosted Event → excluded. Past
Event (when upcoming-only) → excluded, using `eventHasEnded`, never a
raw `end_at > now` filter. Date-only upcoming Event → included, with the
Flore pilot's own exact shape as one fixture. Multiple hosted Events for
one entity → sorted via `compareEventChronology`, no second comparator.

**UI**: zero Events → no section rendered at all. One Event. Multiple
Events. A long title. A date-only Event (no fake time shown). A
full-time Event. Tap → navigates with the correct `eventId` and
`sourceSurface: hostProfile`.

**Regression**: an entity Detail page with zero hosted Events renders
byte-identical to today — proven by re-running (not weakening) the
existing Restaurant/Hotel/Private Chef Detail test suites once
implemented.

## PHYSICAL DEVICE PLAN

**Flore** (real production data): hosted Event visible under `EVENTS`;
correct date-only display (`19 Oct 2026`, no fake time); tap → Event
Detail; back → Flore Detail unchanged; Follow still works; Wishlist
unchanged.

**L'air du temps** (real production data): the same Event must NOT
appear — the one genuinely load-bearing negative-case check this pilot
gives us for free.

**Any restaurant with zero hosted Events** (the overwhelming majority of
the catalogue): no awkward empty section, no visible change at all from
today.

**Hotel / Private Chef**: zero production host relationships exist for
either today — physical-device verification is honestly Restaurant-only
at first; Hotel and Private Chef coverage starts as automated
fixture/widget tests only, until a real hosted relationship exists for
either. This is stated plainly, not glossed over.

## DATABASE

migrations created = 0. migrations deployed = 0. schema changes = 0.
production writes = 0. Everything in this document was derived from
read-only production queries.

## VALIDATION

`flutter analyze`: no issues (unchanged from before this audit — no Dart
was modified). `flutter test`: 1474 passed, 0 failed (baseline
unchanged, no code touched). `supabase migration list --linked`: 39/39
`local == remote`. `supabase db push --linked --dry-run`: "Remote
database is up to date." `git status --short`: unchanged except for this
new, untracked documentation file.

## FILES

New: `docs/Architecture/Events/EVENTS_V2_STEP_8B_REVERSE_EVENT_DISCOVERY_AUDIT.md`
(this file). Left untracked, matching this repository's established
convention for architecture/pre-apply docs. No Dart file created or
modified.

## GIT

Nothing staged, committed, or pushed.

## DECISION

Every piece of schema Step 8B needs already exists: the relationship
tables already carry `is_host`/`is_venue`, already index the reverse
lookup path efficiently at any realistic scale, and their RLS already
permits a safe, public, N+1-free reverse query without a new function.
Production data already gives Step 8B one genuine, real Restaurant-host
example (Flore) and seven genuine negative examples (every other
current relationship, all participant-only) to build and prove the
implementation against — no fixture Events need to be invented for the
Restaurant case at all. Hotel and Private Chef have zero relationships
today, which does not invalidate the architecture, only limits initial
physical-device coverage to Restaurant. The recommended implementation
is additive and small: three repository methods, one new shared
section widget, three independent Detail-screen integrations, reusing
the existing `EventDetailScreen` for navigation and the existing
`AnalyticsSourceSurface.hostProfile` value (already reserved, never
used) for attribution.

EVENTS V2 STEP 8B — REVERSE HOSTED-EVENT DISCOVERY ARCHITECTURE
AUDITED, READY FOR HUMAN REVIEW BEFORE IMPLEMENTATION
