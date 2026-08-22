# EVENTS V2 STEP 8B — REVERSE EVENT DISCOVERY PRE-FINAL

Implementation of the human-approved Step 8B architecture audit
(`EVENTS_V2_STEP_8B_REVERSE_EVENT_DISCOVERY_AUDIT.md`): Restaurant/Hotel/
Private Chef Detail pages now show Events the viewed entity genuinely
HOSTS (`is_host = true`). Nothing staged, committed, or pushed; zero
schema/RLS/migration changes; zero production writes.

## FRESH IMPLEMENTATION AUDIT

Re-read before editing: `EventsRepository`, `RestaurantDetailScreen`,
`HotelDetailScreen`, `PrivateChefDetailScreen`, `EventDetailScreen`,
`event_time.dart`, `event_chronology.dart`, `analytics_properties.dart`.
HEAD was still `782c070` (unchanged since the audit) — no material
discrepancy found; the audit's own findings matched current code exactly.

## REPOSITORY

Three new methods on the existing `EventsRepository`
(`lib/data/repositories/events_repository.dart`) — no second repository
created: `loadHostedEventsForRestaurant`, `loadHostedEventsForHotel`,
`loadHostedEventsForChef`. Each delegates to a shared private
`_loadHostedEvents({table, entityColumn, entityId, now})`.

## QUERY SHAPE

Exactly 2 queries per call, mirroring `loadLinkedVenues`'s own
established pattern, reversed: (1) `SELECT event_id FROM
{event_restaurants|event_hotels|event_chefs} WHERE {entity}_id = ? AND
is_host = true`; (2) `SELECT * FROM events WHERE id IN (...)`. No N+1.

## HOST SEMANTICS

Non-negotiable, enforced by a single, unconditional `.eq('is_host',
true)` in the first query — `is_venue` is never referenced by this
filter at all, so a venue-only or participant-only row is excluded by
construction, not by a separate check that could drift. Proven directly
against real production data (read-only, zero writes) — see Real
Production Positive/Negative Cases below.

## UPCOMING / ACTIVE

The standalone pure function `upcomingHostedEvents(events, {now})`
(added alongside `eventBrowseWindowBounds` in `events_repository.dart`)
excludes cancelled Events (`Event.isCancelled`) and ended Events
(`eventHasEnded` — exact instant when known, else the local-day-end of
`endDate` in the Event's own `timezone`). An Event that has started but
not yet ended is included — `!eventHasEnded` alone already means
"upcoming or active," no separate "has started" check exists. Never a
raw `end_at > now` comparison.

## DATE-ONLY SUPPORT

Proven directly: the real Flore pilot (`start_date=end_date=2026-10-19`,
all time/instant fields null, `timezone='Europe/Amsterdam'`) round-trips
through the exact production query end to end (see below) and displays
as `19 Oct 2026` in `HostedEventsSection`, with no fabricated time —
confirmed by both a widget test and the live production query result.

## SORTING

`upcomingHostedEvents` sorts via the canonical `compareEventChronology`
— no second comparator introduced anywhere.

## SHARED EVENTS SECTION

`HostedEventsSection` (new file,
`lib/features/events/widgets/hosted_events_section.dart`) — one widget
shared by all three Detail screens. Title is plain `EVENTS`. Renders
`SizedBox.shrink()` when `events` is empty. Contains a private
`_HostedEventRow` per Event.

## COMPACT EVENT CARD

`_HostedEventRow`: `warmWhite` background, `subtleBorderLight` border,
`CsRadius.medium` corners — the same visual language `LinkedVenueRow`
already established for "AT THIS HOTEL"/"DINING" on these exact screens,
deliberately NOT `EventActionsRow`'s card-free treatment (that belongs to
Event Detail's own editorial aesthetic). Content: Event title (max 2
lines, ellipsis beyond that — a title is still identifiable at 2 lines;
no real title in production or the Batch-1 backlog needs a third),
precision-aware date/time (`formatEventDateAndTime`), admission label
only when known, trailing chevron. No image/placeholder thumbnail —
audited and deliberately rejected: many Events have no approved image,
and a list of repeated branded monograms would read as noisier than a
calm, text-only row. No relevance reason, no Friends Going, no member
count, no Interested/Going controls, no repetition of the viewed
entity's own name.

## RESTAURANT DETAIL

`_hostedEvents` state (starts empty), loaded in `initState` via
`_loadHostedEvents()` (own try/catch, silently leaves the list empty on
any failure — mirrors `_checkAwardHistory`'s established pattern
exactly). Rendered `if (_hostedEvents.isNotEmpty) [SectionDivider(),
HostedEventsSection(...)]` immediately before the closing
`RestaurantInfoCard` block — the same relative position "AT THIS HOTEL"
occupies. No other section touched.

## HOTEL DETAIL

Identical pattern, same relative position "DINING" occupies (before the
closing `HotelInfoCard`). `DINING`'s own lazy
`if (hotel.hasMichelinRestaurant)`-gated future was left untouched.

## PRIVATE CHEF DETAIL

Appended as a new conditional entry (`if (_hostedEvents.isNotEmpty)
HostedEventsSection(...)`) to the end of the existing `sections` list in
`_body()`, after `PrivateChefConnectSection` — the least disruptive
placement relative to this screen's own documented canonical hierarchy
(HERO → ABOUT → BACKGROUND → THE EXPERIENCE → CONNECT). Loaded
independently of `_load()`'s own critical try/catch, on purpose, so a
hosted-Events failure can never flip the whole screen into its error
state. Production has zero `event_chefs` rows, so this entry is simply
absent from the list on every real device today — not merely hidden,
genuinely absent.

## NAVIGATION

Tap → `EventDetailScreen(eventId: event.id, sourceSurface:
AnalyticsSourceSurface.hostProfile)` — the existing screen, no
duplicate. Back navigation is Flutter's own default stack behavior.

## ANALYTICS

`AnalyticsSourceSurface.hostProfile` — confirmed still unused anywhere
else in the codebase before this change, exactly as the audit found.
`sourceContext` left `null` (no `AnalyticsSourceContext` value cleanly
fits "genuinely hosted by the profile you're viewing," matching the
established "omit rather than force a bad fit" convention). No new
analytics taxonomy created. No host name, friend data, Event title, or
private user state is sent — `AnalyticsProperties(entityType: event,
entityId: event.id, sourceSurface: hostProfile)` only, matching
`EventDetailScreen`'s own existing `eventOpened` call shape.

## EMPTY / FAILURE

Confirmed by both code and test: zero qualifying Events → no divider, no
heading, no placeholder — the entity Detail page is byte-identical to
before this change. A failed lookup behaves identically to zero results
— caught locally, state left at its empty default, nothing else on the
page affected.

## FOLLOW CONSISTENCY

Not touched. Confirmed semantically identical: Step 8A's own "Followed
Host" ranking signal, Step 6's Follow feature, and this Step 8B query
all key off the exact same `is_host = true` column — the same fact,
never two rules that could drift.

## REAL PRODUCTION POSITIVE CASE

Ran the exact 2-query shape read-only against production (zero writes):
`event_restaurants` filtered to Flore's id (`d656c75f-9354-4f57-b133-
b5ce03b913a7`) with `is_host = true` returned exactly one row —
`event_id = 307d79be-1712-40db-83ac-8758eeb78884`. The follow-up `events`
query for that id returned the pilot, `moderation_status='published'`,
`start_date=end_date='2026-10-19'`, `start_at`/`end_at` both null —
exactly the DATE_ONLY shape expected, round-tripping correctly through
the real production schema end to end.

## REAL PRODUCTION NEGATIVE CASES

Same read-only method, same production data: L'air du temps's id
(`8411b03c-14ef-4952-ae12-bec07b5a3470`, `is_host=false,
is_venue=false`) returned zero rows. De Librije's id (`66fc0bdf-19be-
4fd0-b93b-64fb63cc46ba`, one of the six Vergeet Mij Niet Gala
participants, also `is_host=false, is_venue=false`) returned zero rows.
Both negative cases confirmed directly against live data — no fixture
needed, no relationships altered.

## AUTOMATED HOTEL / CHEF COVERAGE

Production has zero `event_hotels`/`event_chefs` rows of any kind — the
Hotel and Chef host, lifecycle, and sorting paths are proven by
`test/hosted_events_domain_test.dart`'s pure-function coverage (which is
identical code regardless of which relationship table called it) and by
direct code review of `_loadHostedEvents`' single shared implementation
(the same function body serves all three tables — there is no
per-table branch to test separately). Local dev Postgres was found to
have an empty `restaurants` table with FK-heavy NOT NULL constraints
(`city_id`, `location`), making an artificial local fixture more
effort than value here — the real-production read-only proof (above)
was judged the more honest and authentic verification for the one
relationship table (`event_restaurants`) where genuine data already
exists, and is explicitly noted as not yet repeated against a live
Hotel/Chef host row, because none exists.

## DATABASE

Migrations created = 0. Migrations deployed = 0. Schema changes = 0.
RLS changes = 0. Production writes = 0 — confirmed directly: `events`
count = 5, `event_restaurants` count = 9, `event_hotels` count = 0,
`event_chefs` count = 0, all unchanged from before this task.
`supabase migration list --linked`: 39/39 `local == remote`. `supabase
db push --linked --dry-run`: "Remote database is up to date."

## VALIDATION

`dart format --set-exit-if-changed .`: 3 files auto-formatted (the
files just edited), 0 remaining diffs after. `flutter analyze`: no
issues at every intermediate step. `flutter test`: **1492 passed, 0
failed** (1474 baseline + 18 new: 8 in `hosted_events_domain_test.dart`,
10 in `hosted_events_section_test.dart`). No existing test weakened.

## FILES

New: `lib/features/events/widgets/hosted_events_section.dart`,
`test/hosted_events_domain_test.dart`,
`test/hosted_events_section_test.dart`,
`docs/Architecture/Events/EVENTS_V2_STEP_8B_REVERSE_EVENT_DISCOVERY_PRE_FINAL.md`
(this file). Modified:
`lib/data/repositories/events_repository.dart`,
`lib/features/restaurants/restaurant_detail_screen.dart`,
`lib/features/hotels/hotel_detail_screen.dart`,
`lib/features/private_chefs/private_chef_detail_screen.dart`.

## GIT

Nothing staged, committed, or pushed. Known unrelated enrichment/
research artifacts remain untouched.

## PHYSICAL DEVICE CHECKLIST

**FLORE**: EVENTS section visible; pilot Event shown; `19 Oct 2026`; no
fake time; tap opens Event Detail; back returns to Flore; Follow still
works; Wishlist still works.

**L'AIR DU TEMPS**: pilot Event NOT shown; no empty EVENTS section (no
heading, no divider).

**OTHER RESTAURANT WITHOUT A HOSTED EVENT** (the overwhelming majority of
the catalogue): no EVENTS section at all; Detail layout unchanged from
before this task.

No Hotel/Chef physical-device test required yet — zero production host
rows exist for either.

## DECISION

Implementation matches the human-approved audit exactly: three
repository methods, one shared section widget, three independent
Detail-screen integrations, existing `EventDetailScreen` navigation,
existing `hostProfile` analytics value — zero schema/RLS/migration
changes, zero production writes. The real Flore pilot proves the
positive case and its own date-only shape end to end against live
production data; L'air du temps and De Librije prove the negative case
against the same live data. Ready for physical-device review.

EVENTS V2 STEP 8B — REVERSE HOSTED-EVENT DISCOVERY IMPLEMENTED, HOST
SEMANTICS PRESERVED, READY FOR PHYSICAL-DEVICE REVIEW
