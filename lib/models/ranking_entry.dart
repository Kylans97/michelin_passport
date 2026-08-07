import 'passport_venue.dart';

/// One unique venue's (restaurant or hotel) aggregated score for a single
/// ranking dimension over a selected period (all time or one year).
/// VISITS/STAYS remain individual historical records; this is the
/// per-venue aggregate built from them for "My Rankings" — a venue never
/// appears twice in the same ranking. Built by buildPersonalRankings in
/// rankings_view_model.dart.
class PersonalRankingEntry {
  final PassportVenue venue;

  // Arithmetic mean of the non-null dimension values among the
  // visits/stays in the selected period. Never includes a null as 0.
  final double averageScore;

  // How many visits/stays contributed a non-null value to [averageScore].
  final int ratedVisitCount;

  // Most recent of the visits/stays that contributed to [averageScore].
  // Used only as a sort tie-break — not shown as "the" date on the card.
  final DateTime mostRecentRelevantVisit;

  const PersonalRankingEntry({
    required this.venue,
    required this.averageScore,
    required this.ratedVisitCount,
    required this.mostRecentRelevantVisit,
  });
}

class CommunityRankingEntry {
  final String restaurantId;
  final String name;
  final String city;
  final String countryFlag;
  final int michelinStars;
  final double communityRating;
  final int totalVisits;

  const CommunityRankingEntry({
    required this.restaurantId,
    required this.name,
    required this.city,
    required this.countryFlag,
    required this.michelinStars,
    required this.communityRating,
    required this.totalVisits,
  });

  factory CommunityRankingEntry.fromJson(Map<String, dynamic> json) =>
      CommunityRankingEntry(
        restaurantId: json['restaurant_id'].toString(),
        name: (json['name'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        countryFlag: (json['country_flag'] as String?) ?? '',
        michelinStars: (json['michelin_stars'] as int?) ?? 0,
        communityRating: ((json['community_rating'] as num?) ?? 0).toDouble(),
        totalVisits: (json['total_visits'] as int?) ?? 0,
      );
}
