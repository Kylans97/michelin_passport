import '../core/utils/event_time.dart' show compareCalendarDates;
import 'event.dart';
import 'event_chronology.dart';
import 'planned_trip.dart';
import 'trip_destination.dart';

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
/// 2. Date ranges must overlap, compared by CALENDAR DATE, never an exact
///    instant. Events V2 Time Precision Phase B: [Event.startDate]/
///    [endDate] are already the event's own correct local calendar dates
///    (see event.dart — computed once, at construction/backfill time, via
///    the event's own timezone) — this function no longer derives them
///    itself from [Event.startAt]/[endAt], which also makes it correct
///    for a date-only Event with no exact instants at all.
///    [trip.startDate]/[endDate] are already day-granularity dates with no
///    time component. The overlap check uses [compareCalendarDates] —
///    zone-tag-agnostic on purpose: [Event.startDate] is always
///    UTC-tagged, but [PlannedTrip.startDate]/[endDate] are parsed via a
///    bare `DateTime.parse` of a date-only string, which Dart resolves to
///    the DEVICE's local zone — comparing the two via ordinary
///    `DateTime.isAfter`/`.isBefore` would silently leak the device's own
///    UTC offset into what must be a pure calendar-date comparison.
///    [compareCalendarDates] only ever looks at (year, month, day),
///    structurally ruling that out.
/// 3. Country must match exactly.
/// 4. City: if BOTH the event and the trip specify a city, they must match
///    (case-insensitive) — this is the "city matching preferred when both
///    have a city" rule, read as a required discriminator once both sides
///    actually know a city, so a Maastricht trip doesn't surface an
///    Amsterdam-only event just because both are in the Netherlands. If
///    EITHER side's city is unknown, matching falls back to country-level
///    — a country-wide event with no city must still be discoverable, per
///    the task's explicit requirement.
///
/// Rules 2–4 apply only to a trip whose destinations weren't loaded (a
/// server without 20261022120000). A trip WITH destinations matches per
/// leg instead — see [firstLegMatchingEvent].
bool eventMatchesTrip(Event event, PlannedTrip trip) {
  if (event.isCancelled) return false;
  if (trip.destinations.isNotEmpty) {
    return firstLegMatchingEvent(event, trip) != null;
  }

  final datesOverlap =
      compareCalendarDates(event.startDate, trip.endDate) <= 0 &&
      compareCalendarDates(event.endDate, trip.startDate) >= 0;
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

/// Multi-destination trips (20261022120000, decision 2): an event matches
/// when it overlaps one leg's own dates (the whole trip's, for a leg
/// without dates) AND is in that leg's country. No city comparison per
/// leg: events carry only a free-text city, and comparing it with a
/// catalogue city's name would be matching on a name. Returns the first
/// such leg in itinerary order, or null; cancelled events never match.
TripDestination? firstLegMatchingEvent(Event event, PlannedTrip trip) {
  if (event.isCancelled) return null;
  for (final leg in trip.destinations) {
    final start = leg.startDate ?? trip.startDate;
    final end = leg.endDate ?? trip.endDate;
    final overlaps =
        compareCalendarDates(event.startDate, end) <= 0 &&
        compareCalendarDates(event.endDate, start) >= 0;
    if (overlaps &&
        event.countryCode.toUpperCase() == leg.countryCode.toUpperCase()) {
      return leg;
    }
  }
  return null;
}

List<Event> eventsMatchingTrip(List<Event> events, PlannedTrip trip) {
  final matches = events.where((e) => eventMatchesTrip(e, trip)).toList()
    ..sort(compareEventChronology);
  return matches;
}
