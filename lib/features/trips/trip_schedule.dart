import '../../core/utils/event_time.dart' show compareCalendarDates;
import '../../models/planned_trip.dart';

/// TRIPS HERO REDESIGN — pure trip-scheduling logic, no Supabase
/// dependency, so it's directly unit-testable in isolation — mirrors
/// [eventMatchesTrip]'s own reasoning for staying pure.
///
/// True when [trip] hasn't fully ended yet, compared by CALENDAR DATE
/// (never an exact instant) via [compareCalendarDates] — the same
/// zone-tag-agnostic comparator [eventMatchesTrip] already uses for
/// exactly this reason: [PlannedTrip.startDate]/[endDate] are parsed via
/// a bare `DateTime.parse` of a date-only string, which Dart resolves to
/// the DEVICE's local zone, so an ordinary `DateTime.isBefore` would leak
/// the device's own UTC offset into what must be a pure calendar-date
/// comparison. A trip currently underway (today falls within its own
/// start/end) still counts as upcoming — there is no separate "trip in
/// progress" state on this screen.
bool isUpcomingTrip(PlannedTrip trip, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return compareCalendarDates(trip.endDate, today) >= 0;
}

/// Every trip in [trips] that hasn't ended yet, soonest-first. Defensive
/// about input order — [PlannedTripsRepository.loadTrips] already orders
/// by `start_date` ascending, but this doesn't assume it, so it stays
/// correct even if that changes or a caller supplies trips from elsewhere.
List<PlannedTrip> upcomingTrips(List<PlannedTrip> trips, {DateTime? now}) {
  final upcoming = trips.where((t) => isUpcomingTrip(t, now: now)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  return upcoming;
}

/// A short, restrained "starts in..." label for the featured trip card —
/// null when not appropriate: a trip that has already started (today is on
/// or after its start date) has nothing meaningful to say about "starting"
/// — printing a negative day count would read as broken, not premium, so
/// this returns null rather than inventing an "Ongoing" label nobody asked
/// for.
String? tripStartLabel(DateTime startDate, {DateTime? now}) {
  final daysUntil = _daysBetween(now ?? DateTime.now(), startDate);
  if (daysUntil < 0) return null;
  if (daysUntil == 0) return 'Starts today';
  if (daysUntil == 1) return 'Starts tomorrow';
  return 'In $daysUntil days';
}

// Calendar-day difference, ignoring time-of-day on either side — matches
// PlannedTrip's own date-only, no-timezone semantics elsewhere (e.g.
// formatTripDateRange reads trip.startDate's day/month/year directly).
int _daysBetween(DateTime from, DateTime to) {
  final fromDate = DateTime(from.year, from.month, from.day);
  final toDate = DateTime(to.year, to.month, to.day);
  return toDate.difference(fromDate).inDays;
}
