// Covers CommunityRankingsTab — Community Rankings across restaurants,
// hotels and events (redesign 2026-10-30). The real widget is pumped with
// hand-rolled fakes for its injected loader and lookups, no mocking
// framework, no mirror of its build() logic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/rankings/widgets/community_rankings_tab.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/restaurant.dart';

CommunityRankedVenue _restaurant({
  String id = 'r1',
  String name = 'Maison Verte',
  int stars = 2,
  int? w50b,
  double rating = 9.0,
  int members = 3,
}) => CommunityRankedVenue(
  kind: CommunityRankingKind.restaurants,
  id: id,
  name: name,
  city: 'Paris',
  countryFlag: '🇫🇷',
  stars: stars,
  worlds50BestRank: w50b,
  communityRating: rating,
  memberCount: members,
);

CommunityRankedVenue _hotel() => const CommunityRankedVenue(
  kind: CommunityRankingKind.hotels,
  id: 'h1',
  name: 'Villa Cora',
  city: 'Florence',
  keys: 2,
  communityRating: 8.7,
  memberCount: 4,
);

CommunityRankedVenue _event() => CommunityRankedVenue(
  kind: CommunityRankingKind.events,
  id: 'e1',
  name: 'Four Hands Dinner',
  city: 'Schoorl',
  communityRating: 9.2,
  memberCount: 3,
  startDate: DateTime(2026, 11, 22),
);

typedef _Loader =
    Future<List<CommunityRankedVenue>> Function(
      CommunityRankingKind kind,
      CommunityRecognitionFilter filter,
    );

Widget _wrap({
  required _Loader loadRanking,
  Future<Restaurant?> Function(String id)? getRestaurantById,
  Future<Hotel?> Function(String id)? getHotelById,
}) => MaterialApp(
  home: Scaffold(
    body: CommunityRankingsTab(
      loadRanking: loadRanking,
      getRestaurantById: getRestaurantById,
      getHotelById: getHotelById,
    ),
  ),
);

void main() {
  group('CommunityRankingsTab — states', () {
    testWidgets('shows a loading indicator before the future resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          loadRanking: (_, _) => Future.delayed(
            const Duration(milliseconds: 50),
            () => [_restaurant()],
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renders rows in input order with rank, name, score and '
        'member count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadRanking: (_, _) async => [
            _restaurant(id: 'r1', name: 'First Place', rating: 9.5, members: 5),
            _restaurant(id: 'r2', name: 'Second Place', members: 10),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('First Place'), findsOneWidget);
      expect(find.text('9.5'), findsOneWidget);
      expect(find.text('· 5 members'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('· 10 members'), findsOneWidget);
      final firstY = tester.getTopLeft(find.text('First Place')).dy;
      final secondY = tester.getTopLeft(find.text('Second Place')).dy;
      expect(firstY, lessThan(secondY));
    });

    testWidgets('empty result shows "No community data yet"', (tester) async {
      await tester.pumpWidget(_wrap(loadRanking: (_, _) async => []));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('No community data yet'));
      expect(text.style?.color, AppColors.secondaryOnDark);
    });

    testWidgets('backend error shows a restrained message, never the raw '
        'exception', (tester) async {
      await tester.pumpWidget(
        _wrap(loadRanking: (_, _) async => throw Exception('down')),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(
        find.text('Could not load community rankings'),
      );
      expect(text.style?.color, AppColors.secondaryOnDark);
      expect(find.textContaining('Exception'), findsNothing);
    });
  });

  group('CommunityRankingsTab — kinds and recognition', () {
    testWidgets('switching kind reloads, resets the filter, and shows the '
        "kind's own recognition labels", (tester) async {
      final calls = <(CommunityRankingKind, CommunityRecognitionFilter)>[];
      await tester.pumpWidget(
        _wrap(
          loadRanking: (kind, filter) async {
            calls.add((kind, filter));
            return switch (kind) {
              CommunityRankingKind.restaurants => [_restaurant()],
              CommunityRankingKind.hotels => [_hotel()],
              CommunityRankingKind.events => [_event()],
            };
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('★★'), findsOneWidget);
      expect(find.text("World's 50 Best"), findsOneWidget);

      await tester.tap(find.text('★★'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hotels'));
      await tester.pumpAndSettle();
      expect(find.text('2 Keys'), findsOneWidget);
      expect(find.text('Villa Cora'), findsOneWidget);
      expect(find.byType(KeyRow), findsOneWidget);

      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.text("World's 50 Best"), findsNothing); // no filter row
      expect(find.text('Four Hands Dinner'), findsOneWidget);
      expect(find.textContaining('22 Nov 2026'), findsOneWidget);

      expect(calls, [
        (CommunityRankingKind.restaurants, CommunityRecognitionFilter.all),
        (CommunityRankingKind.restaurants, CommunityRecognitionFilter.two),
        (CommunityRankingKind.hotels, CommunityRecognitionFilter.all),
        (CommunityRankingKind.events, CommunityRecognitionFilter.all),
      ]);
    });

    testWidgets("a World's 50 Best rank shows beside the stars, and no "
        'text is gold', (tester) async {
      await tester.pumpWidget(
        _wrap(loadRanking: (_, _) async => [_restaurant(w50b: 12)]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StarRow), findsOneWidget);
      expect(find.text('50 Best #12'), findsOneWidget);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
      expect(
        tester.widget<Text>(find.text('9.0')).style?.color,
        AppColors.forestGreen,
      );
    });

    testWidgets('never overflows at 320px', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(loadRanking: (_, _) async => [_restaurant(stars: 3, w50b: 1)]),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Maison Verte'), findsOneWidget);
    });
  });

  group('CommunityRankingsTab — navigation', () {
    // The lookups return null, so Navigator.push is never reached — the
    // pushed detail screens are Supabase-eager and never pumped here.
    testWidgets('a restaurant row looks up exactly that restaurant once', (
      tester,
    ) async {
      final ids = <String>[];
      await tester.pumpWidget(
        _wrap(
          loadRanking: (_, _) async => [_restaurant(id: 'r42')],
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
      expect(tester.takeException(), isNull);
    });

    testWidgets('a hotel row looks up exactly that hotel once', (tester) async {
      final ids = <String>[];
      await tester.pumpWidget(
        _wrap(
          loadRanking: (_, _) async => [_hotel()],
          getHotelById: (id) async {
            ids.add(id);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Villa Cora'));
      await tester.pumpAndSettle();
      expect(ids, ['h1']);
    });
  });
}
