// Pure-logic tests for lib/features/explore/explore_view_model.dart:
// isExploreSearching (the Discovery/Search mode switch) and
// mergeVenueCountries (Search mode's combined country list). Neither
// touches Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/explore_view_model.dart';
import 'package:michelin_passport/models/venue_country.dart';

void main() {
  group('isExploreSearching — the Discovery/Search mode switch', () {
    test('empty query is Discovery mode', () {
      expect(isExploreSearching(''), isFalse);
    });

    test('a single typed character is Search mode', () {
      expect(isExploreSearching('A'), isTrue);
    });

    test('a query of only whitespace is still Discovery mode', () {
      expect(isExploreSearching('   '), isFalse);
    });

    test('a real query with surrounding whitespace is Search mode', () {
      expect(isExploreSearching('  Amsterdam  '), isTrue);
    });

    test('clearing a query back to empty returns to Discovery mode', () {
      expect(isExploreSearching('Amsterdam'), isTrue);
      expect(isExploreSearching(''), isFalse);
    });
  });

  group('mergeVenueCountries', () {
    const netherlands = VenueCountry(
      name: 'Netherlands',
      code: 'NL',
      flag: '🇳🇱',
    );
    const france = VenueCountry(name: 'France', code: 'FR', flag: '🇫🇷');
    const belgium = VenueCountry(name: 'Belgium', code: 'BE', flag: '🇧🇪');

    test('merges and dedupes by country code across every list given', () {
      final merged = mergeVenueCountries([
        [netherlands, france],
        [france, belgium],
        [netherlands],
      ]);
      expect(merged.map((c) => c.code).toSet(), {'NL', 'FR', 'BE'});
      expect(merged.length, 3);
    });

    test('result is sorted by name', () {
      final merged = mergeVenueCountries([
        [netherlands, france, belgium],
      ]);
      expect(merged.map((c) => c.name), ['Belgium', 'France', 'Netherlands']);
    });

    test('an empty list of catalogues merges to an empty result', () {
      expect(mergeVenueCountries(const []), isEmpty);
    });

    test('a single catalogue passes through unchanged (Restaurants-only/ '
        'Hotels-only/Events-only search type)', () {
      final merged = mergeVenueCountries([
        [france, belgium],
      ]);
      expect(merged.map((c) => c.code).toSet(), {'FR', 'BE'});
    });
  });
}
