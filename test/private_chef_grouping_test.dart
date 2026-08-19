// Covers groupChefsByCountry — Step 2C §3/§16's country-grouping rule:
// naturally supports one country today and many later, sorted
// alphabetically by resolved name, never hardcoded to any one country or
// chef.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/private_chefs/private_chef_grouping.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _countryNames = {
  'NL': VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱'),
  'FR': VenueCountry(name: 'France', code: 'FR', flag: '🇫🇷'),
  'BE': VenueCountry(name: 'Belgium', code: 'BE', flag: '🇧🇪'),
};

PrivateChef _chef(String id, String name, String? countryCode) => PrivateChef(
  id: id,
  slug: id,
  displayName: name,
  homeCountryCode: countryCode,
);

void main() {
  group('groupChefsByCountry', () {
    test('a single country produces exactly one group', () {
      final chefs = [_chef('c1', 'Lucas', 'NL')];
      final groups = groupChefsByCountry(chefs, _countryNames);
      expect(groups, hasLength(1));
      expect(groups.single.countryName, 'Netherlands');
      expect(groups.single.chefs, chefs);
    });

    test('multiple countries sort alphabetically by resolved name', () {
      final chefs = [
        _chef('c1', 'Chef NL', 'NL'),
        _chef('c2', 'Chef FR', 'FR'),
        _chef('c3', 'Chef BE', 'BE'),
      ];
      final groups = groupChefsByCountry(chefs, _countryNames);
      expect(groups.map((g) => g.countryName), [
        'Belgium',
        'France',
        'Netherlands',
      ]);
    });

    test('chefs within a country preserve the input order', () {
      final chefs = [_chef('c1', 'B Chef', 'NL'), _chef('c2', 'A Chef', 'NL')];
      final groups = groupChefsByCountry(chefs, _countryNames);
      expect(groups.single.chefs.map((c) => c.displayName), [
        'B Chef',
        'A Chef',
      ]);
    });

    test('unresolved country code still groups, falling back to the code', () {
      final chefs = [_chef('c1', 'Chef PT', 'PT')];
      final groups = groupChefsByCountry(chefs, _countryNames);
      expect(groups.single.countryName, 'PT');
    });

    test('chef with no home_country_code goes into an unlabeled group '
        'rendered last', () {
      final chefs = [
        _chef('c1', 'Chef NL', 'NL'),
        _chef('c2', 'No Country Chef', null),
      ];
      final groups = groupChefsByCountry(chefs, _countryNames);
      expect(groups.last.countryName, isNull);
      expect(groups.last.chefs.single.displayName, 'No Country Chef');
    });

    test('empty chef list -> no groups', () {
      expect(groupChefsByCountry(const [], _countryNames), isEmpty);
    });
  });
}
