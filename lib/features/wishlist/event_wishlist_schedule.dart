import '../../core/utils/event_time.dart' show eventHasEnded;
import '../../models/event.dart';
import '../../models/event_chronology.dart';

/// EVENT WISHLIST V1 — the saved-events list split into UPCOMING (future
/// or currently ongoing) and PAST (already ended), sorted for display.
/// Deliberately a pure function (no Supabase dependency), matching this
/// codebase's established precedent for scheduling logic — [trip_schedule
/// .isUpcomingTrip]/[planned_visit_schedule.isUpcomingPlannedVenue] —
/// reused directly rather than duplicated: an ended Event is classified
/// via the exact same precision-aware [eventHasEnded] every other
/// lifecycle decision in this app already uses (exact instant when known,
/// else the local-day-end of [Event.endDate] in [Event.timezone]), and
/// both lists are ordered via the single canonical [compareEventChronology]
/// comparator — no separate date/timezone logic is invented here.
///
/// Wishlist is user intent/history, not a calendar-driven view: a past
/// saved Event is never dropped, only moved into [past] — sorted
/// most-recently-ended first, so the most relevant history surfaces at
/// the top of what's otherwise a visually secondary section.
class EventWishlistSchedule {
  final List<Event> upcoming;
  final List<Event> past;
  const EventWishlistSchedule({required this.upcoming, required this.past});
}

EventWishlistSchedule scheduleEventWishlist(
  List<Event> events, {
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final upcoming = <Event>[];
  final past = <Event>[];
  for (final event in events) {
    final ended = eventHasEnded(
      endAt: event.endAt,
      endDate: event.endDate,
      timezone: event.timezone,
      now: effectiveNow,
    );
    (ended ? past : upcoming).add(event);
  }
  // Nearest upcoming first.
  upcoming.sort(compareEventChronology);
  // Most recently ended first — reverse chronological.
  past.sort((a, b) => compareEventChronology(b, a));
  return EventWishlistSchedule(upcoming: upcoming, past: past);
}
