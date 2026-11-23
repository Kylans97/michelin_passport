// Visits without a date (20261101700000_add_undated_visits.sql) on My Map:
// the row model, the dashed pins built from it, and the order the
// "Where in {country} have you been?" list shows venues in. Plain Dart
// fixtures, no Supabase, as in map_pin_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/undated_visit_repository.dart';
import 'package:michelin_passport/features/map/models/map_filter_type.dart';
import 'package:michelin_passport/features/map/models/map_pin.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/undated_visit.dart';
import 'package:michelin_passport/models/visit.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Test Restaurant',
  michelinStars: 3,
  inclusionReason: 'michelin_star',
  cityName: 'Roeselare',
  countryCode: 'BE',
  countryName: 'Belgium',
  flagEmoji: '🇧🇪',
  address: '1 Test Street',
);

const _hotel = Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Test Hotel',
  michelinKeys: 1,
  cityName: 'Antwerp',
  countryCode: 'BE',
  countryName: 'Belgium',
  flagEmoji: '🇧🇪',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

UndatedVisit _row({
  String id = 'u1',
  String entityType = 'restaurant',
  String entityId = 'r1',
}) => UndatedVisit.fromJson({
  'id': id,
  'user_id': 'me',
  'entity_type': entityType,
  'entity_id': entityId,
  'visibility': 'friends',
  'stars_at_visit': entityType == 'restaurant' ? 3 : null,
  'keys_at_visit': entityType == 'hotel' ? 1 : null,
  'created_at': '2026-11-23T20:00:00Z',
});

final _undatedRestaurant = UndatedVenue(
  visit: _row(),
  venue: const RestaurantVenue(_restaurant),
);
final _undatedHotel = UndatedVenue(
  visit: _row(id: 'u2', entityType: 'hotel', entityId: 'h1'),
  venue: const HotelVenue(_hotel),
);

CountryVenueChoice _choice(
  String name, {
  String city = 'Antwerp',
  bool hotel = false,
  int? award,
}) => CountryVenueChoice(
  id: name,
  isHotel: hotel,
  name: name,
  city: city,
  stars: hotel ? null : award,
  keys: hotel ? award : null,
);

void main() {
  group('UndatedVisit.fromJson', () {
    test('reads the row, visibility and the award frozen when logged', () {
      final v = _row();
      expect(v.id, 'u1');
      expect(v.isHotel, isFalse);
      expect(v.visibility, VisitVisibility.friends);
      expect(v.starsAtVisit, 3);
      expect(v.keysAtVisit, isNull);
    });

    test('an unknown visibility fails safe to private', () {
      final v = UndatedVisit.fromJson({
        'id': 'u9',
        'user_id': 'me',
        'entity_type': 'hotel',
        'entity_id': 'h1',
        'visibility': null,
        'created_at': '2026-11-23T20:00:00Z',
      });
      expect(v.visibility, VisitVisibility.private);
      expect(v.isHotel, isTrue);
    });
  });

  group('undatedMapPins', () {
    test('one dashed pin per venue with a coordinate', () {
      final pins = undatedMapPins(
        undated: [_undatedRestaurant, _undatedHotel],
        restaurantCoords: {'r1': (50.9, 3.1)},
        hotelCoords: {'h1': (51.2, 4.4)},
      );
      expect(pins, hasLength(2));
      final first = pins.first as UndatedMapPin;
      expect(first.id, 'undated:u1');
      expect(first.type, MapPinType.restaurant);
      expect(first.countryCode, 'BE');
      expect(first.subtitle, 'Roeselare, Belgium');
      expect((pins.last as UndatedMapPin).type, MapPinType.hotel);
    });

    test('no coordinate, no pin: never a guessed position', () {
      final pins = undatedMapPins(
        undated: [_undatedRestaurant],
        restaurantCoords: const {},
        hotelCoords: const {},
      );
      expect(pins, isEmpty);
    });

    test('a venue that also has a dated visit gets no second pin', () {
      final pins = undatedMapPins(
        undated: [_undatedRestaurant, _undatedHotel],
        restaurantCoords: {'r1': (50.9, 3.1)},
        hotelCoords: {'h1': (51.2, 4.4)},
        datedVenueKeys: {'restaurant:r1'},
      );
      expect(pins.single.id, 'undated:u2');
    });

    test('the Restaurants and Hotels filters keep their own undated pins', () {
      final pins = undatedMapPins(
        undated: [_undatedRestaurant, _undatedHotel],
        restaurantCoords: {'r1': (50.9, 3.1)},
        hotelCoords: {'h1': (51.2, 4.4)},
      );
      expect(
        pins.where((p) => MapFilterType.hotels.matches(p.type)).single.id,
        'undated:u2',
      );
      expect(
        pins.where((p) => MapFilterType.events.matches(p.type)),
        isEmpty,
      );
    });
  });

  group('compareCountryChoices', () {
    test('three stars, then two, then the rest; then by city and name', () {
      final list = [
        _choice('Plain B', city: 'Ghent'),
        _choice('Two', award: 2),
        _choice('Plain A', city: 'Antwerp'),
        _choice('Three', award: 3),
        _choice('Keyed', hotel: true, award: 1),
      ]..sort(compareCountryChoices);
      expect(list.map((c) => c.name), [
        'Three',
        'Two',
        'Keyed',
        'Plain A',
        'Plain B',
      ]);
    });

    test('a listed venue without a star (0) sorts with the unawarded', () {
      final list = [
        _choice('Zero', city: 'Bruges', award: 0),
        _choice('One', award: 1),
      ]..sort(compareCountryChoices);
      expect(list.first.name, 'One');
    });
  });
}
