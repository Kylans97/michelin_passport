import '../../../models/hotel.dart';
import '../../../models/restaurant.dart';

/// A single Explore result in "All" mode — either a restaurant or a hotel,
/// kept as genuinely separate domain objects (never forced into one shape,
/// never `dynamic`). Restaurants-only and Hotels-only modes work directly
/// with their own typed lists; this wrapper exists only so "All" mode can
/// hold one combined, sorted list.
sealed class ExploreItem {
  const ExploreItem();

  /// Display name — the only thing "All" mode sorts by, so restaurants and
  /// hotels interleave purely alphabetically; neither is ranked above the
  /// other.
  String get name;
}

class RestaurantExploreItem extends ExploreItem {
  final Restaurant restaurant;
  const RestaurantExploreItem(this.restaurant);

  @override
  String get name => restaurant.name;
}

class HotelExploreItem extends ExploreItem {
  final Hotel hotel;
  const HotelExploreItem(this.hotel);

  @override
  String get name => hotel.name;
}
