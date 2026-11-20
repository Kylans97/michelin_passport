// Explore search for wine estates, trains and ships (2026-11-20): small
// catalogues filtered on the device, by stored fields only.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/explore/explore_view_model.dart';
import 'package:michelin_passport/features/explore/models/explore_search_results.dart';
import 'package:michelin_passport/features/explore/models/explore_search_type.dart';
import 'package:michelin_passport/models/journey.dart';
import 'package:michelin_passport/models/vineyard.dart';

const _bordeaux = Vineyard(
  id: 'v1',
  vineyardCode: 'vine_0001',
  name: 'Château Smith Haut Lafitte',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  region: 'Bordeaux',
  city: 'Martillac',
);

const _douro = Vineyard(
  id: 'v2',
  vineyardCode: 'vine_0002',
  name: 'Quinta do Crasto',
  countryCode: 'PT',
  countryName: 'Portugal',
  flagEmoji: '🇵🇹',
  region: 'Douro Valley',
);

Journey _journey(
  String id,
  String name,
  JourneyKind kind, {
  String? home,
  String? homeName,
  List<String> routes = const [],
}) => Journey(
  id: id,
  journeyCode: id,
  slug: id,
  kind: kind,
  name: name,
  operatorCode: 'op',
  operatorName: 'Belmond',
  primaryCountryCode: home,
  countryName: homeName,
  routeCountryCodes: routes,
);

void main() {
  test('the new filters are labelled for the chip row', () {
    expect(ExploreSearchType.estates.label, 'Wine estates');
    expect(ExploreSearchType.trains.label, 'Trains');
    expect(ExploreSearchType.ships.label, 'Ships');
  });

  group('filterExploreVineyards', () {
    test('matches the name, accents folded', () {
      expect(filterExploreVineyards([_bordeaux, _douro], query: 'chateau'), [
        _bordeaux,
      ]);
    });

    test('matches the stored region and town, so a place finds its '
        'estates', () {
      expect(filterExploreVineyards([_bordeaux, _douro], query: 'douro'), [
        _douro,
      ]);
      expect(filterExploreVineyards([_bordeaux, _douro], query: 'martil'), [
        _bordeaux,
      ]);
    });

    test('a country narrows it; one letter matches nothing', () {
      expect(
        filterExploreVineyards(
          [_bordeaux, _douro],
          query: 'qu',
          countryCode: 'FR',
        ),
        isEmpty,
      );
      expect(filterExploreVineyards([_bordeaux], query: 'c'), isEmpty);
    });
  });

  group('filterExploreJourneys', () {
    final train = _journey(
      't1',
      'Royal Scotsman',
      JourneyKind.train,
      home: 'GB',
      homeName: 'United Kingdom',
    );
    final ship = _journey(
      's1',
      'Royal Clipper',
      JourneyKind.ship,
      routes: ['IT', 'FR'],
    );

    test('a kind keeps only trains or only ships', () {
      expect(
        filterExploreJourneys(
          [train, ship],
          query: 'royal',
          kind: JourneyKind.train,
        ),
        [train],
      );
      expect(filterExploreJourneys([train, ship], query: 'royal'), [
        train,
        ship,
      ]);
    });

    test('a country matches the home country or any route', () {
      expect(
        filterExploreJourneys([train, ship], query: 'royal', countryCode: 'FR'),
        [ship],
      );
      expect(
        filterExploreJourneys([train, ship], query: 'royal', countryCode: 'GB'),
        [train],
      );
    });

    test('the operator matches too', () {
      expect(filterExploreJourneys([train], query: 'belmond'), [train]);
    });
  });

  test('country options come from the catalogue itself', () {
    expect(vineyardCountries([_douro, _bordeaux]).map((c) => c.code), [
      'FR',
      'PT',
    ]);
    expect(
      journeyCountries([
        _journey('t1', 'A', JourneyKind.train, home: 'GB', homeName: 'UK'),
        _journey('s1', 'B', JourneyKind.ship, home: 'IT', homeName: 'Italy'),
      ], JourneyKind.train).map((c) => c.code),
      ['GB'],
    );
  });

  test('results count estates and journeys with the rest', () {
    final results = ExploreSearchResults(
      restaurants: const [],
      hotels: const [],
      events: const [],
      vineyards: const [_bordeaux],
      journeys: [_journey('t1', 'A', JourneyKind.train)],
    );
    expect(results.isEmpty, isFalse);
    expect(results.totalCount, 2);
  });

  test('an estate card names its town and country, never the code', () {
    expect(_bordeaux.cardPlaceLabel, '🇫🇷  Martillac, France');
    expect(_douro.cardPlaceLabel, '🇵🇹  Douro Valley, Portugal');
  });
}
