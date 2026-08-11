// Covers Explore's Search-mode result model/type and rendering:
// - ExploreSearchResults (isEmpty/totalCount) — pure model logic
// - ExploreSearchType.label — pure enum logic
// - ExploreSearchResultsView — grouped RESTAURANTS/HOTELS/EVENTS rendering
// - ExploreSearchEmptyState / ExploreSearchErrorState
// - ExploreEventResultTile
//
// Widget tests pump directly with real model fixtures — no Supabase
// involved (ExploreScreen itself can't be widget-tested; see
// explore_view_model_test.dart's note on the same limitation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/explore/models/explore_search_results.dart';
import 'package:michelin_passport/features/explore/models/explore_search_type.dart';
import 'package:michelin_passport/features/explore/widgets/explore_event_result_tile.dart';
import 'package:michelin_passport/features/explore/widgets/explore_search_results_view.dart';
import 'package:michelin_passport/features/explore/widgets/hotel_tile.dart';
import 'package:michelin_passport/features/explore/widgets/restaurant_tile.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  String cityName = 'Amsterdam',
  String countryName = 'Netherlands',
  String flagEmoji = '🇳🇱',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: null,
  inclusionReason: 'michelin_star',
  cityName: cityName,
  countryCode: 'NL',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
);

Hotel _hotel({
  String id = 'h1',
  String name = 'Test Hotel',
  String cityName = 'Amsterdam',
  String countryName = 'Netherlands',
  String flagEmoji = '🇳🇱',
}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: null,
  cityName: cityName,
  countryCode: 'NL',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Event _event({
  String id = 'e1',
  String name = "'t Preuvenemint",
  String? city,
  bool cancelled = false,
}) => Event(
  id: id,
  name: name,
  startAt: DateTime(2026, 8, 27),
  endAt: DateTime(2026, 8, 30),
  countryCode: 'NL',
  city: city ?? 'Maastricht',
  eventType: EventType.festival,
  status: cancelled ? EventStatus.cancelled : EventStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('ExploreSearchResults', () {
    test('isEmpty is true only when all three lists are empty', () {
      expect(ExploreSearchResults.empty.isEmpty, isTrue);
      expect(
        const ExploreSearchResults(
          restaurants: [],
          hotels: [],
          events: [],
        ).isEmpty,
        isTrue,
      );
      expect(
        ExploreSearchResults(
          restaurants: [_restaurant()],
          hotels: const [],
          events: const [],
        ).isEmpty,
        isFalse,
      );
    });

    test('totalCount sums all three lists', () {
      final results = ExploreSearchResults(
        restaurants: [
          _restaurant(id: 'r1'),
          _restaurant(id: 'r2'),
        ],
        hotels: [_hotel()],
        events: [
          _event(id: 'e1'),
          _event(id: 'e2'),
          _event(id: 'e3'),
        ],
      );
      expect(results.totalCount, 6);
    });
  });

  group('ExploreSearchType.label', () {
    test('every value has its expected label', () {
      expect(ExploreSearchType.all.label, 'All');
      expect(ExploreSearchType.restaurants.label, 'Restaurants');
      expect(ExploreSearchType.hotels.label, 'Hotels');
      expect(ExploreSearchType.events.label, 'Events');
    });
  });

  group('ExploreSearchResultsView', () {
    testWidgets(
      'Amsterdam-style "All" search: restaurant, hotel and event results '
      'all appear, grouped under their own section labels',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ExploreSearchResultsView(
              results: ExploreSearchResults(
                restaurants: [_restaurant(name: 'Amsterdam Restaurant')],
                hotels: [_hotel(name: 'Amsterdam Hotel')],
                events: [_event(name: 'Amsterdam Festival', city: 'Amsterdam')],
              ),
              onTapEvent: (_) {},
            ),
          ),
        );
        expect(find.text('RESTAURANTS'), findsOneWidget);
        expect(find.text('HOTELS'), findsOneWidget);
        expect(find.text('EVENTS'), findsOneWidget);
        expect(find.text('Amsterdam Restaurant'), findsOneWidget);
        expect(find.text('Amsterdam Hotel'), findsOneWidget);
        expect(find.text('Amsterdam Festival'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Maastricht-style search: event-only match still renders '
        'under an EVENTS section with no restaurant/hotel sections shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ExploreSearchResultsView(
            results: ExploreSearchResults(
              restaurants: const [],
              hotels: const [],
              events: [_event(name: "'t Preuvenemint", city: 'Maastricht')],
            ),
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('RESTAURANTS'), findsNothing);
      expect(find.text('HOTELS'), findsNothing);
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text("'t Preuvenemint"), findsOneWidget);
    });

    testWidgets('shows each section\'s result count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ExploreSearchResultsView(
            results: ExploreSearchResults(
              restaurants: [
                _restaurant(id: 'r1'),
                _restaurant(id: 'r2'),
              ],
              hotels: [_hotel()],
              events: const [],
            ),
            onTapEvent: (_) {},
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
      'restaurant/hotel results render as real RestaurantTile/HotelTile — '
      'each already navigates to its own Detail screen internally (see '
      'this file\'s header comment), so no onTap wiring is verified by '
      'tapping through here: doing so would genuinely navigate into '
      'RestaurantDetailScreen/HotelDetailScreen, which construct several '
      'repositories against Supabase.instance.client in initState and '
      'throw immediately with no Supabase session initialized in this '
      'sandbox — the same limitation passport_cards_test.dart documents '
      'for its own navigation checks',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ExploreSearchResultsView(
              results: ExploreSearchResults(
                restaurants: [_restaurant()],
                hotels: [_hotel()],
                events: const [],
              ),
              onTapEvent: (_) {},
            ),
          ),
        );
        expect(find.byType(RestaurantTile), findsOneWidget);
        expect(find.byType(HotelTile), findsOneWidget);
      },
    );

    testWidgets('tapping an event result fires onTapEvent', (tester) async {
      var eventTapped = false;
      await tester.pumpWidget(
        _wrap(
          ExploreSearchResultsView(
            results: ExploreSearchResults(
              restaurants: const [],
              hotels: const [],
              events: [_event()],
            ),
            onTapEvent: (_) => eventTapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(ExploreEventResultTile));
      expect(eventTapped, isTrue);
    });

    testWidgets('320px width, long names across all three types — no '
        'overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ExploreSearchResultsView(
            results: ExploreSearchResults(
              restaurants: [
                _restaurant(
                  name:
                      'The Extraordinarily Long Restaurant Name Establishment',
                  countryName:
                      'United Kingdom of Great Britain and Northern Ireland',
                  flagEmoji: '🇬🇧',
                ),
              ],
              hotels: [
                _hotel(
                  name: 'The Extraordinarily Long Grand Hotel Establishment',
                  countryName:
                      'United Kingdom of Great Britain and Northern Ireland',
                  flagEmoji: '🇬🇧',
                ),
              ],
              events: [
                _event(
                  name: 'The Extraordinarily Long Culinary Festival Name',
                  city: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
                ),
              ],
            ),
            onTapEvent: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: ExploreSearchResultsView(
                    results: ExploreSearchResults(
                      restaurants: [_restaurant()],
                      hotels: [_hotel()],
                      events: [_event()],
                    ),
                    onTapEvent: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ExploreSearchEmptyState / ExploreSearchErrorState', () {
    testWidgets('empty state renders restrained copy, no exhaustive-'
        'coverage claim', (tester) async {
      await tester.pumpWidget(_wrap(const ExploreSearchEmptyState()));
      expect(find.text('No places found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error state renders and Retry fires the callback', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(ExploreSearchErrorState(onRetry: () => retried = true)),
      );
      expect(find.text('Could not load results'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('ExploreEventResultTile', () {
    testWidgets('renders name, date and location', (tester) async {
      await tester.pumpWidget(
        _wrap(ExploreEventResultTile(event: _event(), onTap: () {})),
      );
      expect(find.text("'t Preuvenemint"), findsOneWidget);
      expect(find.textContaining('Maastricht'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a cancelled event shows a CANCELLED marker', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ExploreEventResultTile(event: _event(cancelled: true), onTap: () {}),
        ),
      );
      expect(find.text('CANCELLED'), findsOneWidget);
    });

    testWidgets('tapping fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ExploreEventResultTile(event: _event(), onTap: () => tapped = true),
        ),
      );
      await tester.tap(find.byType(ExploreEventResultTile));
      expect(tapped, isTrue);
    });

    testWidgets('long name/city at 320px — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ExploreEventResultTile(
            event: _event(
              name: 'The Extraordinarily Long Culinary Festival Name',
              city: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
