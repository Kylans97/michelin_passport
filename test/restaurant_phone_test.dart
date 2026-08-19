// Covers Restaurant.phone — Restaurant Enrichment Step 1D. Mirrors
// restaurant_hall_of_fame_test.dart's own convention for a field sourced
// directly from restaurants_full: a raw JSON row map in, an assertion on
// the parsed field out — no Supabase involved.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/restaurant.dart';

Map<String, dynamic> _row({String? phone, bool includePhoneKey = true}) => {
  'id': 'r1',
  'restaurant_code': 'rest_0079',
  'name': 'Parkheuvel',
  'michelin_stars': 2,
  'inclusion_reason': 'michelin_star',
  'city_name': 'Rotterdam',
  'country_code': 'NL',
  'country_name': 'Netherlands',
  'flag_emoji': '🇳🇱',
  'address': 'Heuvellaan 21, 3016 GL Rotterdam',
  if (includePhoneKey) 'phone': phone,
};

void main() {
  group('Restaurant.phone', () {
    test('parses a populated phone value', () {
      final restaurant = Restaurant.fromJson(
        _row(phone: '+31 (0)10 436 07 66'),
      );
      expect(restaurant.phone, '+31 (0)10 436 07 66');
    });

    test('a null phone value parses to null, never an empty string', () {
      final restaurant = Restaurant.fromJson(_row(phone: null));
      expect(restaurant.phone, isNull);
    });

    test('backwards compatible: a row with no "phone" key at all (read '
        'before the migration ships) parses to null rather than throwing', () {
      final restaurant = Restaurant.fromJson(_row(includePhoneKey: false));
      expect(restaurant.phone, isNull);
    });

    test('every other field still parses normally alongside phone', () {
      final restaurant = Restaurant.fromJson(
        _row(phone: '+31 (0)10 436 07 66'),
      );
      expect(restaurant.name, 'Parkheuvel');
      expect(restaurant.michelinStars, 2);
      expect(restaurant.address, 'Heuvellaan 21, 3016 GL Rotterdam');
    });
  });
}
