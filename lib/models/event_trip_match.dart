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
/// 2. Date ranges must overlap: the event's [start_at, end_at) window
///    intersects the trip's [start_date, end_date] window (trip dates are
///    day-granularity, so the trip's own end date counts as a whole day).
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

  final tripStart = DateTime(
    trip.startDate.year,
    trip.startDate.month,
    trip.startDate.day,
  );
  // Exclusive upper bound covering the whole of the trip's last day.
  final tripEndExclusive = DateTime(
    trip.endDate.year,
    trip.endDate.month,
    trip.endDate.day + 1,
  );
  final datesOverlap =
      event.startAt.isBefore(tripEndExclusive) &&
      event.endAt.isAfter(tripStart);
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
