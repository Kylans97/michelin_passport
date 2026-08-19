# Events V2 — Step 3 Implementation Report: Interested + Going

**Status: implemented, not yet committed.** Full Interested/Going intent lifecycle on Event Detail — transactional state, UX, and analytics instrumentation. No database change (Step 1's `event_attendance` table, widened by `20260819141000_events_v2_attendance_interested_going.sql`, already supports this exactly as designed). No new analytics vendor, no confirmed Attendance, no Passport auto-add, no Follow UI, no navigation change — all explicitly out of scope for this step.

## Final state machine

Three canonical states — NONE / INTERESTED / GOING — modeled as `EventIntentStatus?` (`lib/models/event_attendance.dart`): `null` is NONE (the database's own reality — there is no `'none'` row, only the absence of one), `interested`/`going` mirror the two legal `event_attendance.status` values exactly.

The entire state machine is one pure function, `resolveIntentTap` (`lib/models/event_intent.dart`):

```dart
EventIntentStatus? resolveIntentTap({
  required EventIntentStatus? current,
  required EventIntentStatus tapped,
}) => current == tapped ? null : tapped;
```

Tapping the already-selected status removes it (→ NONE); tapping any other status selects it. All six legal transitions (NONE→INTERESTED, NONE→GOING, INTERESTED→GOING, GOING→INTERESTED, INTERESTED→NONE, GOING→NONE) and no others are reachable — unit-tested exhaustively in `test/event_intent_test.dart`. Interested and Going are never modeled as two independent booleans — one nullable status field, matching `event_attendance`'s own `unique(event_id, user_id)` row shape exactly.

## Visibility transition rules

Derived entirely from the *target* status, never preserved from a prior value — `visibilityForIntent` (`lib/models/event_intent.dart`):

| Target status | Visibility | Reasoning |
|---|---|---|
| `interested` | `private`, always | MVP product rule — Interested never friends-visible, full stop, regardless of what visibility a prior Going row carried |
| `going` | `friends`, always | Unchanged from the existing Social Foundation Step 2B default — an event is public catalogue content, so intent to attend is lower-sensitivity than a private rating |

Concretely: GOING→INTERESTED resets to `private` (never blindly carries a friends-visible value onto a concept designed to stay private); INTERESTED→GOING sets `friends` (the same default a direct NONE→GOING would get). This is enforced at the repository layer — `setEventIntent` computes visibility internally; there is no caller-supplied visibility parameter to get wrong.

## Repository API

`EventAttendanceRepository` (`lib/data/repositories/event_attendance_repository.dart`), renamed/added this step:

| Method | Change |
|---|---|
| `getMyEventIntent({userId, eventId})` | renamed from `getMyAttendance` — same behavior, clearer name now that "Attendance" means something else (`event_confirmed_attendance`) |
| `setEventIntent({userId, eventId, status})` | **new** — single typed mutation for every NONE→X or X→Y transition; tries INSERT, falls back to UPDATE on a `unique(event_id, user_id)` violation (a switch or a re-tap), matching the existing idempotent-on-23505 pattern already used elsewhere in this codebase. No separate `markInterested()`/`markGoing()` pair. |
| `removeEventIntent({userId, eventId})` | renamed from `removeAttendance` |
| `getVisibleUserIds({eventId, status})` | renamed from `getVisibleAttendeeUserIds`, **and a required `status` filter added** — see Friends Going Compatibility below |
| `getFriendUpcomingEvents({userId, status})` | renamed from `getFriendUpcomingAttendance`, **and a required `status` filter added** — see below |

No raw status strings anywhere in UI code — every call site passes `EventIntentStatus.going`/`.interested`, never `'going'`/`'interested'` literals.

## Event Detail UX

`EventIntentControls` (`lib/features/events/widgets/event_intent_controls.dart`) replaces `EventGoingButton` — two compact pills ("Interested", "Going") in a `Wrap` (reflows to a second line rather than overflowing at high text scale/narrow width — a real 320px/1.6× overflow the widget's own test caught and the implementation fixed). Same visual language as the retired widget: outline = unselected (forest-green border/text), filled = selected (forest-green fill, ivory text/icon), never gold. A pill's own icon distinguishes selected/unselected (bookmark outline→filled for Interested, circle-outline→check for Going) — never color-only.

State exposed: `status` (persisted), `busy` (a mutation is in flight — both pills disabled), `pendingTarget` (which status the in-flight mutation targets — that pill shows selected+spinner; the other shows unselected; `null` while busy specifically means a removal is in flight, so neither pill shows a target). Non-optimistic: the confirmed `status` never changes until the write succeeds; a failed write simply clears the busy flags, which already restores the last confirmed appearance with no separate rollback step. Accessibility: `Semantics(selected: ...)` (the modern Flutter flag, not color-only) plus a "Tap to remove" hint on the selected pill.

Concurrency: `_intentBusy` guards `_handleIntentTap` against a second tap firing a competing mutation while one is already in flight — the same guard shape the retired `_toggleGoing` already used, extended to also gate both pills rather than one.

**Approved rapid-tap behavior, stated precisely** (a prior draft of this behavior in an earlier report described it ambiguously as "final state matches the last tap," which is not what this implementation does and has been corrected here): tapping Interested, then tapping Going before the first write completes, does **not** result in "last tap wins." Both pills are disabled (`enabled: !busy` on `EventIntentControls`) for the full duration of the in-flight mutation, so the second tap (Going) is a no-op and is silently dropped — it never reaches `_handleIntentTap` at all. The first mutation (Interested) completes, `_intentBusy` clears, and only then can the user tap Going again as a genuinely new, second action. This is a deliberate, simple "lock during mutation" design, not a queue and not last-write-wins — see §19 (Concurrency) of the original Step 3 brief for why this was the chosen approach over a mutation queue.

## Analytics — mutation semantics

Every transition emits its analytics only *after* the Supabase write succeeds (`EventDetailScreen._handleIntentTap` — write, await, `setState`, *then* `track()`; a thrown exception never reaches the tracking call). The exact events per transition — `intentAnalyticsEvents` (`lib/models/event_intent.dart`, unit-tested for all six transitions):

| Transition | Events fired (in order) |
|---|---|
| NONE→INTERESTED | `event_interested_added` |
| NONE→GOING | `event_going_added` |
| INTERESTED→GOING | `event_interested_removed`, then `event_going_added` |
| GOING→INTERESTED | `event_going_removed`, then `event_interested_added` |
| INTERESTED→NONE | `event_interested_removed` |
| GOING→NONE | `event_going_removed` |

**The switching decision, explicit**: a switch fires *two* events for one database `UPDATE`, not one. This isn't a new decision Step 3 invented — `EVENTS_V2_ANALYTICS_CONTRACT.md` §5 already defined `event_interested_removed`/`event_going_removed` as firing "on the row's removal **or transition away from** that status," and Step 3 simply implements that definition faithfully.

Properties populated (`EventDetailScreen._intentProperties`) — only data already in hand from the screen's own load, never an extra query: `entityType: event`, `entityId`, `sourceSurface`/`sourceContext` (below), `eventCategory`, `city`, `countryCode`, `admissionType`. `hostCount` and `availability_status` were evaluated per the brief's own property checklist and deliberately **not** populated this step — neither is reliably available without new data-fetching plumbing (`loadLinkedVenues` returns venue objects, not host flags; `availability_status` isn't parsed onto the `Event` model), and adding either solely to fill an optional analytics field would be scope creep this step's own boundary explicitly warns against.

**Attribution** — `EventDetailScreen` gained two optional constructor params, `sourceSurface`/`sourceContext` (`AnalyticsSourceSurface`/`AnalyticsSourceContext`, Step 2's canonical enums, never a raw string). Four known call sites updated:

| Call site | `sourceSurface` | `sourceContext` |
|---|---|---|
| `EventsScreen._openEvent` | `eventsFeed` | — |
| `ExploreScreen._openEvent` | `discover` | — |
| `TripDetailScreen._openEvent` | `tripRecommendation` | — |
| `friend_profile_screen.dart`'s `openFriendEvent` | `friendActivity` | `friendSignal` |

Explore's single call site covers both its "What's On" preview and inline search-result taps (one shared method, `discover` is the honest attribution for both — not split further, since the code has no way to distinguish them without a refactor this step doesn't otherwise need). No other call site was found. Where attribution is unknown, both fields stay `null` and are simply omitted from the analytics payload (`AnalyticsProperties.toMap`'s existing null-omission behavior) — never a guessed value.

## Friends Going compatibility

**A real, previously-latent bug, found and fixed, not merely "audited and left alone."** Before Step 1, `event_attendance.status` had exactly one legal value (`'going'`), so `getVisibleAttendeeUserIds`/`getFriendUpcomingAttendance` never needed to filter by status — any row for the event/user *was* a Going row by construction. Once Step 1 widened `status` to also allow `'interested'`, both queries would have silently returned Interested rows too, mislabeling them as Going in Friend Profile's "GOING" section and Event Detail's "Friends Going" section. Fixed by requiring an explicit `status` parameter on both (see Repository API above) — every existing call site (Friend Profile, `FriendGoingListScreen`, `EventDetailScreen`) now passes `status: EventIntentStatus.going` explicitly, and the bug can never resurface silently because the parameter is required, not defaulted.

Proof Interested doesn't leak: `friendsGoingToEvent` (the pure resolver) is unchanged and untested-as-changed because the fix lives entirely at the query layer, one level below it — `test/event_intent_test.dart` and the repository's own doc comments cover the reasoning; `test/friend_profile_going_section_test.dart`/`event_friends_going_section_test.dart` (presentation-only, unaffected) continue to pass unmodified.

**Readiness for future Friends Interested** (explicitly not built this step): both renamed methods already take `status` as a parameter — a future Friends Interested feature calls the exact same `getVisibleUserIds`/`getFriendUpcomingEvents` with `status: EventIntentStatus.interested` once its own privacy model is approved (Interested is private-by-default today, so it isn't friends-visible regardless — but the query-level filter is now a guarantee, not an accident of the visibility default).

## Web-readiness

Every business rule — the state machine (`resolveIntentTap`), the visibility rule (`visibilityForIntent`), the analytics-event mapping (`intentAnalyticsEvents`) — is a pure, platform-neutral Dart function in `lib/models/`, with zero Flutter widget or iOS/Android-specific code. `EventIntentControls` itself is presentational only, with no business logic of its own — it receives already-resolved state and reports taps upward. Supabase (`event_attendance`) remains the sole canonical store; `Event`/`EventAttendance` ids are the same stable UUIDs a future web client would read. The analytics taxonomy (Step 2) was already platform-neutral. Nothing in this step assumes a mobile-only data shape.

## Deferred (explicitly, per this step's own scope boundary)

Confirmed Attendance, post-event prompts, Passport auto-add, Trip-completion conversion, Friends Interested UI, Follow UI, notifications, ticket-purchase tracking, an analytics vendor, event impressions, navigation changes.
