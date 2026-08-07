import 'ranking_dimension.dart';

/// My Rankings' venue-type selector: Restaurants or Hotels — deliberately
/// no "All". A restaurant ranking and a hotel ranking are separate contexts
/// with different valid dimensions, unlike Explore/Passport's combined
/// browsing view.
enum RankingVenueType {
  restaurant,
  hotel;

  String get label => switch (this) {
    RankingVenueType.restaurant => 'Restaurants',
    RankingVenueType.hotel => 'Hotels',
  };

  /// The ranking dimensions valid for this venue type, in display order.
  List<RankingDimension> get validDimensions => switch (this) {
    RankingVenueType.restaurant =>
      RankingDimension.values.where((d) => d.validForRestaurant).toList(),
    RankingVenueType.hotel =>
      RankingDimension.values.where((d) => d.validForHotel).toList(),
  };
}
