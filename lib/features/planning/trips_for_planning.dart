import '../../models/planned_trip.dart';

/// A trip offered in "Plan visit", and whether it has already ended.
typedef PlanTripChoice = ({PlannedTrip trip, bool ended});

/// The trips "Plan visit" offers for a venue in [countryCode] (decided
/// 2026-10-31 from tester feedback: a Dutch restaurant could be added to
/// a trip abroad, and every trip that had ended was listed too).
///
/// - Only trips with a destination in [countryCode] — the trip's own
///   country or any of its legs. An empty [countryCode] filters nothing.
/// - Trips still to come or under way (ending today or later), soonest
///   first.
/// - Plus the single most recently ended trip in that country, last and
///   marked ended, for adding to a trip just after it.
/// - The trip [keepTripId] names (the plan being edited is already in
///   it) is always kept, wherever it would otherwise be filtered out.
List<PlanTripChoice> tripsForPlanning(
  List<PlannedTrip> trips, {
  required String countryCode,
  required DateTime today,
  String? keepTripId,
}) {
  final day = DateTime(today.year, today.month, today.day);
  bool ended(PlannedTrip t) {
    final end = DateTime(t.endDate.year, t.endDate.month, t.endDate.day);
    return end.isBefore(day);
  }

  bool inCountry(PlannedTrip t) {
    if (countryCode.isEmpty) return true;
    final code = countryCode.toUpperCase();
    return t.countryCode.toUpperCase() == code ||
        t.destinations.any((d) => d.countryCode.toUpperCase() == code);
  }

  final local = trips.where(inCountry).toList();
  final current = local.where((t) => !ended(t)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final past = local.where(ended).toList()
    ..sort((a, b) => b.endDate.compareTo(a.endDate));

  final chosen = <PlanTripChoice>[
    for (final t in current) (trip: t, ended: false),
    if (past.isNotEmpty) (trip: past.first, ended: true),
  ];
  if (keepTripId != null && !chosen.any((c) => c.trip.id == keepTripId)) {
    for (final t in trips) {
      if (t.id == keepTripId) chosen.add((trip: t, ended: ended(t)));
    }
  }
  return chosen;
}
