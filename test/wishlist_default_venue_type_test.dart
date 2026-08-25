// Covers WishlistScreen's IA simplification (removing the "All" category)
// and EVENT WISHLIST V1's addition of a third tab: defaultWishlistVenueType
// picks a sensible initial filter from the user's existing wishlist state,
// without ever selecting "All" (which doesn't exist as an option on this
// screen), preferring Restaurants > Hotels > Events, each tier only kicking
// in when everything before it is empty.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/wishlist/wishlist_view_model.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant() => const Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Test Restaurant',
  michelinStars: null,
  inclusionReason: 'michelin_star',
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
);

Hotel _hotel() => const Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Test Hotel',
  michelinKeys: null,
  cityName: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Event _event() => Event(
  id: 'e1',
  name: 'Test Event',
  startDate: DateTime.utc(2026, 9, 1),
  endDate: DateTime.utc(2026, 9, 1),
  countryCode: 'FR',
  eventType: EventType.dinner,
  status: EventStatus.upcoming,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('defaultWishlistVenueType', () {
    test('empty wishlist defaults to Restaurants', () {
      expect(defaultWishlistVenueType([], []), WishlistVenueType.restaurants);
    });

    test('restaurants-only wishlist stays on Restaurants', () {
      expect(
        defaultWishlistVenueType([RestaurantVenue(_restaurant())], []),
        WishlistVenueType.restaurants,
      );
    });

    test('hotels-only wishlist switches to Hotels — Restaurants would be '
        'empty-by-construction otherwise', () {
      expect(
        defaultWishlistVenueType([HotelVenue(_hotel())], []),
        WishlistVenueType.hotels,
      );
    });

    test('events-only wishlist switches to Events — Restaurants and Hotels '
        'would both be empty-by-construction otherwise', () {
      expect(
        defaultWishlistVenueType([], [_event()]),
        WishlistVenueType.events,
      );
    });

    test('mixed wishlist prefers Restaurants', () {
      expect(
        defaultWishlistVenueType([
          HotelVenue(_hotel()),
          RestaurantVenue(_restaurant()),
        ], [_event()]),
        WishlistVenueType.restaurants,
      );
    });

    test('hotels + events (no restaurants) prefers Hotels', () {
      expect(
        defaultWishlistVenueType([HotelVenue(_hotel())], [_event()]),
        WishlistVenueType.hotels,
      );
    });

    test('never returns anything but Restaurants/Hotels/Events — Wishlist '
        'has no All category', () {
      for (final items in [
        (<PassportVenue>[], <Event>[]),
        ([RestaurantVenue(_restaurant())], <Event>[]),
        (<PassportVenue>[], [_event()]),
      ]) {
        expect(
          WishlistVenueType.values,
          contains(defaultWishlistVenueType(items.$1, items.$2)),
        );
      }
    });
  });
}
