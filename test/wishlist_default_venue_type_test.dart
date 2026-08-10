// Covers WishlistScreen's IA simplification (removing the "All" category):
//   defaultWishlistVenueType picks a sensible initial filter from the
//   user's existing wishlist state, without ever selecting "All" (which no
//   longer exists as an option on this screen).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/models/explore_filters.dart';
import 'package:michelin_passport/features/wishlist/wishlist_view_model.dart';
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

void main() {
  group('defaultWishlistVenueType', () {
    test('empty wishlist defaults to Restaurants', () {
      expect(defaultWishlistVenueType([]), ExploreVenueType.restaurants);
    });

    test('restaurants-only wishlist stays on Restaurants', () {
      expect(
        defaultWishlistVenueType([RestaurantVenue(_restaurant())]),
        ExploreVenueType.restaurants,
      );
    });

    test('hotels-only wishlist switches to Hotels — Restaurants would be '
        'empty-by-construction otherwise', () {
      expect(
        defaultWishlistVenueType([HotelVenue(_hotel())]),
        ExploreVenueType.hotels,
      );
    });

    test('mixed wishlist prefers Restaurants', () {
      expect(
        defaultWishlistVenueType([
          HotelVenue(_hotel()),
          RestaurantVenue(_restaurant()),
        ]),
        ExploreVenueType.restaurants,
      );
    });

    test('never returns All — Wishlist has no All category', () {
      for (final items in [
        <PassportVenue>[],
        [RestaurantVenue(_restaurant())],
        [HotelVenue(_hotel())],
      ]) {
        expect(defaultWishlistVenueType(items), isNot(ExploreVenueType.all));
      }
    });
  });
}
