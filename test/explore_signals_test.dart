import 'package:michelin_passport/features/explore/explore_signals.dart';
import 'package:michelin_passport/features/explore/models/explore_filters.dart';
import 'package:michelin_passport/features/explore/models/explore_search_results.dart';
import 'package:michelin_passport/features/explore/models/explore_search_type.dart';
import 'package:michelin_passport/models/cuisine_family.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_country.dart';
import 'package:flutter_test/flutter_test.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Test Kitchen',
  michelinStars: 1,
  inclusionReason: 'michelin_star',
  cityName: 'São Paulo',
  cityId: 'c-sp',
  countryCode: 'BR',
  countryName: 'Brazil',
  flagEmoji: '🇧🇷',
  address: '1 Test Street',
);

const _hotel = Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Test Hotel',
  michelinKeys: 1,
  cityName: 'Amsterdam',
  cityId: 'c-ams',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

const _results = ExploreSearchResults(
  restaurants: [_restaurant],
  hotels: [_hotel],
  events: [],
);

const _families = [CuisineFamily(slug: 'french', name: 'French')];
const _countries = [
  VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱'),
];

List<ExploreSignal> _match(String q) => searchMatches(
  query: q,
  results: _results,
  families: _families,
  countries: _countries,
);

void main() {
  test('normalizeForMatch folds case, accents and spaces', () {
    expect(normalizeForMatch('  São   Paulo '), 'sao paulo');
    expect(normalizeForMatch('Œuvre Straße'), 'oeuvre strasse');
    expect(normalizeForMatch('Zürich'), 'zurich');
  });

  test('an exact city name matches the city id, never the text', () {
    expect(_match('sao paulo'), [
      const ExploreSignal('search_match', 'city', 'c-sp'),
    ]);
  });

  test('a partial name matches nothing', () {
    expect(_match('sao'), isEmpty);
    expect(_match('Amster'), isEmpty);
    expect(_match('a'), isEmpty);
  });

  test('cuisine family, country and venue names match exactly', () {
    expect(_match('French'), [
      const ExploreSignal('search_match', 'cuisine_family', 'french'),
    ]);
    expect(_match('netherlands'), [
      const ExploreSignal('search_match', 'country', 'NL'),
    ]);
    expect(_match('test hotel'), [
      const ExploreSignal('search_match', 'hotel', 'h1'),
    ]);
    expect(_match('Test Kitchen'), [
      const ExploreSignal('search_match', 'restaurant', 'r1'),
    ]);
  });

  test('no stored value can carry typed text', () {
    final all = [
      ..._match('sao paulo'),
      ..._match('french'),
      ..._match('netherlands'),
      ..._match('test hotel'),
    ];
    for (final s in all) {
      expect(s.value, matches(RegExp(r'^[A-Za-z0-9_-]{1,64}$')));
    }
  });

  test('activeFilters skips All and empty choices', () {
    expect(
      activeFilters(
        searchType: ExploreSearchType.all,
        countryCode: null,
        cuisineFamilies: const {},
        restaurantAward: RestaurantAwardFilter.all,
        hotelKeys: HotelKeysFilter.all,
      ),
      isEmpty,
    );
    expect(
      activeFilters(
        searchType: ExploreSearchType.restaurants,
        countryCode: 'PT',
        cuisineFamilies: const {'french'},
        restaurantAward: RestaurantAwardFilter.twoStars,
        hotelKeys: HotelKeysFilter.all,
      ),
      const [
        ExploreSignal('filter', 'search_type', 'restaurants'),
        ExploreSignal('filter', 'country', 'PT'),
        ExploreSignal('filter', 'cuisine_family', 'french'),
        ExploreSignal('filter', 'restaurant_award', 'twoStars'),
      ],
    );
  });

  test('noResults carries filters and matches, or one bare row', () {
    expect(noResults(filters: const [], matches: const []), const [
      ExploreSignal('no_results'),
    ]);
    expect(
      noResults(
        filters: const [ExploreSignal('filter', 'country', 'PT')],
        matches: const [
          ExploreSignal('search_match', 'cuisine_family', 'french'),
        ],
      ),
      const [
        ExploreSignal('no_results', 'country', 'PT'),
        ExploreSignal('no_results', 'cuisine_family', 'french'),
      ],
    );
  });

  test('toRow leaves out an empty dimension and value', () {
    expect(const ExploreSignal('no_results').toRow('u'), {
      'user_id': 'u',
      'signal': 'no_results',
    });
  });
}
