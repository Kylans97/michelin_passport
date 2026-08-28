# Events V2 — Analytics Contract

**Status: vendor-neutral foundation implemented (`lib/core/analytics/`). No analytics vendor selected. No feature instrumented. No production analytics data exists.** This is operational documentation, not an essay — if you're implementing Interested/Going/Follow/Attendance in Step 3+, this file tells you exactly which event to emit, when, with which properties, and what never to send. For the *design rationale* behind these decisions, see `EVENTS_V2_ARCHITECTURE.md` §31 (Analytics architecture) — this document is that design's operational, implementation-facing counterpart, and defers to it on anything not restated here.

## 1. Principles

Analytics exists to improve the product, understand engagement, curate better events, prove host/destination value, and support future commercial and recognition-partner conversations — never to build a profile of any individual user beyond what a specific, named product goal requires. It stays privacy-conscious, purpose-limited, first-party, explainable, and structurally separate from product state. It is not, and must never become, ad-tech-style surveillance.

## 2. Source-of-truth boundary (non-negotiable)

**Supabase is the sole source of truth for every piece of transactional product state. Analytics is never authoritative and must never be queried to reconstruct product state.**

| Table | Owns the truth for |
|---|---|
| `event_attendance` | Interested / Going |
| `event_confirmed_attendance` | confirmed Attendance |
| `follows_restaurants` / `follows_hotels` / `follows_private_chefs` | Follow |
| `visits` | Restaurant/Hotel Passport history |
| `planned_venues` | Trip planning |

```
GOOD:
  Database: event_attendance.status = 'going'
  Analytics: event_going_added   (an echo, fired after)

BAD:
  No database write. Infer "going" from the most recent analytics event.
```

A screen that needs to know current state always reads the database. `AnalyticsService.track` never performs, substitutes for, or is a precondition of a state change — see §11 (Successful-write rule).

## 3. Abstraction

Implemented in `lib/core/analytics/`:

- **`analytics_event.dart`** — `AnalyticsEvent` enum (the full taxonomy, §5) + `.wireName` extension (the one place the wire string is spelled out) + `analyticsSchemaVersion`.
- **`analytics_properties.dart`** — `AnalyticsProperties` (the one typed property bag, §6) + the controlled vocabularies it's built from (`AnalyticsSourceSurface`, `AnalyticsSourceContext`, `FriendSignalType`, `AttendanceSource`, `AnalyticsEntityType`, `PriceBucket`).
- **`analytics_service.dart`** — `abstract class AnalyticsService { track(...); identify(...); resetIdentity(); }`, `NoopAnalyticsService` (the production-safe default — a true no-op, nothing computed, nothing stored, nothing sent), `DebugPrintAnalyticsService` (local-only development aid, prints the fully-stamped envelope via `debugPrint`, never a network call).

No screen, repository, or widget imports a vendor SDK — none exists in `pubspec.yaml` as of this step. A future provider is added later as a **new implementation of `AnalyticsService`**, wired in at one place (app composition), never by touching call sites. `track()` stamps `event_name`/`timestamp`/`schema_version`/`session_id`/`user_internal_id` (if identified) itself — a call site only ever passes the `AnalyticsEvent` and the relevant `AnalyticsProperties`, never the envelope fields by hand.

Neither implementation is wired into `main.dart`/`app.dart` by Step 2 — this step establishes the contract only. Step 3 wires whichever implementation is appropriate (almost certainly `NoopAnalyticsService`, until a vendor is chosen) into the app once it starts calling `track()` from real screens.

## 4. Property contract

`AnalyticsProperties` is one flat, all-nullable class — not one class per event. Which fields are REQUIRED for a given event is a **documented convention** (§6 below), not something the Dart type system enforces per-event; a per-event class hierarchy would be exactly the "large analytics framework" this step was told not to build, for no correctness benefit a documented convention doesn't already provide. `event_name`/`timestamp`/`schema_version`/`session_id`/`user_internal_id` are never part of `AnalyticsProperties` — they're envelope data `track()` stamps itself (§3).

## 5. Event taxonomy

Preserved from `EVENTS_V2_ARCHITECTURE.md` §31.2 essentially unchanged — that list was already audited once against this exact taxonomy's own goals. Two of this step's own draft suggestions were considered and **not** adopted, for consistency reasons explained inline below. Grouped by category; `E` = client, `S` = server-emittable in a future phase, `D` = derived (never tracked directly) — see §10 for the full client/server/derived classification.

### Discovery

| Event | When | Class |
|---|---|---|
| `event_opened` | User explicitly navigates to and lands on Event Detail — see §13 for the precise boundary | E |
| `event_search_performed` | A search query is executed (never the query text itself — see §8) | E |
| `event_filter_applied` | A controlled-vocabulary filter (event type, country, etc.) is applied | E |

`event_impression` remains **deferred, not implemented** — `event_opened` is sufficient for every goal this taxonomy serves at MVP. See §14 for the impression definition to use *if* this is ever built.

### Host / place

| Event | When |
|---|---|
| `host_profile_opened` | User navigates to a Restaurant/Hotel/Private Chef profile |
| `follow_added` | After a `follows_*` INSERT succeeds |
| `follow_removed` | After a `follows_*` DELETE succeeds |

Follow's entity type is the `entityType` **property** (`restaurant`/`hotel`/`privateChef`), never three separate event-name families — already correct in the original taxonomy, no change needed. **Not adopted**: this step's own draft suggested `follow_created`; preserving `follow_added` (already established) instead, for consistency with `event_interested_added`/`event_going_added`'s identical `_added`/`_removed` pairing — introducing a third verb for the same semantic role would fragment the taxonomy's own internal naming convention for no benefit.

### Event intent (Interested / Going)

| Event | When |
|---|---|
| `event_interested_added` | After `event_attendance` UPDATE/INSERT to `status='interested'` succeeds |
| `event_interested_removed` | After the row's removal or transition away from `interested` succeeds |
| `event_going_added` | After `event_attendance` UPDATE/INSERT to `status='going'` succeeds |
| `event_going_removed` | After the row's removal or transition away from `going` succeeds |

**Track only after the transactional write succeeds — never as the state transition itself, never speculatively.** Mandatory for Step 3; see §11.

### Ticketing

| Event | When |
|---|---|
| `ticket_link_opened` | See §15 for the exact boundary |

Means **only** "the user opened the external ticket/booking destination from Mantelier." Never implies purchase, booking, or revenue — see §17.

### Venue link clicks

| Event | When | Class |
|---|---|---|
| `venue_booking_link_opened` | A Restaurant/Hotel's own `website_url` or `booking_url` link is opened from that venue's Detail screen — after `launchUrl` returns `true`, same §15 boundary as `ticket_link_opened` | Client + server-persisted |

**Not the same event as `ticket_link_opened`**, deliberately: that event is scoped to an Event's own ticket/booking destination; this one is scoped to a Restaurant/Hotel's own website/booking link, opened from that venue's own Detail screen, with no Event in the picture at all. Conflating the two would make it impossible to answer "how many people clicked through to this restaurant's booking page" without also counting Event ticket opens, or vice versa.

**The narrow exception to §2/§18's "analytics is never persisted server-side" default**: `venue_booking_link_opened` is the one event in this taxonomy that IS written to a Supabase table (`public.venue_link_clicks`, `supabase/migrations/20260829120000_add_venue_link_click_tracking.sql`) via a dedicated `SupabaseAnalyticsService` (`lib/core/analytics/supabase_analytics_service.dart`), injected only on Restaurant/Hotel Detail — every other screen, and every other event, still goes through `NoopAnalyticsService`. This is a deliberate, narrow build (a host/venue click-through reporting need), not the general analytics vendor decision described in §3/§20, which remains unmade. `venue_link_clicks` itself has no select policy for `anon` or `authenticated` at all — it is not user-readable data, and the only path any of it can leave that table is `public.venue_link_click_stats`, an aggregating, k-anonymity-suppressed view (rows with fewer than `venue_link_click_min_unique_users()` distinct clickers are omitted entirely) not currently granted to any client role either — see that migration's own header for the full reasoning.

### Attendance

| Event | When |
|---|---|
| `event_attendance_prompted` | The "Did you make it?" prompt is shown to the user |
| `event_attendance_confirmed` | After `event_confirmed_attendance` INSERT succeeds |
| `event_attendance_denied` | User answers "No" to the prompt (no database row is created for this — the denial itself is the meaningful signal) |

Carries `attendanceSource` (§6) mirroring `event_confirmed_attendance.source` exactly (`manual`/`post_event_prompt`/`trip_completion`) on `event_attendance_confirmed`. **Not adopted**: this step's own draft suggested `attendance_prompt_shown`/`attendance_confirmed`/`attendance_declined`; preserving the `event_attendance_*` names (already established) instead, for consistency with every other Event-scoped event's `event_` prefix (`event_opened`, `event_interested_added`, `event_going_added`) — introducing an unprefixed family here would break that pattern without adding information.

### Content (on confirmed attendance)

| Event | When |
|---|---|
| `event_rating_added` | Fired on every save (create or update) of `event_confirmed_attendance.rating` — no separate "updated" event; see the original taxonomy's own reasoning (`EVENTS_V2_ARCHITECTURE.md` §31.2) |
| `event_photo_added` | A photo is attached to a confirmed attendance |
| `event_comment_added` | A comment is saved on a confirmed attendance |
| `event_recommendation_added` | Events V2 Step 4.1. Fired on every save that results in a definite Yes/No `event_confirmed_attendance.would_recommend` value — first answer AND changing an existing answer both fire this one event, same "no separate updated event" convention as `event_rating_added` above |
| `event_recommendation_removed` | Events V2 Step 4.1. Fired only when a save changes `would_recommend` from a definite Yes/No back to `NULL` — i.e. an existing answer was deliberately cleared. **Not adopted**: reporting a null update as `event_recommendation_added` with no value — that would misrepresent "the user removed their answer" as "the user just told us something." Never fired when the value was already `NULL` (nothing to remove) |

### Trips

| Event | When |
|---|---|
| `trip_event_added` | An event is added to a trip (`planned_venues`, `entity_type='event'`) |
| `trip_restaurant_added` | A restaurant is added to a trip |
| `trip_hotel_added` | A hotel is added to a trip |
| `trip_review_opened` | The post-trip review flow (§3 of the architecture doc) becomes visible |
| `trip_item_confirmed` | A plan item's post-trip "yes" answer is saved |
| `trip_item_rejected` | A plan item's post-trip "no" answer is saved (`planned_venues.status → cancelled`) |

**Not adopted**: no separate `trip_item_attendance_confirmed` event. A trip item confirmed as an event ("yes, I made it") already fires both `trip_item_confirmed` (the trip-funnel outcome) and `event_attendance_confirmed` with `attendanceSource=tripCompletion` (the Attendance-funnel outcome, §5's Attendance table) — a third, narrower event describing the same single action would be redundant, not a useful addition, and this taxonomy is optimized for usefulness, not volume.

### Passport

| Event | When |
|---|---|
| `passport_item_created` | A `visits` row or `event_confirmed_attendance` row is created |
| `passport_item_removed` | Either is deleted |

**Explicit decision**: kept as a **separate, generic, cross-entity-type** event alongside `event_attendance_confirmed`, not merged into it — the two answer different questions. `event_attendance_confirmed` is Event-specific (funnel analysis: did this Event convert intent into confirmed attendance). `passport_item_created` is entity-type-agnostic (fires identically for a restaurant visit, a hotel stay, or an event attendance) and is what the "Passport growth" Core metric (§18) actually aggregates — a restaurant visit alone has no Event-scoped equivalent to fire, so this generic event is the only signal that metric can use. Both are correct; neither is redundant.

### Friends

| Event | When |
|---|---|
| `friends_signal_opened` | User opens an event/host discovered via a friend signal |

Carries `sourceContext=friendSignal` + `friendSignalType` (§6) — never a friend's identity. `event_opened` with `sourceSurface=friendActivity`/`sourceContext=friendSignal` is sufficient for most friend-influenced-discovery analysis; `friends_signal_opened` exists only for the case where the user opens the *friends list/signal itself* (e.g. "4 friends interested" → tap → friend list), not the event.

## 6. Property contract

`REQUIRED` = must be present whenever the event that lists it fires (excluding the always-present envelope fields, §3). `OPTIONAL` = include when known/relevant. `DO_NOT_TRACK` = never, under any circumstance — see §7.

| Property | Type | Classification | Notes |
|---|---|---|---|
| `entityType` / `entityId` | `AnalyticsEntityType` / `String` | REQUIRED on Follow, Trip-item, Passport-item events; also REQUIRED on `venue_booking_link_opened` (the venue) | the entity the action concerns |
| `linkDestination` | `AnalyticsLinkDestination` | REQUIRED on `venue_booking_link_opened` | `website` or `booking` — which link was opened |
| `sourceScreen` | `AnalyticsVenueDetailScreen` | REQUIRED on `venue_booking_link_opened` | `restaurant_detail` or `hotel_detail` — explicit call-site data, not derived from `entityType` |
| `eventId` | `String` | OPTIONAL | `venue_booking_link_opened` only — set only if the click happened from an event context; unused by any call site today |
| `sourceSurface` | `AnalyticsSourceSurface` | REQUIRED on discovery/open events | §9 |
| `sourceContext` | `AnalyticsSourceContext` | OPTIONAL | only when more specific than the surface alone |
| `hostType` / `hostId` | `AnalyticsEntityType` / `String` | OPTIONAL, single-host events **only** | never populate for a zero- or multi-host event — see §10 |
| `hostCount` | `int` | OPTIONAL | always safe to include when known, regardless of host count |
| `city` / `countryCode` | `String` | OPTIONAL | the event's/venue's location — never the user's |
| `eventCategory` | `String` | OPTIONAL | `events.event_type` verbatim |
| `admissionType` | `String` | OPTIONAL | `events.admission_type` verbatim |
| `priceBucket` | `PriceBucket` | OPTIONAL | coarse only — never an exact amount |
| `tripId` | `String` | OPTIONAL | Trip-funnel events only |
| `followedHost` | `bool` | OPTIONAL | discovery events only |
| `positionInFeed` | `int` | OPTIONAL | unused until impression tracking is built (§14) |
| `friendSignalType` | `FriendSignalType` | OPTIONAL | *what kind* of friend signal — never *which* friend |
| `attendanceSource` | `AttendanceSource` | REQUIRED on `event_attendance_confirmed` | mirrors the DB column exactly |
| `resultsCount` | `int` | OPTIONAL | `event_search_performed` only — a count, never the query text |
| `wouldRecommend` | `bool` | OPTIONAL | Events V2 Step 4.1. `event_recommendation_added` only — the new Yes/No value being reported. Never populated on `event_recommendation_removed` (there is no value once cleared — sending a stale `true`/`false` there would misrepresent a removal as a fresh answer) |

Two properties added in Step 2, not present in the architecture document's original property list: `attendanceSource` (needed to align with the Step 1 database's own `source` constraint, per this step's explicit instruction) and `hostCount` (needed for the host-attribution correctness requirement, §10). Both are additive — nothing in the original list changed meaning. `wouldRecommend` was added in Step 4.1 for the same reason: it mirrors a new DB column (`event_confirmed_attendance.would_recommend`), and the boolean value itself was explicitly approved for analytics (§9 below) rather than left DO_NOT_TRACK by default.

## 7. Do-not-track

Never, under any circumstance, in any analytics payload: event/visit/trip notes, private comments, enquiry message content, raw search free text (§8), photo content or URLs, phone numbers, email addresses, names, friend user IDs, exact GPS coordinates, sensitive profile fields, ticket URLs containing user/session identifiers, Supabase auth tokens. `AnalyticsProperties`' closed field set makes most of this structurally impossible to pass by accident — there is no field to put a name or a note into.

## 8. Search analytics — explicit decision

**Decision: Option A — do not track raw search text at all, at MVP.** `event_search_performed` fires with `resultsCount` only (a plain integer, never the query). No goal in §31.1 of the architecture document requires the literal query text, and free-text search can incidentally contain personal or unexpected information (a name, a private note-like phrase) with no product benefit to justify collecting it. `event_filter_applied` may carry the filter's controlled-vocabulary value (e.g. `eventCategory`) since that's never free text — only ever one of a fixed, known set of values.

## 9. Attribution model

`sourceSurface` (§6) is the MVP attribution model: **session-scoped, last-touch** — the surface the user was on immediately before the tracked action. Never multi-touch, never "first ever discovery" (that needs either a persisted first-seen record or a warehouse join across historical raw events — not justified before any product decision depends on the distinction).

Funnel: `event_opened → event_interested_added/event_going_added → ticket_link_opened → event_attendance_confirmed`. Tracked for analysis, **never** treated as proof of causation between adjacent steps — a ticket click never implies purchase, Going never implies attendance, attendance never implies ticket conversion (§17).

**Discovery vs. interaction attribution**: a single `sourceSurface` per event is sufficient at MVP — do not build separate `discoverySource`/`interactionSource` fields. Each event in the funnel carries its *own* immediate `sourceSurface` (e.g. `event_going_added` carries whatever surface the user was on *when they tapped Going*, which is normally Event Detail itself, not wherever they originally discovered the event) — reconstructing "the original discovery surface that eventually led to this Going" is a warehouse-side join across a user's `event_opened` history for that `entityId`, not something every downstream event needs to carry forward itself.

## 10. Host attribution

**HOST ≠ VENUE, and an event may have zero, one, or many hosts** (`is_host=true` rows can exist independently across `event_restaurants`/`event_hotels`/`event_chefs` — Step 1 §6.3). A bare single `hostId` property would misattribute a multi-host event to whichever one happened to be picked, which is worse than no attribution at all.

**Rule**: populate `hostType`/`hostId` **only** when exactly one canonical `is_host=true` row exists for the event. Leave both `null` for zero-host and multi-host events. Always populate `hostCount` when host data is available, regardless — this is what lets a genuinely multi-host event still be aggregated server-side (by `entityId` → join `event_restaurants`/`event_hotels`/`event_chefs` → count/list hosts) without any client-side event ever having asserted a false single host.

## 11. Successful-write rule (mandatory for Step 3+)

For any event representing a database state change — Interested, Going, Follow, confirmed Attendance — **`track()` is called only after the corresponding Supabase write has already succeeded.** If the write fails, **no** success event fires. This is not optional and not a style preference — it's the mechanism that keeps analytics from ever drifting out of sync with the database it's supposed to be a read-only echo of. Future error/failure telemetry, if ever built, is a **separate** signal — never mixed into the same success-event stream.

```dart
final row = await repository.setEventIntent(status: EventIntentStatus.going, ...);  // 1. write (throws on failure)
// 2. echo, only reached if the write above succeeded
analytics.track(AnalyticsEvent.eventGoingAdded, properties);
```

(Illustrative shape only — Step 3's actual implementation, `EventDetailScreen._handleIntentTap`, wraps the write in a try/catch and only reaches the `track()` call inside the success path, per this section's own rule. `setEventIntent` is a single typed method for both Interested and Going, not a `markGoing`-style per-status method — see the Step 3 implementation report for the full repository API.)

## 12. Identity

`identify(userInternalId)` — always `auth.uid()`, never email/name/phone, never a raw Supabase auth token. `resetIdentity()` — called on sign-out/account switch; subsequent `track()` calls report session-only (anonymous) until the next `identify()`. No anonymous pre-login tracking is built in this phase — nothing in this taxonomy's goals requires distinguishing anonymous sessions before a first login-driven baseline exists, and this app has no meaningful pre-login browsing surface to instrument anyway. No elaborate anonymous→known merging is built — out of scope until a concrete need exists.

## 13. Event open — precise definition

`event_opened` fires **exactly once**, when the user's explicit navigation to Event Detail completes and the screen becomes visible to them. It does **not** fire for: a card rendering in a list (even off-screen), hero-image preloading, a route being constructed but never actually shown (e.g. a cancelled navigation), or a rebuild of an already-open Event Detail screen. Implementation guidance: fire from the screen's own lifecycle at the point the screen is confirmed on-screen following a real navigation (not from `initState` alone, which can run before the transition completes) — consistent with how this event has always been described in the architecture document, made precise here.

## 14. Impression definition (deferred, documented for future reference only)

**Not implemented in MVP** — `event_opened` is sufficient for every current goal, and impression tracking adds real client-side complexity for a signal nothing in this taxonomy needs yet (`EVENTS_V2_ARCHITECTURE.md` §31.18). If this is ever built, the contract should be: a card counts as an impression only once it becomes *meaningfully visible* (a real viewport-visibility threshold, not "was in the widget tree"), deduplicated per screen-session (the same card scrolling in and out of view repeatedly within one screen visit counts once). `positionInFeed` (§6) is reserved for this future use and unused until then.

## 15. Ticket-link open — exact boundary

Fire `ticket_link_opened` **after `launchUrl` returns `true`** (the actual OS-level launch attempt succeeded) — not merely after the user taps the button, and not merely after `canLaunchUrl` returns `true` (which only confirms *capability*, not that an attempt was actually made). This codebase's existing external-link pattern (`_openUrl`/`_openMaps`/`_openCall` across Restaurant/Hotel Detail) already computes this exact boolean via `await launchUrl(...)` but doesn't currently branch on it — Step 3+'s ticket-link implementation should check it (a small, justified addition to the existing pattern, since the value is already computed for free and materially improves analytics truthfulness at zero extra cost).

## 16. North Star

**Unchanged**: *Monthly Confirmed Experiences per Active User* (restaurant visits + hotel stays + confirmed event attendances, summed, ÷ monthly active users) — re-evaluated in this step and confirmed as the best available choice; not changed merely to make this step look different from the architecture document. The per-user denominator is what prevents the metric from rewarding pure event-volume/lower-quality proliferation.

## 17. Supporting KPIs and commercial terminology

| Metric | Formula |
|---|---|
| Event Detail Open Rate | `event_opened` ÷ `event_impression`-equivalent reach (until impressions exist: not computable, tracked as a future gap) |
| Interested Rate | distinct users with `status='interested'` ÷ distinct `event_opened` users, per event |
| Going Rate | distinct users with `status='going'` ÷ distinct `event_opened` users, per event |
| Ticket Intent Rate | distinct `ticket_link_opened` users ÷ distinct `event_opened` users, per event |
| Confirmed Attendance Rate | distinct `event_confirmed_attendance` rows ÷ distinct `status='going'` users, per event |
| Friend-Influenced Event Discovery Rate | `event_opened` where `sourceContext=friendSignal` ÷ all `event_opened`, per period |
| Follow → Event Engagement Rate | distinct users who `event_opened` a followed host's event within N days of `follow_added` ÷ distinct `follow_added` users |
| Trip → Confirmed Experience Rate | `trip_item_confirmed` ÷ (`trip_event_added` + `trip_restaurant_added` + `trip_hotel_added`), per trip |

**Precise host-facing terminology — never overstate:**

| Say | Never say |
|---|---|
| Event impressions / Event Detail views | — |
| Interested users | "leads" (unless the business later explicitly defines and validates that term) |
| Going users | "attendance" |
| Ticket-link opens | "ticket sales" / "tickets sold" |
| Confirmed attendance | "verified attendance" (it's self-reported, never checked-in) |

## 18. Client / server / derived classification

| Event | Class | Rationale |
|---|---|---|
| `event_opened`, `event_search_performed`, `event_filter_applied`, `ticket_link_opened`, `host_profile_opened`, `trip_review_opened`, `friends_signal_opened` | **Client** | inherently a UI moment with no reliable server-side equivalent |
| `follow_added`/`removed`, `event_interested_added`/`removed`, `event_going_added`/`removed`, `event_attendance_confirmed`, `event_attendance_denied`, `passport_item_created`/`removed` | **Client at Step 3, server-emittable in a future phase** | Step 3 fires these client-side immediately after a successful write (§11); a future phase may move them server-side (a Postgres trigger/edge function reacting to the write) for stronger guarantees against a client crashing between write and track-call — not required for Step 3, documented as the long-term intended source |
| `event_rating_added`, `event_photo_added`, `event_comment_added`, `event_recommendation_added`, `event_recommendation_removed` | **Client**, same successful-write rule | |
| `trip_event_added`/`trip_restaurant_added`/`trip_hotel_added`/`trip_item_confirmed`/`trip_item_rejected` | **Client**, same successful-write rule | |
| Host/venue/destination aggregate metrics (§17) | **Derived** | never tracked directly — always a query-time aggregation over the raw event stream and/or transactional tables |

No server-side analytics implementation exists or is built in this step (per explicit instruction) — this table documents the *intended long-term source* for Step 3+ and beyond, not current behavior. **One exception, added later, narrow in scope**: `venue_booking_link_opened` (see its own "Venue link clicks" section above) genuinely is written to `public.venue_link_clicks` today, via `SupabaseAnalyticsService` on Restaurant/Hotel Detail only — not a change to this table's general statement about the rest of the taxonomy, which remains entirely unimplemented server-side.

## 19. Schema versioning

`analyticsSchemaVersion` (currently `1`, `lib/core/analytics/analytics_event.dart`) is stamped on every event by `track()` itself. **Adding** a new `AnalyticsEvent` or `AnalyticsProperties` field never requires a bump. **Changing what an existing event or property means** always does — retire the old meaning under a new name wherever feasible rather than silently reinterpreting an existing name at the same version.

## 20. Provider requirements (for the future decision — none selected here)

| Requirement | Why it matters |
|---|---|
| Flutter SDK quality | first-class, maintained client SDK |
| EU hosting / data residency | matches this app's likely user base and GDPR posture |
| GDPR tooling (deletion APIs, export) | account-deletion cascade must be implementable |
| Funnels / cohorts / retention | this taxonomy is funnel-shaped by design |
| Feature flags | useful, not required |
| Session replay | explicitly optional and privacy-sensitive — do not default to enabling if the chosen provider offers it |
| Data export / warehouse export | keeps this app's own data portable, avoids lock-in |
| Identity controls | must support `identify`/`reset` semantics cleanly |
| Cost at early scale vs. larger scale | both matter — early cost shouldn't block adoption, scaling cost shouldn't surprise later |
| Startup complexity | the whole point of §3's abstraction is that this can be deferred without cost |

Candidates worth evaluating when the decision is made: PostHog, Amplitude, Mixpanel, a Supabase-native event table (see `EVENTS_V2_ARCHITECTURE.md` §31.15 for the fuller comparison). **No recommendation is made here** — insufficient evidence for a real choice at this stage, and none is needed given the abstraction.

## Implementation guidance for Step 3+

1. Perform the Supabase write first. Confirm success.
2. Only then call `analytics.track(event, properties)` — never before, never on failure (§11).
3. Build `AnalyticsProperties` from data already in hand at the call site — never an extra query solely to populate an analytics property.
4. Use `NoopAnalyticsService` as the wired implementation until a vendor is chosen — do not block feature work on the provider decision.
5. Never import a vendor SDK directly in feature code, ever, regardless of urgency.
6. If a new event or property is genuinely needed, add it to `AnalyticsEvent`/`AnalyticsProperties` and this document together, in the same change — never introduce a raw string event name as a shortcut.
7. If an existing event's meaning would change, bump `analyticsSchemaVersion` and consider a new event name instead (§19).
