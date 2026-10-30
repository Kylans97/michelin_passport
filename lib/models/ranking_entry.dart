import 'photo_framing.dart';
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

/// Which list Community Rankings shows.
enum CommunityRankingKind {
  restaurants('Restaurants'),
  hotels('Hotels'),
  events('Events');

  final String label;
  const CommunityRankingKind(this.label);
}

/// The one recognition filter on Community Rankings. For restaurants the
/// counts are MICHELIN stars, for hotels MICHELIN Keys; events have none.
/// [worlds50Best] keeps venues ranked on The World's 50 Best, starred/keyed
/// or not.
enum CommunityRecognitionFilter { all, one, two, three, worlds50Best }

/// One row of Community Rankings, whichever kind — a venue or event, its
/// community average and how many members it rests on. Never a member's
/// own score or identity: the views behind it return only aggregates.
class CommunityRankedVenue {
  final CommunityRankingKind kind;
  final String id;
  final String name;
  final String city;
  final String countryFlag;

  /// Restaurants: MICHELIN stars (0 for none). Null otherwise.
  final int? stars;

  /// Hotels: MICHELIN Keys, null when none is confirmed.
  final int? keys;
  final int? worlds50BestRank;
  final double communityRating;

  /// Members behind [communityRating] (latest visit/stay, or attendance).
  final int memberCount;
  final String? imageUrl;
  final PhotoFraming imageFraming;

  /// Events only: their calendar dates.
  final DateTime? startDate;
  final DateTime? endDate;

  const CommunityRankedVenue({
    required this.kind,
    required this.id,
    required this.name,
    required this.city,
    this.countryFlag = '',
    this.stars,
    this.keys,
    this.worlds50BestRank,
    required this.communityRating,
    required this.memberCount,
    this.imageUrl,
    this.imageFraming = PhotoFraming.center,
    this.startDate,
    this.endDate,
  });

  factory CommunityRankedVenue.restaurantFromJson(Map<String, dynamic> json) =>
      CommunityRankedVenue(
        kind: CommunityRankingKind.restaurants,
        id: json['restaurant_id'].toString(),
        name: (json['name'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        countryFlag: (json['country_flag'] as String?) ?? '',
        stars: (json['michelin_stars'] as int?) ?? 0,
        worlds50BestRank: json['worlds_50_best_rank'] as int?,
        communityRating: ((json['community_rating'] as num?) ?? 0).toDouble(),
        memberCount: (json['total_visits'] as int?) ?? 0,
        imageUrl: json['card_photo_url'] as String?,
        imageFraming: PhotoFraming.fromJson(json, prefix: 'card_'),
      );

  factory CommunityRankedVenue.hotelFromJson(Map<String, dynamic> json) =>
      CommunityRankedVenue(
        kind: CommunityRankingKind.hotels,
        id: json['hotel_id'].toString(),
        name: (json['name'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        countryFlag: (json['country_flag'] as String?) ?? '',
        keys: json['michelin_keys'] as int?,
        worlds50BestRank: json['worlds_50_best_rank'] as int?,
        communityRating: ((json['community_rating'] as num?) ?? 0).toDouble(),
        memberCount: (json['total_stays'] as int?) ?? 0,
        imageUrl: json['card_photo_url'] as String?,
        imageFraming: PhotoFraming.fromJson(json, prefix: 'card_'),
      );

  factory CommunityRankedVenue.eventFromJson(Map<String, dynamic> json) =>
      CommunityRankedVenue(
        kind: CommunityRankingKind.events,
        id: json['event_id'].toString(),
        name: (json['name'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        communityRating: ((json['community_rating'] as num?) ?? 0).toDouble(),
        memberCount: (json['total_attendees'] as int?) ?? 0,
        imageUrl: json['image_url'] as String?,
        startDate: DateTime.tryParse((json['start_date'] as String?) ?? ''),
        endDate: DateTime.tryParse((json['end_date'] as String?) ?? ''),
      );
}
