import 'hotel.dart';
import 'restaurant.dart';

/// A single venue a user can build personal history against — a restaurant
/// or a hotel — kept as genuinely separate domain objects (never forcing
/// one shape onto both, never `dynamic`, never a fake Restaurant standing
/// in for a Hotel). Feeds [VenueEntry] for My Passport today, and is
/// intended to be reused by My Rankings once hotel rankings are built.
sealed class PassportVenue {
  const PassportVenue();

  /// Display name — what "All" mode sorts ties by.
  String get name;

  /// ISO 3166-1 alpha-2 country code — what Passport's countries count and
  /// country filters key on.
  String get countryCode;
}

class RestaurantVenue extends PassportVenue {
  final Restaurant restaurant;
  const RestaurantVenue(this.restaurant);

  @override
  String get name => restaurant.name;

  @override
  String get countryCode => restaurant.countryCode;
}

class HotelVenue extends PassportVenue {
  final Hotel hotel;
  const HotelVenue(this.hotel);

  @override
  String get name => hotel.name;

  @override
  String get countryCode => hotel.countryCode;
}
