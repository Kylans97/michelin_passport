// Covers the root cause of the Explore search regression: a query with a
// trailing/leading space (routine on iOS — autocomplete/autocorrect
// commonly appends one when a word like a city name is confirmed) turned
// `%query%` into an ilike pattern requiring that literal space in the
// matched text, which name/city_name/country_name never have — silently
// returning zero results in every Explore mode (All/Restaurants/Hotels),
// for both RestaurantRepository.search() and HotelRepository.search(), and
// the equivalent EventsRepository.loadEvents(query:). buildIlikeOrFilter()
// is the single, shared, pure function all three now delegate to, so this
// is tested once here rather than duplicated per repository — and
// verified live against production for the exact reported cities in the
// same session (see the task report).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/search_query.dart';

void main() {
  group('buildIlikeOrFilter', () {
    test('trims a trailing space — the exact "Amsterdam " regression', () {
      final filter = buildIlikeOrFilter('Amsterdam ', [
        'name',
        'city_name',
        'country_name',
      ]);
      expect(
        filter,
        'name.ilike.%Amsterdam%,city_name.ilike.%Amsterdam%,'
        'country_name.ilike.%Amsterdam%',
      );
      expect(filter, isNot(contains('Amsterdam %')));
    });

    test('trims a leading space', () {
      final filter = buildIlikeOrFilter(' Maastricht', ['name']);
      expect(filter, 'name.ilike.%Maastricht%');
    });

    test('trims leading and trailing whitespace together', () {
      final filter = buildIlikeOrFilter('  Amsterdam  ', ['name']);
      expect(filter, 'name.ilike.%Amsterdam%');
    });

    test('a query that is only whitespace is treated as empty', () {
      expect(buildIlikeOrFilter('   ', ['name']), isNull);
    });

    test('an empty query returns null — no filter applied, never an '
        'always-false clause', () {
      expect(buildIlikeOrFilter('', ['name', 'city_name']), isNull);
    });

    test('builds one ilike clause per field, comma-joined, no country '
        'requirement encoded anywhere', () {
      final filter = buildIlikeOrFilter('Japan', [
        'name',
        'city',
        'venue_name',
      ]);
      expect(
        filter,
        'name.ilike.%Japan%,city.ilike.%Japan%,venue_name.ilike.%Japan%',
      );
    });

    test('an already-clean query (no whitespace) is unaffected', () {
      expect(
        buildIlikeOrFilter('Maastricht', ['city_name']),
        'city_name.ilike.%Maastricht%',
      );
    });
  });
}
