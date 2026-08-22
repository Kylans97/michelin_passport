// Events V2 Step 4 — the Confirmed Attendance / post-event "Did you make
// it?" eligibility rules, kept as pure, top-level functions (mirroring
// canAttendEvent/eventMatchesTrip/event_intent.dart's own established
// pattern in this codebase) so they're unit-testable without a live
// Supabase session or a widget pump.
//
// Eligibility is always keyed off a precise "has this Event ended" instant
// — never a rendered/event-local date, never the viewer's device time.
// Events V2 Time Precision Phase B: that instant is now
// [eventEndReferenceInstant] (core/utils/event_time.dart) rather than a
// bare `event.endAt` — the exact instant when known (identical behavior to
// before Phase B for every full-precision Event), or the local-day-end of
// [Event.endDate] when [Event.endAt] is unknown. This is exactly the same
// rule event_detail_screen.dart's own canAttendEvent doc comment already
// commits this codebase to.

import '../core/utils/event_time.dart';
import 'event.dart';
import 'event_attendance.dart';

/// How far past an Event's end the UNPROMPTED surfaces (today: the Events
/// screen's own top-of-list nudge) will still surface a "Did you make
/// it?" prompt. A restrained MVP default, not a guess pulled from
/// nowhere: 30 days comfortably covers "I forgot to confirm right after"
/// without ever asking about something from many months ago (this
/// module's own doc comment on [AttendanceUiState.manualOnly] is the
/// explicit example this guards against). The manual "I attended this"
/// affordance on Event Detail deliberately has NO window — see
/// [resolveAttendanceUiState] — a user should always be able to
/// self-report attendance to a past event, however old.
const attendancePromptLookbackWindow = Duration(days: 30);

/// The four mutually-exclusive states Event Detail's own completed-event
/// section can be in for the signed-in viewer. A single resolver function,
/// not scattered boolean checks, so the same rule can't drift between
/// call sites (Event Detail vs. any future surface).
enum AttendanceUiState {
  /// No confirmed attendance exists, AND the event hasn't ended yet, OR
  /// the event is cancelled — no attendance UI of any kind renders.
  /// Mirrors [Event.isCancelled] and the same `endAt` instant
  /// [canAttendEvent] itself already uses (see that function's own doc
  /// comment in event_detail_screen.dart). Events V2 Step 5 bugfix: this
  /// state is reached only when [hasConfirmedAttendance] is false — a
  /// genuinely confirmed attendance always resolves to [attended]
  /// instead, regardless of the event's current cancelled/ended state
  /// (see [resolveAttendanceUiState]'s own doc comment).
  none,

  /// A confirmed attendance row already exists for this (event, viewer)
  /// pair — render the "Attended" / manage state, never a prompt or a
  /// manual CTA.
  attended,

  /// Event ended, viewer's own intent was GOING, no confirmed attendance
  /// yet, and still within [attendancePromptLookbackWindow] — the full
  /// Yes/No/Not-now prompt renders (source will be `postEventPrompt` on
  /// Yes).
  promptable,

  /// Event ended, no confirmed attendance yet, and NOT [promptable] —
  /// either the viewer was never GOING (Interested-only, or no intent at
  /// all — §7's explicit "must not require a pre-existing Going row"), or
  /// they were GOING but the lookback window has passed (an old Going row
  /// from 18 months ago must never resurrect a "did you make it?" prompt —
  /// see the module-level doc comment). A plain, non-intrusive manual "I
  /// attended this" affordance still renders (source will be `manual`).
  manualOnly,
}

bool _hasEnded(Event event, DateTime now) => eventHasEnded(
  endAt: event.endAt,
  endDate: event.endDate,
  timezone: event.timezone,
  now: now,
);

// The lookback window counts from the same "when did this Event actually
// end" reference instant [_hasEnded] itself uses — exact endAt when known,
// else the local-day-end of endDate — never a raw endAt that may not
// exist.
bool _withinPromptWindow(Event event, DateTime now) => !now.isAfter(
  eventEndReferenceInstant(
    endAt: event.endAt,
    endDate: event.endDate,
    timezone: event.timezone,
  ).add(attendancePromptLookbackWindow),
);

/// The single source of truth for what Event Detail's completed-event
/// section should show. [intent] is the viewer's own current
/// `event_attendance.status` (null = NONE, matching event_intent.dart's
/// own convention).
///
/// Events V2 Step 5 bugfix: [hasConfirmedAttendance] is checked FIRST,
/// before [Event.isCancelled] or whether the event "has ended" — a
/// confirmed attendance is a record of a past fact, and a later change
/// to the event's own lifecycle state (e.g. an organizer marking it
/// cancelled after the fact) must never retroactively hide that the
/// viewer actually attended. Without this ordering, a cancelled-after-
/// the-fact event would incorrectly fall through to [AttendanceUiState.
/// none] and hide the viewer's rating, would-recommend, photos, and
/// "Edit your experience" / "Remove from Passport" affordances, even
/// though the underlying `event_confirmed_attendance` row and Passport
/// listing are untouched. A cancelled event with NO confirmed
/// attendance still correctly resolves to [AttendanceUiState.none] —
/// cancellation only ever suppresses the *prompt*/*manual* paths, never
/// an attendance that already happened.
AttendanceUiState resolveAttendanceUiState({
  required Event event,
  required EventIntentStatus? intent,
  required bool hasConfirmedAttendance,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (hasConfirmedAttendance) return AttendanceUiState.attended;
  if (event.isCancelled) return AttendanceUiState.none;
  if (!_hasEnded(event, n)) return AttendanceUiState.none;
  if (intent == EventIntentStatus.going && _withinPromptWindow(event, n)) {
    return AttendanceUiState.promptable;
  }
  return AttendanceUiState.manualOnly;
}

/// Picks the single event an UNPROMPTED surface (the Events screen's top
/// card) should nudge about, from the viewer's own past-GOING events.
/// [pastGoingEvents] may include events outside the lookback window,
/// cancelled events, or events already confirmed — this function applies
/// every eligibility rule itself rather than trusting a pre-filtered
/// caller, so a future caller can pass a broader query result safely.
/// Ties (same end reference instant) break by `id` for a fully
/// deterministic order — an arbitrary but stable choice, never "whatever
/// order the database returned them in."
///
/// Returns null when nothing is eligible — callers must render nothing at
/// all in that case (§24's explicit "never stack, never show more than
/// one" rule starts from "show at most one," and null is the "show
/// zero" case that rule already implies).
Event? mostRecentEligibleAttendancePromptEvent({
  required List<Event> pastGoingEvents,
  required Set<String> confirmedEventIds,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final eligible =
      pastGoingEvents
          .where(
            (e) =>
                !e.isCancelled &&
                _hasEnded(e, n) &&
                _withinPromptWindow(e, n) &&
                !confirmedEventIds.contains(e.id),
          )
          .toList()
        ..sort((a, b) {
          final aEnd = eventEndReferenceInstant(
            endAt: a.endAt,
            endDate: a.endDate,
            timezone: a.timezone,
          );
          final bEnd = eventEndReferenceInstant(
            endAt: b.endAt,
            endDate: b.endDate,
            timezone: b.timezone,
          );
          final byEnd = bEnd.compareTo(aEnd);
          return byEnd != 0 ? byEnd : a.id.compareTo(b.id);
        });
  return eligible.isEmpty ? null : eligible.first;
}
