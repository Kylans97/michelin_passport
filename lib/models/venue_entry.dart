import 'passport_venue.dart';
import 'visit.dart';

/// One unique venue (restaurant or hotel), together with every visit/stay
/// logged against it. A venue visited/stayed at three times is still one
/// VenueEntry with three visits — the individual visits/stays stay
/// browsable, unmerged, via Restaurant/Hotel Detail's own visit/stay
/// history. This is what My Passport is built from; My Rankings can later
/// build on the same shape once hotel rankings exist.
class VenueEntry {
  final PassportVenue venue;

  // Every visit/stay against this venue, newest first. Never empty: an
  // entry only exists because at least one visit/stay produced it.
  final List<Visit> visits;

  const VenueEntry({required this.venue, required this.visits});

  /// Visits/stays within [year], or all of them when [year] is null ("All
  /// time").
  List<Visit> visitsInYear(int? year) => year == null
      ? visits
      : visits.where((v) => v.visitedOn.year == year).toList();
}
