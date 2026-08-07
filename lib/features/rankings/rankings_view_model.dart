import '../../models/passport_venue.dart';
import '../../models/ranking_dimension.dart';
import '../../models/ranking_entry.dart';
import '../../models/ranking_venue_type.dart';
import '../../models/venue_entry.dart';

/// True when [venue] belongs to the ranking context [type] — restaurants
/// and hotels are always kept as fully separate rankings, never mixed into
/// one list.
bool venueMatchesRankingType(PassportVenue venue, RankingVenueType type) =>
    switch (type) {
      RankingVenueType.restaurant => venue is RestaurantVenue,
      RankingVenueType.hotel => venue is HotelVenue,
    };

/// Builds "My Rankings" for one venue type + dimension + year selection
/// from [allEntries] (every venue the user has visited/stayed at, each with
/// all of its visits/stays — see VisitedRepository.loadPassportVenues).
/// VISITS/STAYS remain individual historical records; this aggregates them
/// per unique venue, so a venue with several relevant visits/stays
/// contributes exactly one entry, averaging only the ones that rated
/// [dimension].
///
/// A venue is excluded entirely when it doesn't belong to [venueType], or
/// when none of its visits/stays in the selected period rated [dimension]
/// — never averaged in as a 0.
List<PersonalRankingEntry> buildPersonalRankings(
  List<VenueEntry> allEntries, {
  required RankingVenueType venueType,
  required RankingDimension dimension,
  int? year,
}) {
  final entries = <PersonalRankingEntry>[];

  for (final entry in allEntries) {
    if (!venueMatchesRankingType(entry.venue, venueType)) continue;

    final ratedVisits = [
      for (final visit in entry.visitsInYear(year))
        if (dimension.valueFor(visit) != null) visit,
    ];
    if (ratedVisits.isEmpty) continue;

    final values = [
      for (final visit in ratedVisits) dimension.valueFor(visit)!,
    ];
    final average = values.reduce((a, b) => a + b) / values.length;
    final mostRecent = ratedVisits
        .map((v) => v.visitedOn)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    entries.add(
      PersonalRankingEntry(
        venue: entry.venue,
        averageScore: average,
        ratedVisitCount: ratedVisits.length,
        mostRecentRelevantVisit: mostRecent,
      ),
    );
  }

  // Deterministic tie-break: higher average, then more rated visits/stays,
  // then most recent relevant visit/stay, then venue name.
  entries.sort((a, b) {
    final byScore = b.averageScore.compareTo(a.averageScore);
    if (byScore != 0) return byScore;
    final byCount = b.ratedVisitCount.compareTo(a.ratedVisitCount);
    if (byCount != 0) return byCount;
    final byRecency = b.mostRecentRelevantVisit.compareTo(
      a.mostRecentRelevantVisit,
    );
    if (byRecency != 0) return byRecency;
    return a.venue.name.compareTo(b.venue.name);
  });

  return entries;
}
