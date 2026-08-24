// Covers CommunityScreen (Community Typography + Dining Together
// Refinement — Hottest Places/Community Rankings/Dining Together are
// major editorial section titles, not tiny uppercase eyebrows; Dining
// Together is tappable). CommunityScreen injects loadCommunityRankings/
// getRestaurantById (see its own doc comment for why) — the REAL widget
// is pumped directly with hand-rolled fakes, no mocking framework, no
// mirrored copy of its build() method. This is a deliberate departure
// from this app's usual "mirror a Supabase-eager screen" pattern: a
// mirror can never catch a defect in the actual production code path,
// which is exactly what happened here previously — see the Hot Right Now
// Bugfix note in docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/features/community/community_screen.dart';
import 'package:michelin_passport/features/community/dining_together_screen.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/restaurant.dart';

CommunityRankingEntry _entry({int stars = 3}) => CommunityRankingEntry(
  restaurantId: 'r1',
  name: 'Maison Verte',
  city: 'Paris',
  countryFlag: '🇫🇷',
  michelinStars: stars,
  communityRating: 4.8,
  totalVisits: 42,
);

Widget _wrap({
  Future<List<CommunityRankingEntry>> Function()? loadCommunityRankings,
  Future<Restaurant?> Function(String id)? getRestaurantById,
}) => MaterialApp(
  home: CommunityScreen(
    loadCommunityRankings: loadCommunityRankings,
    getRestaurantById: getRestaurantById,
  ),
);

void main() {
  group('CommunityScreen — Hottest Places, real widget + fakes', () {
    testWidgets('a ranked restaurant renders the full hero: heading, card, '
        'name, honest copy, and rating', (tester) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: () async => [_entry()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hottest Places'), findsOneWidget);
      expect(find.text('RESTAURANT'), findsOneWidget);
      expect(find.text('Maison Verte'), findsOneWidget);
      expect(find.text('Highest rated by the community'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      // Never implies a temporal trending algorithm the data doesn't
      // support.
      expect(find.textContaining('Trending'), findsNothing);
      expect(find.textContaining('This week'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty ranking list omits the section — no fabricated '
        'restaurant, no crash', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();

      expect(find.text('Hottest Places'), findsNothing);
      expect(find.text('Maison Verte'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a repository error (e.g. the production '
        '"restaurant_rankings" view not existing) never crashes, and the '
        'rest of Community still renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async =>
              throw Exception('relation "restaurant_rankings" does not exist'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hottest Places'), findsNothing);
      // Community Rankings and Dining Together are unconditional siblings
      // — a Hottest Places failure must never take them down too.
      expect(find.text('Community Rankings'), findsOneWidget);
      expect(find.text('Dining Together'), findsOneWidget);
    });

    testWidgets('tapping the hero looks up the exact tapped restaurant '
        'exactly once, and a failed lookup never crashes and never '
        'navigates', (tester) async {
      // getRestaurantById intentionally returns null here rather than a
      // real Restaurant: _openRestaurant's own `if (restaurant == null)
      // return;` guard means Navigator.push is never reached, so it's
      // safe to pumpAndSettle afterward. Actually resolving a Restaurant
      // and letting the chain proceed to Navigator.push would build the
      // pushed RestaurantDetailScreen — Supabase-eager, same established
      // limitation as every other pushed detail screen in this app (see
      // restaurant_detail_screen.dart) — which no test in this suite
      // pumps past for exactly that reason.
      var lookupCalls = 0;
      String? lookedUpId;
      await tester.pumpWidget(
        _wrap(
          loadCommunityRankings: () async => [_entry()],
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
      expect(lookedUpId, 'r1');
      expect(tester.takeException(), isNull);
      // Still on Community — CommunityScreen itself is still in the tree.
      expect(find.byType(CommunityScreen), findsOneWidget);
    });
  });

  group('CommunityScreen — structure', () {
    testWidgets('renders the title and subtitle, ivory/secondary, never '
        'gold', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text('Community'));
      expect(title.style?.color, AppColors.ivory);
      expect(title.style?.color, isNot(AppColors.gold));
    });

    testWidgets('the three major section titles use the same serif style, '
        'clearly smaller than the page title and larger than their own '
        'description text', (tester) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: () async => [_entry()]),
      );
      await tester.pumpAndSettle();

      final pageTitle = tester.widget<Text>(find.text('Community'));
      final sectionTitles = [
        tester.widget<Text>(find.text('Hottest Places')),
        tester.widget<Text>(find.text('Community Rankings')),
        tester.widget<Text>(find.text('Dining Together')),
      ];
      final description = tester.widget<Text>(
        find.text('See how the community rates every restaurant.'),
      );
      final actionLink = tester.widget<Text>(find.text('View rankings'));

      for (final title in sectionTitles) {
        expect(title.style?.fontSize, sectionTitles.first.style?.fontSize);
        expect(
          title.style?.fontFamily,
          sectionTitles.first.style?.fontFamily,
        );
        expect(title.style?.color, AppColors.ivory);
        expect(title.style?.color, isNot(AppColors.gold));
        expect(title.style!.fontSize!, lessThan(pageTitle.style!.fontSize!));
        expect(
          title.style!.fontSize!,
          greaterThan(description.style!.fontSize!),
        );
        expect(
          title.style!.fontSize!,
          greaterThan(actionLink.style!.fontSize!),
        );
      }
      // Never the tiny tracked-uppercase eyebrow style previously used.
      expect(find.text('HOTTEST PLACES'), findsNothing);
      expect(find.text('COMMUNITY RANKINGS'), findsNothing);
      expect(find.text('DINING TOGETHER'), findsNothing);
    });

    testWidgets('Community Rankings: title, description, and a restrained '
        '"View rankings" action link — the link is not more prominent '
        'than the title', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('Community Rankings'), findsOneWidget);
      expect(
        find.text('See how the community rates every restaurant.'),
        findsOneWidget,
      );
      expect(find.text('View rankings'), findsOneWidget);
      // Not tapped here: it pushes CommunityRankingsScreen, which embeds
      // the Supabase-eager CommunityRankingsTab — same established
      // limitation as every other pushed detail screen in this suite
      // (see this file's own Hottest Places hero-card tap test for the
      // identical reasoning). CommunityRankingsScreen has its own
      // dedicated mirror coverage in community_rankings_screen_test.dart.
    });

    testWidgets('Meet the Community is completely absent', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('MEET THE COMMUNITY'), findsNothing);
      expect(find.text('Meet the Community'), findsNothing);
    });

    testWidgets('Dining Together: title, teaser copy, and a "Discover the '
        'concept" action link — never shows "Coming soon" directly on the '
        'landing page', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('Dining Together'), findsOneWidget);
      expect(find.text('Great tables are better shared.'), findsOneWidget);
      expect(find.text('Discover the concept'), findsOneWidget);
      expect(find.text('Coming soon'), findsNothing);
    });

    testWidgets('Dining Together is now tappable and opens its own '
        'concept page', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover the concept'));
      await tester.pumpAndSettle();
      expect(find.byType(DiningTogetherScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CommunityScreen — header alignment (bugfix, still intact)', () {
    // A physical-device regression: a plain Column loosens the cross-axis
    // constraint it gives non-flex children, so without
    // crossAxisAlignment.stretch on the outer Column, the header/section
    // content would shrink-wrap to its own widest line and sit centered.
    // Re-verified here with the new section-title copy.
    Future<void> expectAllLeftAligned(
      WidgetTester tester,
      Size size, {
      required bool withCard,
    }) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: CommunityScreen(
                loadCommunityRankings: () async =>
                    withCard ? [_entry()] : [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final texts = [
        'Community',
        'What people are chasing.',
        'Community Rankings',
        'View rankings',
        'Dining Together',
        'Great tables are better shared.',
        'Discover the concept',
        if (withCard) 'Hottest Places',
      ];
      for (final t in texts) {
        expect(
          tester.getTopLeft(find.text(t)).dx,
          CsSpacing.pageHorizontal,
          reason: '"$t" at size $size (withCard=$withCard)',
        );
      }
      await tester.binding.setSurfaceSize(null);
    }

    testWidgets('every section shares the same left edge as Explore/'
        'Passport (CsSpacing.pageHorizontal) at 320/390/430/800 widths', (
      tester,
    ) async {
      for (final size in [
        const Size(320, 844),
        const Size(390, 844),
        const Size(430, 932),
        const Size(800, 600),
      ]) {
        await expectAllLeftAligned(tester, size, withCard: false);
      }
    });

    testWidgets('the Hottest Places hero card does not shift the header '
        'or other sections off the left grid', (tester) async {
      await expectAllLeftAligned(
        tester,
        const Size(390, 844),
        withCard: true,
      );
    });
  });
}
