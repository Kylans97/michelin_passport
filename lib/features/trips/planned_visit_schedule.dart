import '../../core/utils/event_time.dart' show compareCalendarDates;
import '../../models/planned_venue.dart';
import '../../models/resolved_planned_venue.dart';

/// PLANNED VISITS REFINEMENT — pure filtering/sorting for "PLANNED
/// VISITS" (the untripped section of the Trips subsection), mirroring
/// [trip_schedule.dart]'s own reasoning for staying pure and testable
/// rather than embedding this logic in the widget.
///
/// A restaurant visit has no end date (see [PlannedVenue]'s own doc
/// comment: "Restaurant: the single planned visit date, endDate stays
/// null") — its [PlannedVenue.startDate] is the only date there is to
/// judge. A hotel stay has an explicit checkout ([PlannedVenue.endDate])
/// when known; while still checked in (today falls anywhere from
/// check-in through checkout, inclusive), it must keep showing as
/// upcoming/ongoing — comparing against [PlannedVenue.startDate] alone
/// would incorrectly drop a stay the moment check-in day itself has
/// passed, even though the guest is still there. Falls back to
/// [PlannedVenue.startDate] when [PlannedVenue.endDate] is null (a
/// restaurant, or a hotel stay whose checkout the user hasn't set yet) —
/// never invents an end date. Compared by CALENDAR DATE via
/// [compareCalendarDates], the same zone-tag-agnostic comparator
/// [trip_schedule.dart] already uses for the identical reason: these
/// dates are parsed via a bare `DateTime.parse` of a date-only string,
/// which Dart resolves to the DEVICE's local zone, so an ordinary
/// `DateTime.isBefore` would leak the device's own UTC offset into what
/// must be a pure calendar-date comparison.
bool isUpcomingPlannedVenue(PlannedVenue plan, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final effectiveEndDate = plan.endDate ?? plan.startDate;
  return compareCalendarDates(effectiveEndDate, today) >= 0;
}

/// Every entry in [venues] that's still upcoming or ongoing, nearest
/// [PlannedVenue.startDate] first — never creation/insertion order. A
/// venue whose visit/stay has fully passed is filtered out of THIS list
/// only; nothing here deletes or mutates the underlying planned-venue
/// row, so historical data stays exactly where it already lives (Passport
/// visit/stay history reads from VisitedRepository, an entirely separate
/// table/repository untouched by this function).
List<ResolvedPlannedVenue> upcomingPlannedVenues(
  List<ResolvedPlannedVenue> venues, {
  DateTime? now,
}) {
  final upcoming = venues
      .where((v) => isUpcomingPlannedVenue(v.plan, now: now))
      .toList()
    ..sort((a, b) => a.plan.startDate.compareTo(b.plan.startDate));
  return upcoming;
}
