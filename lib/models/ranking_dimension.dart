import 'visit.dart';

/// The personal rating dimensions "My Rankings" can sort by. Each maps to
/// exactly one column on `public.visits` — never Michelin stars, which are
/// venue identity/context and play no part in computing a ranking.
///
/// UI Consistency pass: [room]/[experience] added so hotel rankings expose
/// every dimension Hotel Detail/Add Stay/Stay Detail already collect
/// (`room_rating`/`experience_rating`, added by migration `20260816120000`,
/// confirmed deployed to production) — Rankings previously only recognised
/// Overall/Service/Value for hotels, silently excluding two dimensions a
/// user could already rate. Food/Wine remain restaurant-only.
enum RankingDimension {
  overall,
  food,
  service,
  wine,
  value,
  room,
  experience;

  String get label => switch (this) {
    RankingDimension.overall => 'Overall',
    RankingDimension.food => 'Food',
    RankingDimension.service => 'Service',
    RankingDimension.wine => 'Wine',
    RankingDimension.value => 'Value',
    RankingDimension.room => 'Room',
    RankingDimension.experience => 'Experience',
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
    RankingDimension.room => visit.roomRating,
    RankingDimension.experience => visit.experienceRating,
  };

  /// True for every dimension a restaurant visit can rate — Overall, Food,
  /// Service, Wine, Value. Room/Experience are hotel-only concepts a
  /// restaurant visit never records.
  bool get validForRestaurant => switch (this) {
    RankingDimension.overall => true,
    RankingDimension.food => true,
    RankingDimension.service => true,
    RankingDimension.wine => true,
    RankingDimension.value => true,
    RankingDimension.room => false,
    RankingDimension.experience => false,
  };

  /// True for every dimension a hotel stay can rate — Overall, Service,
  /// Value, Room, Experience. Food and Wine are restaurant concepts a hotel
  /// stay never records — see VisitedRepository.markHotelStay, which never
  /// populates food_rating/wine_rating for entity_type = 'hotel'.
  bool get validForHotel => switch (this) {
    RankingDimension.overall => true,
    RankingDimension.service => true,
    RankingDimension.value => true,
    RankingDimension.room => true,
    RankingDimension.experience => true,
    RankingDimension.food => false,
    RankingDimension.wine => false,
  };
}
