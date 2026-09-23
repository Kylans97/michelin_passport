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

  // buildIlikeOrFilters() is what RestaurantRepository.search() and
  // HotelRepository.search() actually call now, so a combined query like
  // "Flore Amsterdam" can match a name and a city on the same row.
  // PostgrestFilterBuilder.or() appends to the `or` query parameter rather
  // than overwriting it (postgrest-2.7.0's appendSearchParams:
  // `searchParams[key] = [...searchParams[key] ?? [], value]`), and
  // PostgREST ANDs repeated top-level params together — so what matters
  // here, and what these tests check, is that each word becomes its own
  // independent group in the returned list, not that they get merged into
  // one broad OR. Verifying the caller applies `.or()` once per group
  // (rather than the group strings themselves) is what actually proves
  // the AND-across-words / OR-within-a-word behaviour; that loop lives in
  // RestaurantRepository.search()/HotelRepository.search(), not here.
  group('buildIlikeOrFilters', () {
    test('a single-word query returns one group, identical to what '
        'buildIlikeOrFilter() builds for the same query and fields — '
        'single-word search is unaffected by this change', () {
      final fields = ['name', 'city_name', 'country_name'];
      expect(
        buildIlikeOrFilters('Amsterdam', fields),
        [buildIlikeOrFilter('Amsterdam', fields)],
      );
      expect(
        buildIlikeOrFilters('Flore', fields),
        [buildIlikeOrFilter('Flore', fields)],
      );
    });

    test('two words return two independent groups, one per word', () {
      final filters = buildIlikeOrFilters('Flore Amsterdam', [
        'name',
        'city_name',
        'country_name',
      ]);
      expect(filters, [
        'name.ilike.%Flore%,city_name.ilike.%Flore%,'
            'country_name.ilike.%Flore%',
        'name.ilike.%Amsterdam%,city_name.ilike.%Amsterdam%,'
            'country_name.ilike.%Amsterdam%',
      ]);
    });

    test('three words return three independent groups — proves this '
        'scales past two, not a two-word special case', () {
      final filters = buildIlikeOrFilters('Flore Amsterdam Netherlands', [
        'name',
        'city_name',
        'country_name',
      ]);
      expect(filters, [
        'name.ilike.%Flore%,city_name.ilike.%Flore%,'
            'country_name.ilike.%Flore%',
        'name.ilike.%Amsterdam%,city_name.ilike.%Amsterdam%,'
            'country_name.ilike.%Amsterdam%',
        'name.ilike.%Netherlands%,city_name.ilike.%Netherlands%,'
            'country_name.ilike.%Netherlands%',
      ]);
    });

    test('a word with no matching venue anywhere stays its own group, '
        'not folded into the others — this is what makes "Flore Parijs" '
        'return nothing rather than everything matching either word: '
        'the caller ANDs these groups together, so a row needs a hit in '
        'EVERY group, and a Flore-in-Amsterdam row has no field '
        'matching "Parijs" to satisfy the second one', () {
      final filters = buildIlikeOrFilters('Flore Parijs', [
        'name',
        'city_name',
        'country_name',
      ]);
      expect(filters, [
        'name.ilike.%Flore%,city_name.ilike.%Flore%,'
            'country_name.ilike.%Flore%',
        'name.ilike.%Parijs%,city_name.ilike.%Parijs%,'
            'country_name.ilike.%Parijs%',
      ]);
      // The two groups are genuinely separate list entries, not merged
      // into one comma-joined string — merging them would turn this into
      // a single OR-across-everything filter, which is exactly the bug
      // this feature must not introduce.
      expect(filters.length, 2);
    });

    test('an empty or whitespace-only query returns an empty list — no '
        'filter applied, mirrors buildIlikeOrFilter()\'s null case', () {
      expect(buildIlikeOrFilters('', ['name']), isEmpty);
      expect(buildIlikeOrFilters('   ', ['name']), isEmpty);
    });

    test('repeated whitespace between words does not produce an empty '
        'group', () {
      final filters = buildIlikeOrFilters('Flore   Amsterdam', ['name']);
      expect(filters, ['name.ilike.%Flore%', 'name.ilike.%Amsterdam%']);
    });
  });
}
