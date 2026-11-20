// "Wishlist, calmer" (product owner, 2026-11-20): one selector instead of
// a chip row, with "Everything, by place" first. Covers the selector's
// rows and counts and the by-place grouping, all pure.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/wishlist/wishlist_view_model.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/journey.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/vineyard.dart';

Restaurant _restaurant(
  String id, {
  String city = 'Bordeaux',
  String? region = 'Bordeaux',
  String country = 'FR',
  String countryName = 'France',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: 'Restaurant $id',
  michelinStars: null,
  inclusionReason: 'michelin_star',
  cityName: city,
  region: region,
  countryCode: country,
  countryName: countryName,
  flagEmoji: '',
  address: '',
);

Hotel _hotel(String id, {String? region = 'Bordeaux'}) => Hotel(
  id: id,
  hotelCode: id,
  name: 'Hotel $id',
  michelinKeys: null,
  cityName: 'Martillac',
  region: region,
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '',
  address: '',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Vineyard _vineyard(String id, {String region = 'Bordeaux'}) => Vineyard(
  id: id,
  vineyardCode: 'vine_$id',
  name: 'Estate $id',
  countryCode: 'FR',
  countryName: 'France',
  region: region,
  city: 'Martillac',
);

Event _event(String id, {String city = 'Antwerp'}) => Event(
  id: id,
  name: 'Event $id',
  startDate: DateTime.utc(2027, 2, 5),
  endDate: DateTime.utc(2027, 2, 5),
  countryCode: 'BE',
  city: city,
  eventType: EventType.dinner,
  createdAt: DateTime.utc(2026, 1, 1),
);

Journey _journey(String id, JourneyKind kind) => Journey(
  id: id,
  journeyCode: id,
  slug: id,
  kind: kind,
  name: 'Journey $id',
  operatorCode: 'op',
  operatorName: 'Operator',
);

void main() {
  group('WishlistContents', () {
    final contents = WishlistContents(
      venues: [
        RestaurantVenue(_restaurant('r1')),
        RestaurantVenue(_restaurant('r2')),
        HotelVenue(_hotel('h1')),
      ],
      events: [_event('e1')],
      vineyards: [_vineyard('v1')],
      journeys: [
        _journey('t1', JourneyKind.train),
        _journey('t2', JourneyKind.train),
        _journey('s1', JourneyKind.ship),
      ],
    );

    test('counts each kind, trains and ships apart', () {
      expect(contents.countOf(WishlistView.everything), 8);
      expect(contents.countOf(WishlistView.restaurants), 2);
      expect(contents.countOf(WishlistView.hotels), 1);
      expect(contents.countOf(WishlistView.events), 1);
      expect(contents.countOf(WishlistView.estates), 1);
      expect(contents.countOf(WishlistView.trains), 2);
      expect(contents.countOf(WishlistView.ships), 1);
    });

    test('the selector lists Everything first and leaves out kinds with '
        'nothing saved', () {
      final onlyRestaurants = WishlistContents(
        venues: [RestaurantVenue(_restaurant('r1'))],
      );
      expect(onlyRestaurants.selectorViews(WishlistView.everything), [
        WishlistView.everything,
        WishlistView.restaurants,
      ]);
    });

    test('the current view stays in the selector even when it is empty', () {
      const empty = WishlistContents();
      expect(empty.selectorViews(WishlistView.ships), [
        WishlistView.everything,
        WishlistView.ships,
      ]);
    });

    test('Everything reads as "Everything, by place" in the sheet', () {
      expect(WishlistView.everything.sheetLabel, 'Everything, by place');
      expect(WishlistView.estates.sheetLabel, 'Wine estates');
    });
  });

  group('groupWishlistByPlace', () {
    test('a restaurant, a hotel and an estate in one region share a '
        'group; the biggest place comes first', () {
      final groups = groupWishlistByPlace(
        WishlistContents(
          venues: [
            RestaurantVenue(_restaurant('r1')),
            HotelVenue(_hotel('h1')),
            RestaurantVenue(
              _restaurant(
                'r2',
                city: 'Zwolle',
                region: 'Overijssel',
                country: 'NL',
                countryName: 'Netherlands',
              ),
            ),
          ],
          vineyards: [_vineyard('v1')],
        ),
      );
      expect(groups.map((g) => g.title), ['Bordeaux', 'Overijssel']);
      expect(groups.first.items, hasLength(3));
      expect(groups.first.country, 'France');
      expect(
        wishlistGroupSummary(groups.first),
        '1 restaurant, 1 hotel, 1 wine estate',
      );
    });

    test('without a region, the town names the place', () {
      final groups = groupWishlistByPlace(
        WishlistContents(
          venues: [
            RestaurantVenue(_restaurant('r1', city: 'Antwerp', region: null)),
          ],
        ),
      );
      expect(groups.single.title, 'Antwerp');
    });

    test('a region of the same name in two countries stays two places', () {
      final groups = groupWishlistByPlace(
        WishlistContents(
          venues: [
            RestaurantVenue(
              _restaurant('r1', region: 'Limburg', country: 'NL'),
            ),
            RestaurantVenue(
              _restaurant('r2', region: 'Limburg', country: 'BE'),
            ),
          ],
        ),
      );
      expect(groups, hasLength(2));
    });

    test('trains and ships close the list together as "On the move"', () {
      final groups = groupWishlistByPlace(
        WishlistContents(
          events: [_event('e1')],
          journeys: [
            _journey('t1', JourneyKind.train),
            _journey('s1', JourneyKind.ship),
          ],
        ),
      );
      expect(groups.last.title, 'On the move');
      expect(groups.last.isOnTheMove, isTrue);
      expect(wishlistGroupSummary(groups.last), '1 train, 1 ship');
      expect(groups.first.title, 'Antwerp');
    });

    test('an empty wishlist has no groups', () {
      expect(groupWishlistByPlace(const WishlistContents()), isEmpty);
    });
  });
}
