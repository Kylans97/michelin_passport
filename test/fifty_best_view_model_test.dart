// Pure-logic tests for lib/features/guides/fifty_best_view_model.dart:
// preserveCountrySelection. Does not touch Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/guides/fifty_best_view_model.dart';
import 'package:michelin_passport/models/venue_country.dart';

void main() {
  group('preserveCountrySelection', () {
    const france = VenueCountry(name: 'France', code: 'FR', flag: '🇫🇷');
    const peru = VenueCountry(name: 'Peru', code: 'PE', flag: '🇵🇪');

    test('no prior selection stays unselected', () {
      expect(preserveCountrySelection(null, [france, peru]), isNull);
    });

    test('a selection still present in the new year is preserved', () {
      expect(preserveCountrySelection(france, [france, peru]), france);
    });

    test('a selection absent from the new year resets to null, never '
        'silently produces a zero-result state', () {
      expect(preserveCountrySelection(peru, [france]), isNull);
    });

    test('matches by country code, not object identity', () {
      const franceCopy = VenueCountry(name: 'France', code: 'FR', flag: '🇫🇷');
      expect(preserveCountrySelection(france, [franceCopy]), france);
    });

    test('an empty new-year country list always resets', () {
      expect(preserveCountrySelection(france, const []), isNull);
    });
  });
}
