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
  startAt: DateTime.utc(2026, 8, 27),
  endAt: DateTime.utc(2026, 8, 30),
  timezone: 'UTC',
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

  group(
    'SliverFillRemaining keyboard-overflow regression (Explore bugfix)',
    () {
      // Reproduces the reported bug: opening the iOS keyboard shrinks the
      // Scaffold body (default resizeToAvoidBottomInset: true), which
      // shrinks how much viewport height is left for the trailing
      // SliverFillRemaining once the header/search field/type chips/
      // country filter/(award-or-keys filter row) above it have taken
      // their share — sometimes down to less than the empty/error state's
      // own fixed content height. A plain SingleChildScrollView (this
      // file's usual `_wrap`) hands its child unbounded height and would
      // never exercise that failure — a real CustomScrollView inside a
      // height-constrained SizedBox is what actually reproduces it.
      //
      // 200px is not an arbitrary round number: `ExploreSearchEmptyState`'s
      // own fixed vertical padding alone is 112px (56 top + 56 bottom, see
      // explore_search_results_view.dart), so any viewport height at or
      // below that deflates to an exact ZERO-height box for its inner
      // Column — and a genuinely zero-sized box never reaches Flutter's
      // overflow-indicator/assertion path at all (there's nothing to
      // visibly clip), so a too-small probe height would pass even against
      // the ORIGINAL buggy `hasScrollBody: true` and prove nothing. 200px
      // leaves a small but *positive* remainder for the Column (well under
      // its own ~126px of content), which is the actual failure mode
      // reported on-device (a positive but insufficient remaining height,
      // not a literal zero) — confirmed against the pre-fix code during
      // development: `hasScrollBody: true` at this exact height threw
      // "A RenderFlex overflowed by 38 pixels", and `hasScrollBody: false`
      // (the shipped fix, used below) does not.
      //
      // `hasScrollBody: false` is exercised directly here rather than by
      // pumping the full ExploreScreen, which can't be widget-tested (see
      // this file's header comment) — this targets the exact shared sliver
      // composition every search type (All/Restaurants/Hotels/Events)
      // funnels through, so one test here stands in for all four rather
      // than needing a mode-specific duplicate of each.
      const double keyboardShrunkHeight = 200;

      Widget sliverWrap(
        Widget child, {
        double viewportHeight = keyboardShrunkHeight,
      }) => MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.deepGreen,
          body: SizedBox(
            height: viewportHeight,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(hasScrollBody: false, child: child),
              ],
            ),
          ),
        ),
      );

      testWidgets('ExploreSearchEmptyState in a keyboard-shrunk viewport (a '
          'positive, but insufficient, remaining height) scrolls instead of '
          'overflowing — no RenderFlex exception', (tester) async {
        await tester.pumpWidget(sliverWrap(const ExploreSearchEmptyState()));
        expect(find.text('No places found'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ExploreSearchErrorState in the same shrunk viewport scrolls '
          'instead of overflowing', (tester) async {
        await tester.pumpWidget(
          sliverWrap(ExploreSearchErrorState(onRetry: () {})),
        );
        expect(find.text('Could not load results'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'still renders cleanly with plenty of room (keyboard closed) — '
        'hasScrollBody: false is not a regression for the common case',
        (tester) async {
          await tester.pumpWidget(
            sliverWrap(const ExploreSearchEmptyState(), viewportHeight: 700),
          );
          expect(find.text('No places found'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('320px width, keyboard-shrunk viewport — no overflow', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                height: keyboardShrunkHeight,
                child: CustomScrollView(
                  slivers: [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: ExploreSearchEmptyState(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('1.6x text scale, keyboard-shrunk viewport — no overflow', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: Scaffold(
                backgroundColor: AppColors.deepGreen,
                body: SizedBox(
                  height: keyboardShrunkHeight,
                  child: CustomScrollView(
                    slivers: [
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: ExploreSearchEmptyState(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'a populated ExploreSearchResultsView (the non-empty branch, a '
        'plain SliverToBoxAdapter, not SliverFillRemaining) still scrolls '
        'cleanly in the same shrunk viewport — confirms this fix does not '
        'touch or regress the populated-results path',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                backgroundColor: AppColors.deepGreen,
                body: SizedBox(
                  height: 100,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: ExploreSearchResultsView(
                          results: ExploreSearchResults(
                            restaurants: [_restaurant()],
                            hotels: [_hotel()],
                            events: const [],
                          ),
                          onTapEvent: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

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
