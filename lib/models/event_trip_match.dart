import '../core/utils/event_time.dart';
import 'event.dart';
import 'planned_trip.dart';

/// Pure trip/event matching — no Supabase dependency, so this is testable
/// in isolation and reusable for the future push-notification hook ("a new
/// culinary event was added during your planned trip") without any
/// architecture change: that hook would call this same function against
/// the single newly-inserted event and a user's trips, rather than
/// re-deriving the rule.
///
/// Rules (in order):
/// 1. A cancelled event never matches any trip — nothing "happening during
///    your trip" if it's been cancelled.
/// 2. Date ranges must overlap, compared by CALENDAR DATE, not exact
///    instant: event.startAt/endAt are absolute timestamptz instants — the
///    calendar date they fall on depends on WHICH zone you read them in.
///    A viewer in New York and the event's own venue in Tokyo can
///    legitimately disagree about which day a given instant falls on, and
///    a trip is planned against the destination's own calendar, not the
///    trip-planner's device zone — so both event dates are read via
///    eventLocalDateTime(event's own timezone), never device-local, before
///    truncating to Y-M-D. trip.startDate/endDate are already
///    day-granularity dates with no time component. Comparing full
///    DateTime instants between the two (e.g. an exclusive "day + 1" upper
///    bound) makes the match sensitive to time-of-day at the boundary for
///    no reason — a person reading "27-30 August" against "26-31 August"
///    is comparing whole days, so both sides are first truncated to Y-M-D
///    and checked for inclusive date-range overlap.
/// 3. Country must match exactly.
/// 4. City: if BOTH the event and the trip specify a city, they must match
///    (case-insensitive) — this is the "city matching preferred when both
///    have a city" rule, read as a required discriminator once both sides
///    actually know a city, so a Maastricht trip doesn't surface an
///    Amsterdam-only event just because both are in the Netherlands. If
///    EITHER side's city is unknown, matching falls back to country-level
///    — a country-wide event with no city must still be discoverable, per
///    the task's explicit requirement.
bool eventMatchesTrip(Event event, PlannedTrip trip) {
  if (event.isCancelled) return false;

  final eventStart = _dateOnly(
    eventLocalDateTime(event.startAt, event.timezone),
  );
  final eventEnd = _dateOnly(eventLocalDateTime(event.endAt, event.timezone));
  final tripStart = _dateOnly(trip.startDate);
  final tripEnd = _dateOnly(trip.endDate);
  final datesOverlap =
      !eventStart.isAfter(tripEnd) && !eventEnd.isBefore(tripStart);
  if (!datesOverlap) return false;

  if (event.countryCode.toUpperCase() != trip.countryCode.toUpperCase()) {
    return false;
  }

  final eventCity = event.city?.trim();
  final tripCity = trip.city?.trim();
  if (eventCity != null &&
      eventCity.isNotEmpty &&
      tripCity != null &&
      tripCity.isNotEmpty) {
    return eventCity.toLowerCase() == tripCity.toLowerCase();
  }
  return true;
}

/// Every event in [events] that matches [trip], chronologically sorted —
/// what "CULINARY EVENTS DURING YOUR TRIP" renders directly.
List<Event> eventsMatchingTrip(List<Event> events, PlannedTrip trip) {
  final matches = events.where((e) => eventMatchesTrip(e, trip)).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  return matches;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
