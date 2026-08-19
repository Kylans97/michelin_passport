// Covers chefDescriptors — the Step 2C editorial descriptor derivation:
// always PRIVATE DINING, WINE PAIRING/TRAVELS strictly conditional on the
// chef's own true/false capability fields, never invented, never more
// than 3.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/private_chefs/private_chef_descriptors.dart';
import 'package:michelin_passport/models/private_chef.dart';

const _base = PrivateChef(id: 'c1', slug: 'chef', displayName: 'Chef');

void main() {
  group('chefDescriptors', () {
    test('always includes PRIVATE DINING', () {
      expect(chefDescriptors(_base), contains('PRIVATE DINING'));
    });

    test('wine_pairing_available true -> WINE PAIRING included', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        winePairingAvailable: true,
      );
      expect(chefDescriptors(chef), contains('WINE PAIRING'));
    });

    test('wine_pairing_available false -> WINE PAIRING never shown', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        winePairingAvailable: false,
      );
      expect(chefDescriptors(chef), isNot(contains('WINE PAIRING')));
    });

    test('travel_available true -> TRAVELS included', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        travelAvailable: true,
      );
      expect(chefDescriptors(chef), contains('TRAVELS'));
    });

    test('travel_available false -> TRAVELS never shown', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        travelAvailable: false,
      );
      expect(chefDescriptors(chef), isNot(contains('TRAVELS')));
    });

    test('Lucas-shaped data yields exactly the 3 expected descriptors', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'lucas-de-jager',
        displayName: 'Lucas de Jager',
        winePairingAvailable: true,
        travelAvailable: true,
      );
      expect(chefDescriptors(chef), [
        'PRIVATE DINING',
        'WINE PAIRING',
        'TRAVELS',
      ]);
    });

    test('never exceeds 3 descriptors', () {
      final chef = PrivateChef(
        id: 'c1',
        slug: 'chef',
        displayName: 'Chef',
        winePairingAvailable: true,
        travelAvailable: true,
      );
      expect(chefDescriptors(chef).length, lessThanOrEqualTo(3));
    });
  });
}
