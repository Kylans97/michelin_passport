import 'restaurant.dart';

class PersonalRankingEntry {
  final Restaurant restaurant;
  final double personalRating;
  final DateTime? visitedAt;

  const PersonalRankingEntry({
    required this.restaurant,
    required this.personalRating,
    this.visitedAt,
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
