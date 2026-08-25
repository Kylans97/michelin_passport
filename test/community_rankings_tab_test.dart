// Covers CommunityRankingsTab (Community Rankings Backend V1) — the
// widget that renders the actual ranking rows on CommunityRankingsScreen.
// CommunityRankingsTab now injects loadCommunityRankings/
// getRestaurantById (see its own doc comment), so the REAL widget is
// pumped directly with hand-rolled fakes, no mocking framework, no
// mirror of its build() logic. Previously this widget had ZERO test
// coverage at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/rankings/widgets/community_rankings_tab.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/restaurant.dart';

CommunityRankingEntry _entry({
  String id = 'r1',
  String name = 'Maison Verte',
  int stars = 2,
  double rating = 9.0,
  int visits = 3,
}) => CommunityRankingEntry(
  restaurantId: id,
  name: name,
  city: 'Paris',
  countryFlag: '🇫🇷',
  michelinStars: stars,
  communityRating: rating,
  totalVisits: visits,
);

Widget _wrap({
  required Future<List<CommunityRankingEntry>> Function({int? stars})
  loadCommunityRankings,
  Future<Restaurant?> Function(String id)? getRestaurantById,
}) => MaterialApp(
  home: Scaffold(
    body: CommunityRankingsTab(
      loadCommunityRankings: loadCommunityRankings,
      getRestaurantById: getRestaurantById,
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
          loadCommunityRankings: ({stars}) => Future.delayed(
            const Duration(milliseconds: 50),
            () => [_entry()],
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('renders ranking rows in input order with rank, name, '
        'rating and visit count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: ({stars}) async => [
            _entry(id: 'r1', name: 'First Place', rating: 9.5, visits: 5),
            _entry(id: 'r2', name: 'Second Place', rating: 9.0, visits: 10),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('First Place'), findsOneWidget);
      expect(find.text('9.5'), findsOneWidget);
      expect(find.text('5 visits'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Second Place'), findsOneWidget);
      expect(find.text('9.0'), findsOneWidget);
      expect(find.text('10 visits'), findsOneWidget);

      // Preserves backend order — First Place above Second Place.
      final firstY = tester.getTopLeft(find.text('First Place')).dy;
      final secondY = tester.getTopLeft(find.text('Second Place')).dy;
      expect(firstY, lessThan(secondY));
    });

    testWidgets('empty result shows "No community data yet" — never a '
        'fabricated row', (tester) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: ({stars}) async => []),
      );
      await tester.pumpAndSettle();
      expect(find.text('No community data yet'), findsOneWidget);
    });

    testWidgets('backend error shows a restrained error message — '
        'distinct from the empty-result message, never a raw exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: ({stars}) async =>
              throw Exception('relation "restaurant_rankings" does not exist'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load community rankings'), findsOneWidget);
      expect(find.text('No community data yet'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty message uses secondaryOnDark — the correct '
        'dark-surface text token — never textSecondary, a light-surface '
        'token that would render dark-on-dark and nearly invisible on '
        'this screen\'s deep-green canvas', (tester) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: ({stars}) async => []),
      );
      await tester.pumpAndSettle();
      final emptyText = tester.widget<Text>(find.text('No community data yet'));
      expect(emptyText.style?.color, AppColors.secondaryOnDark);
      expect(emptyText.style?.color, isNot(AppColors.textSecondary));
    });

    testWidgets('the error message uses secondaryOnDark — same '
        'dark-surface token as the empty message, never textSecondary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: ({stars}) async => throw Exception('down'),
        ),
      );
      await tester.pumpAndSettle();
      final errorText = tester.widget<Text>(
        find.text('Could not load community rankings'),
      );
      expect(errorText.style?.color, AppColors.secondaryOnDark);
      expect(errorText.style?.color, isNot(AppColors.textSecondary));
    });
  });

  group('CommunityRankingsTab — star filter', () {
    testWidgets('tapping a star filter reloads with the corresponding '
        'stars parameter', (tester) async {
      final requestedStars = <int?>[];
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: ({stars}) async {
            requestedStars.add(stars);
            return [_entry()];
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(requestedStars, [null]); // "All ★" is the default

      await tester.tap(find.text('★★'));
      await tester.pumpAndSettle();
      expect(requestedStars, [null, 2]);

      await tester.tap(find.text('All ★'));
      await tester.pumpAndSettle();
      expect(requestedStars, [null, 2, null]);
    });
  });

  group('CommunityRankingsTab — responsive', () {
    testWidgets('the filter row and a ranked card (stars + flag + city) '
        'never overflow at 320px', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: ({stars}) async => [_entry(stars: 3)]),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('All ★'), findsOneWidget);
      expect(find.text('★★★'), findsOneWidget);
      expect(find.text('Maison Verte'), findsOneWidget);
    });
  });

  group('CommunityRankingsTab — navigation', () {
    testWidgets('tapping a row looks up the exact tapped restaurant '
        'exactly once, and a failed lookup never crashes and never '
        'navigates', (tester) async {
      // getRestaurantById intentionally returns null: _openRestaurant's
      // own `if (restaurant == null) return;` guard means Navigator.push
      // is never reached, so it's safe to pumpAndSettle afterward —
      // resolving a real Restaurant and letting the chain proceed would
      // build the pushed RestaurantDetailScreen, which is Supabase-eager
      // (same established limitation as every other pushed detail screen
      // in this app) and is never pumped past in this test suite.
      var lookupCalls = 0;
      String? lookedUpId;
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: ({stars}) async => [_entry(id: 'r42')],
          getRestaurantById: (id) async {
            lookupCalls++;
            lookedUpId = id;
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maison Verte'));
      await tester.pumpAndSettle();

      expect(lookupCalls, 1);
      expect(lookedUpId, 'r42');
      expect(tester.takeException(), isNull);
      expect(find.byType(CommunityRankingsTab), findsOneWidget);
    });
  });
}
