// Covers Community Rankings, layout "B" (2026-10-30): one Filters button,
// a summary of what's active, a hairline ranked list with small photos,
// and the ivory Filters sheet. The real widget is pumped with hand-rolled
// fakes for its injected loaders and lookups.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/features/rankings/widgets/community_rankings_tab.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/restaurant.dart';

CommunityRankedVenue _restaurant({
  String id = 'r1',
  String name = 'Maison Verte',
  String country = 'FR',
  int stars = 2,
  int? w50b,
  double rating = 9.0,
  int members = 3,
}) => CommunityRankedVenue(
  kind: CommunityRankingKind.restaurants,
  id: id,
  name: name,
  city: 'Paris',
  countryCode: country,
  stars: stars,
  worlds50BestRank: w50b,
  communityRating: rating,
  memberCount: members,
);

const _hotel = CommunityRankedVenue(
  kind: CommunityRankingKind.hotels,
  id: 'h1',
  name: 'Villa Cora',
  city: 'Florence',
  countryCode: 'IT',
  keys: 2,
  communityRating: 8.7,
  memberCount: 4,
);

final _event = CommunityRankedVenue(
  kind: CommunityRankingKind.events,
  id: 'e1',
  name: 'Four Hands Dinner',
  city: 'Schoorl',
  countryCode: 'NL',
  communityRating: 9.2,
  memberCount: 3,
  startDate: DateTime(2026, 11, 22),
);

Widget _wrap({
  required Future<List<CommunityRankedVenue>> Function(CommunityRankingKind)
  loadRanking,
  Future<Restaurant?> Function(String id)? getRestaurantById,
  Future<Hotel?> Function(String id)? getHotelById,
}) => MaterialApp(
  home: Scaffold(
    body: CommunityRankingsTab(
      loadRanking: loadRanking,
      loadCountryNames: () async => {
        'FR': 'France',
        'IT': 'Italy',
        'NL': 'Netherlands',
      },
      getRestaurantById: getRestaurantById,
      getHotelById: getHotelById,
    ),
  ),
);

Future<List<CommunityRankedVenue>> _all(CommunityRankingKind kind) async =>
    switch (kind) {
      CommunityRankingKind.restaurants => [
        _restaurant(id: 'r1', name: 'First Place', rating: 9.5, members: 5),
        _restaurant(
          id: 'r2',
          name: 'Second Place',
          country: 'IT',
          stars: 3,
          w50b: 12,
          members: 10,
        ),
      ],
      CommunityRankingKind.hotels => [_hotel],
      CommunityRankingKind.events => [_event],
    };

void main() {
  group('applyCommunityFilters', () {
    final rows = [
      _restaurant(id: 'a', stars: 1),
      _restaurant(id: 'b', stars: 3, country: 'IT', w50b: 4),
    ];

    test('country and recognition narrow, order kept', () {
      List<String> ids(CommunityRankingFilters f) => [
        for (final v in applyCommunityFilters(rows, f)) v.id,
      ];
      expect(ids(const CommunityRankingFilters()), ['a', 'b']);
      expect(ids(const CommunityRankingFilters(countryCode: 'IT')), ['b']);
      expect(
        ids(
          const CommunityRankingFilters(
            recognition: CommunityRecognitionFilter.one,
          ),
        ),
        ['a'],
      );
      expect(
        ids(
          const CommunityRankingFilters(
            recognition: CommunityRecognitionFilter.worlds50Best,
          ),
        ),
        ['b'],
      );
    });

    test('Keys count for hotels; events ignore recognition', () {
      expect(
        applyCommunityFilters(
          [_hotel],
          const CommunityRankingFilters(
            kind: CommunityRankingKind.hotels,
            recognition: CommunityRecognitionFilter.two,
          ),
        ),
        hasLength(1),
      );
      expect(
        applyCommunityFilters(
          [_event],
          const CommunityRankingFilters(
            kind: CommunityRankingKind.events,
            recognition: CommunityRecognitionFilter.three,
          ),
        ),
        hasLength(1),
      );
    });

    test('summary names only what narrows; count excludes the type', () {
      const f = CommunityRankingFilters(
        countryCode: 'IT',
        recognition: CommunityRecognitionFilter.two,
      );
      expect(
        communityFiltersSummary(f, {'IT': 'Italy'}),
        'Restaurants · Italy · ★★',
      );
      expect(f.activeCount, 2);
      expect(
        communityFiltersSummary(const CommunityRankingFilters(), const {}),
        'Restaurants',
      );
    });
  });

  group('CommunityRankingsTab', () {
    testWidgets('shows the summary, a Filters button and ranked rows', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(loadRanking: _all));
      await tester.pumpAndSettle();

      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('First Place'), findsOneWidget);
      expect(find.text('9.5'), findsOneWidget);
      expect(find.text('5 members'), findsOneWidget);
      expect(find.text("World's 50 Best #12"), findsOneWidget);
      final firstY = tester.getTopLeft(find.text('First Place')).dy;
      final secondY = tester.getTopLeft(find.text('Second Place')).dy;
      expect(firstY, lessThan(secondY));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('the sheet filters by country and switches type', (
      tester,
    ) async {
      final loads = <CommunityRankingKind>[];
      await tester.pumpWidget(
        _wrap(
          loadRanking: (kind) {
            loads.add(kind);
            return _all(kind);
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('COUNTRY'), findsOneWidget);
      expect(find.text('Show 2 places'), findsOneWidget);
      await tester.tap(find.text('Italy'));
      await tester.pumpAndSettle();
      expect(find.text('Show 1 place'), findsOneWidget);
      await tester.tap(find.text('Show 1 place'));
      await tester.pumpAndSettle();

      expect(find.text('Restaurants · Italy'), findsOneWidget);
      expect(find.text('Filters · 1'), findsOneWidget);
      expect(find.text('First Place'), findsNothing);
      expect(find.text('Second Place'), findsOneWidget);

      await tester.tap(find.text('Filters · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hotels'));
      await tester.pumpAndSettle();
      expect(find.text('2 Keys'), findsOneWidget);
      await tester.tap(find.text('Show 1 place'));
      await tester.pumpAndSettle();
      expect(find.text('Villa Cora'), findsOneWidget);
      expect(find.byType(KeyRow), findsOneWidget);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.text('RECOGNITION'), findsNothing);
      await tester.tap(find.text('Show 1 place'));
      await tester.pumpAndSettle();
      expect(find.textContaining('22 Nov 2026'), findsOneWidget);

      // Each list is loaded once and cached.
      expect(loads, [
        CommunityRankingKind.restaurants,
        CommunityRankingKind.hotels,
        CommunityRankingKind.events,
      ]);
    });

    testWidgets('closing the sheet changes nothing', (tester) async {
      await tester.pumpWidget(_wrap(loadRanking: _all));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Italy'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('COUNTRY'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('First Place'), findsOneWidget);
    });

    testWidgets('an empty list shows the quiet empty line', (tester) async {
      await tester.pumpWidget(_wrap(loadRanking: (_) async => []));
      await tester.pumpAndSettle();
      final empty = tester.widget<Text>(find.text('No community data yet'));
      expect(empty.style?.color, AppColors.secondaryOnDark);
    });

    testWidgets('a failed load shows a message and Retry', (tester) async {
      await tester.pumpWidget(
        _wrap(loadRanking: (_) async => throw Exception('down')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load community rankings'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('never overflows at 320px', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          loadRanking: (_) async => [
            _restaurant(
              name: 'Gucci Osteria da Massimo Bottura Firenze',
              stars: 3,
              w50b: 1,
              rating: 10,
              members: 1234,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a restaurant row looks up exactly that restaurant once', (
      tester,
    ) async {
      final ids = <String>[];
      await tester.pumpWidget(
        _wrap(
          loadRanking: (_) async => [_restaurant(id: 'r42')],
          getRestaurantById: (id) async {
            ids.add(id);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maison Verte'));
      await tester.pumpAndSettle();
      expect(ids, ['r42']);
    });
  });
}
