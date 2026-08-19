// Covers formatChefLocation — Step 2C §12's "Breda, Netherlands" over
// "Breda, NL" preference, with graceful fallback and no dangling
// separators.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/private_chefs/private_chef_location.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _countryNames = {
  'NL': VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱'),
};

void main() {
  group('formatChefLocation', () {
    test('resolved country code renders as its full name', () {
      expect(
        formatChefLocation(
          city: 'Breda',
          countryCode: 'NL',
          countryNames: _countryNames,
        ),
        'Breda, Netherlands',
      );
    });

    test('unresolved country code falls back to the raw code', () {
      expect(
        formatChefLocation(
          city: 'Lisbon',
          countryCode: 'PT',
          countryNames: _countryNames,
        ),
        'Lisbon, PT',
      );
    });

    test('city only -> city alone, no dangling comma', () {
      expect(
        formatChefLocation(
          city: 'Breda',
          countryCode: null,
          countryNames: _countryNames,
        ),
        'Breda',
      );
    });

    test('country only -> country alone, no leading comma', () {
      expect(
        formatChefLocation(
          city: null,
          countryCode: 'NL',
          countryNames: _countryNames,
        ),
        'Netherlands',
      );
    });

    test('neither city nor country -> null', () {
      expect(
        formatChefLocation(
          city: null,
          countryCode: null,
          countryNames: _countryNames,
        ),
        isNull,
      );
    });

    test('blank strings treated the same as null', () {
      expect(
        formatChefLocation(
          city: '   ',
          countryCode: '  ',
          countryNames: _countryNames,
        ),
        isNull,
      );
    });
  });
}
