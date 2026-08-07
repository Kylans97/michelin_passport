import '../../models/passport_venue.dart';
import '../../models/venue_entry.dart';
import '../../models/visit.dart';
import '../explore/models/explore_filters.dart' show ExploreVenueType;

/// One venue's stats for the currently selected venue-type filter and year
/// (or all time). [visitCount], [latestVisit] and [averageRating] only ever
/// reflect the visits/stays that fall inside the active filter — never the
/// venue's full history, which remains reachable in full via Restaurant/
/// Hotel Detail regardless of what Passport is currently filtered to.
class PassportVenueStats {
  final PassportVenue venue;
  final int visitCount;
  final DateTime latestVisit;

  // Arithmetic mean of the non-null overall ratings among the filtered
  // visits/stays. Null when none of them were rated — never coerced to 0.
  final double? averageRating;

  // stars_at_visit (restaurant) or keys_at_visit (hotel) from this venue's
  // most recent visit/stay within the filtered period — never the venue's
  // *current* michelinStars/michelinKeys. A venue is one entry, so its
  // award is counted once here regardless of how many times it was
  // visited/stayed at in the period.
  final int awardAtLatestVisit;

  const PassportVenueStats._({
    required this.venue,
    required this.visitCount,
    required this.latestVisit,
    required this.averageRating,
    required this.awardAtLatestVisit,
  });

  factory PassportVenueStats.from(
    PassportVenue venue,
    List<Visit> visitsInPeriod,
  ) {
    final ratings = [
      for (final visit in visitsInPeriod)
        if (visit.rating != null) visit.rating!,
    ];
    final mostRecentVisit = visitsInPeriod.reduce(
      (a, b) => a.visitedOn.isAfter(b.visitedOn) ? a : b,
    );
    final award = switch (venue) {
      RestaurantVenue() => mostRecentVisit.starsAtVisit ?? 0,
      HotelVenue() => mostRecentVisit.keysAtVisit ?? 0,
    };
    return PassportVenueStats._(
      venue: venue,
      visitCount: visitsInPeriod.length,
      latestVisit: mostRecentVisit.visitedOn,
      averageRating: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      awardAtLatestVisit: award,
    );
  }
}

/// Passport-wide totals for the active filter. Field names are
/// venue-type-neutral ("places"/"awards") — the screen picks the label text
/// ("PLACES"/"RESTAURANTS"/"HOTELS", "AWARDS"/"STARS"/"KEYS") to match
/// [ExploreVenueType].
class PassportSummary {
  final int placesVisited;

  // Sum of each unique venue's awardAtLatestVisit — not per-visit/stay. A
  // restaurant with 1 star visited 3 times contributes 1, not 3; a hotel
  // with 2 Keys stayed at twice contributes 2, not 4.
  final int awardsExperienced;
  final int countriesVisited;

  const PassportSummary({
    required this.placesVisited,
    required this.awardsExperienced,
    required this.countriesVisited,
  });
}

/// The Passport view for one filter selection: the venues (of [venueType])
/// that had at least one visit/stay in [year] (all of them when [year] is
/// null), each with its own stats scoped to that same period, plus the
/// passport-wide summary.
class PassportFilterResult {
  final List<PassportVenueStats> entries;
  final PassportSummary summary;

  const PassportFilterResult({required this.entries, required this.summary});

  factory PassportFilterResult.of(
    List<VenueEntry> allEntries, {
    required ExploreVenueType venueType,
    int? year,
  }) {
    final stats = <PassportVenueStats>[];
    for (final entry in allEntries) {
      if (!_matchesVenueType(entry.venue, venueType)) continue;
      final visitsInPeriod = entry.visitsInYear(year);
      if (visitsInPeriod.isEmpty) continue;
      stats.add(PassportVenueStats.from(entry.venue, visitsInPeriod));
    }
    // Most recently visited/stayed (within the active period) first,
    // regardless of venue type — restaurants and hotels interleave by
    // date, never grouped by type. Ties break alphabetically by name.
    stats.sort((a, b) {
      final byDate = b.latestVisit.compareTo(a.latestVisit);
      if (byDate != 0) return byDate;
      return a.venue.name.compareTo(b.venue.name);
    });

    final awards = stats.fold<int>(0, (sum, s) => sum + s.awardAtLatestVisit);
    final countries = stats.map((s) => s.venue.countryCode).toSet().length;

    return PassportFilterResult(
      entries: stats,
      summary: PassportSummary(
        placesVisited: stats.length,
        awardsExperienced: awards,
        countriesVisited: countries,
      ),
    );
  }

  static bool _matchesVenueType(PassportVenue venue, ExploreVenueType type) =>
      switch (type) {
        ExploreVenueType.all => true,
        ExploreVenueType.restaurants => venue is RestaurantVenue,
        ExploreVenueType.hotels => venue is HotelVenue,
      };
}
