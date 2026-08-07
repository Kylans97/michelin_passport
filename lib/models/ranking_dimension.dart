import 'visit.dart';

/// The five personal rating dimensions "My Rankings" can sort by. Each maps
/// to exactly one column on `public.visits` — never Michelin stars, which
/// are venue identity/context and play no part in computing a ranking.
enum RankingDimension {
  overall,
  food,
  service,
  wine,
  value;

  String get label => switch (this) {
    RankingDimension.overall => 'Overall',
    RankingDimension.food => 'Food',
    RankingDimension.service => 'Service',
    RankingDimension.wine => 'Wine',
    RankingDimension.value => 'Value',
  };

  /// This dimension's rating on [visit], or null when that visit didn't
  /// record it. Never coerced to 0 — a null here must be excluded from any
  /// average, not counted as a low score.
  int? valueFor(Visit visit) => switch (this) {
    RankingDimension.overall => visit.rating,
    RankingDimension.food => visit.foodRating,
    RankingDimension.service => visit.serviceRating,
    RankingDimension.wine => visit.wineRating,
    RankingDimension.value => visit.valueRating,
  };

  /// True for every dimension a restaurant visit can rate — all five.
  bool get validForRestaurant => true;

  /// True only for the three dimensions a hotel stay can rate. Food and
  /// Wine are restaurant concepts a hotel stay never records — see
  /// VisitedRepository.markHotelStay, which never populates
  /// food_rating/wine_rating for entity_type = 'hotel'.
  bool get validForHotel => switch (this) {
    RankingDimension.overall => true,
    RankingDimension.service => true,
    RankingDimension.value => true,
    RankingDimension.food => false,
    RankingDimension.wine => false,
  };
}
