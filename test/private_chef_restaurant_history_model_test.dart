// Covers PrivateChefRestaurantHistory.fromRow — the canonical-vs-text-
// fallback distinction that mirrors the database's own
// private_chef_restaurant_history_identity_xor CHECK constraint, and the
// derived isCanonical/displayName getters the UI reads to decide
// tappability and star rendering.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/private_chef_restaurant_history.dart';
import 'package:michelin_passport/models/restaurant.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Parkheuvel',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Rotterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: 'Some address',
);

Map<String, dynamic> _row({
  String id = 'h1',
  String privateChefId = 'chef-1',
  Object? restaurantId,
  Object? restaurantNameText,
  Object? role,
  Object? periodText,
  int displayOrder = 0,
}) => {
  'id': id,
  'private_chef_id': privateChefId,
  'restaurant_id': restaurantId,
  'restaurant_name_text': restaurantNameText,
  'role': role,
  'period_text': periodText,
  'display_order': displayOrder,
};

void main() {
  group('PrivateChefRestaurantHistory.fromRow', () {
    test('canonical row: restaurant supplied, restaurantNameText stays '
        'null even if the raw row happened to carry one', () {
      final history = PrivateChefRestaurantHistory.fromRow(
        _row(restaurantId: 'r1', restaurantNameText: 'Should be ignored'),
        restaurant: _restaurant,
      );
      expect(history.isCanonical, isTrue);
      expect(history.restaurant, _restaurant);
      expect(history.restaurantNameText, isNull);
      expect(history.displayName, 'Parkheuvel');
    });

    test('text-only row: no restaurant resolved, restaurant_name_text '
        'passes through', () {
      final history = PrivateChefRestaurantHistory.fromRow(
        _row(restaurantNameText: 'A small regional restaurant'),
      );
      expect(history.isCanonical, isFalse);
      expect(history.restaurant, isNull);
      expect(history.restaurantNameText, 'A small regional restaurant');
      expect(history.displayName, 'A small regional restaurant');
    });

    test('role/period/display_order map through', () {
      final history = PrivateChefRestaurantHistory.fromRow(
        _row(role: 'Sous Chef', periodText: '2019–2022', displayOrder: 2),
      );
      expect(history.role, 'Sous Chef');
      expect(history.periodText, '2019–2022');
      expect(history.displayOrder, 2);
    });

    test('missing role/period stay null, not empty strings', () {
      final history = PrivateChefRestaurantHistory.fromRow(_row());
      expect(history.role, isNull);
      expect(history.periodText, isNull);
    });
  });
}
