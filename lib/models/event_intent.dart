// Events V2 Step 3 — the Interested/Going intent state machine, kept as
// pure, top-level functions (mirroring canAttendEvent/eventMatchesTrip's
// own established pattern in this codebase) so it's unit-testable without
// a live Supabase session or a widget pump.
//
// The three canonical states are NONE / INTERESTED / GOING. NONE is
// deliberately represented as a nullable EventIntentStatus? rather than a
// third enum member: `public.event_attendance` never stores a 'none' row
// — the state is the absence of a row, not a value inside one — so a
// nullable status mirrors the database's own reality exactly rather than
// inventing a value nothing is ever written as.

import '../core/analytics/analytics_event.dart';
import 'event_attendance.dart';

/// Derives `event_attendance.visibility` from the *target* intent status —
/// never independently settable by a caller, and never preserved across a
/// transition. Both Going and Interested are friends-visible as of Events
/// V2 Step 7 — an event is already public catalogue content, so either
/// intent is lower-sensitivity than a private rating, and Step 7's own
/// product requirement is that accepted friends can see both signals
/// consistently (Friends Going and Friends Interested read as two states
/// of the same social system, not one visible and one hidden).
///
/// Step 3 originally kept Interested private-by-default in MVP; Step 7
/// changes that default for FUTURE writes only (this function is the
/// single place the value is derived — see [EventAttendanceRepository
/// .setEventIntent], the only caller). No backfill accompanies this
/// change: production held zero Interested rows at the time of the Step 7
/// architecture audit, and even in general the safer transition is
/// future-writes-only — a user who marked Interested under the old
/// private default should never have that historical row silently
/// broadened without their own re-action (re-tapping Interested, which
/// already goes through this same function on the next write).
AttendanceVisibility visibilityForIntent(EventIntentStatus status) =>
    switch (status) {
      EventIntentStatus.going => AttendanceVisibility.friends,
      EventIntentStatus.interested => AttendanceVisibility.friends,
    };

/// The entire Interested/Going state machine in one pure function.
/// Tapping the currently-selected status removes intent (→ null, NONE).
/// Tapping any other status selects it — NONE → that status directly, or
/// a switch away from whatever the current status was. No other
/// transition exists; every legal (NONE→INTERESTED, NONE→GOING,
/// INTERESTED→GOING, GOING→INTERESTED, INTERESTED→NONE, GOING→NONE) and
/// only those six is reachable by calling this with every combination of
/// [current] and [tapped].
EventIntentStatus? resolveIntentTap({
  required EventIntentStatus? current,
  required EventIntentStatus tapped,
}) => current == tapped ? null : tapped;

/// The ordered [AnalyticsEvent]s a transition from [previous] to [next]
/// should fire, per `EVENTS_V2_ANALYTICS_CONTRACT.md`'s own event
/// definitions: `event_interested_removed`/`event_going_removed` fire "on
/// the row's removal OR TRANSITION AWAY FROM" that status — not only on
/// an outright removal. A switch between Interested and Going is therefore
/// TWO analytics echoes (a removed echo for the status left behind, an
/// added echo for the status entered) even though it is a single database
/// UPDATE, not two writes — this is the explicit, contract-derived
/// decision Events V2 Step 3 makes, not an invented one. Returns an empty
/// list when [previous] == [next] (never produced by [resolveIntentTap]
/// itself, but this function makes no assumption about its caller).
List<AnalyticsEvent> intentAnalyticsEvents({
  required EventIntentStatus? previous,
  required EventIntentStatus? next,
}) {
  if (previous == next) return const [];
  return [
    if (previous != null) _removedEventFor(previous),
    if (next != null) _addedEventFor(next),
  ];
}

AnalyticsEvent _addedEventFor(EventIntentStatus status) => switch (status) {
  EventIntentStatus.interested => AnalyticsEvent.eventInterestedAdded,
  EventIntentStatus.going => AnalyticsEvent.eventGoingAdded,
};

AnalyticsEvent _removedEventFor(EventIntentStatus status) => switch (status) {
  EventIntentStatus.interested => AnalyticsEvent.eventInterestedRemoved,
  EventIntentStatus.going => AnalyticsEvent.eventGoingRemoved,
};
