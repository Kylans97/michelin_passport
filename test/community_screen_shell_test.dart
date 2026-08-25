// Covers CommunityScreen's own COMMUNITY tab (Community Typography +
// Dining Together Refinement, extended by COMMUNITY & FRIENDS FOUNDATION
// V1, then refined again by COMMUNITY V1 UI REFINEMENT) — Hottest Places/
// Community Ranking/Upcoming Events/Dining Together are all major
// editorial section titles, not tiny uppercase eyebrows; Dining Together
// is tappable. Trending Now and Recently Discovered are deliberately
// absent entirely (no canonical data source exists yet — see
// community_screen.dart's own extension-point comments) rather than shown
// as placeholder/empty sections. FRIENDS-tab and tab-switching coverage
// lives in community_friends_foundation_test.dart. CommunityScreen
// injects loadCommunityRankings/getRestaurantById (see its own doc
// comment for why) — the REAL widget is pumped directly with hand-rolled
// fakes, no mocking framework, no mirrored copy of its build() method.
// This is a deliberate departure from this app's usual "mirror a
// Supabase-eager screen" pattern: a mirror can never catch a defect in
// the actual production code path, which is exactly what happened here
// previously — see the Hot Right Now Bugfix note in
// docs/Architecture/NAVIGATION_INFORMATION_ARCHITECTURE_V2.md.

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
      // "Maison Verte" now legitimately appears twice: once as the
      // Hottest Places hero, once more as the actual #1 row inside the
      // Community Ranking feature card directly below it (both are
      // correctly derived from the exact same #1 ranking entry — a real
      // top-3 list must include the real #1, not artificially exclude
      // it).
      expect(find.text('Maison Verte'), findsNWidgets(2));
      expect(find.text('Highest rated by the community'), findsOneWidget);
      // Likewise legitimately doubled — the hero's own rating numeral and
      // the ranking card's own #1 row both display the same real 4.8.
      expect(find.text('4.8'), findsNWidgets(2));
      // Hottest Places' own caption never implies a temporal trending
      // algorithm the data doesn't support — "Highest rated by the
      // community" (already asserted above) is its only caption.
      // "Trending Now" is deliberately absent entirely (no fake/no
      // placeholder trending section anywhere on this page).
      expect(find.textContaining('This week'), findsNothing);
      expect(find.textContaining('Trending'), findsNothing);
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
      // Community Ranking and Dining Together are unconditional siblings
      // — a Hottest Places failure must never take them down too.
      expect(find.text('Community Ranking'), findsOneWidget);
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

      // "Maison Verte" legitimately appears twice now (Hottest Places
      // hero + the Community Ranking card's own #1 row) — .first targets
      // the hero specifically, which sits earlier in the tree.
      await tester.tap(find.text('Maison Verte').first);
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

    testWidgets('the major section titles use the same serif style, '
        'clearly smaller than the page title', (tester) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: () async => [_entry()]),
      );
      await tester.pumpAndSettle();

      final pageTitle = tester.widget<Text>(find.text('Community'));
      final sectionTitles = [
        tester.widget<Text>(find.text('Hottest Places')),
        tester.widget<Text>(find.text('Community Ranking')),
        tester.widget<Text>(find.text('Upcoming Events')),
        tester.widget<Text>(find.text('Dining Together')),
      ];
      final actionLink = tester.widget<Text>(find.text('Discover the concept'));

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
          greaterThan(actionLink.style!.fontSize!),
        );
      }
      // Never the tiny tracked-uppercase eyebrow style previously used.
      expect(find.text('HOTTEST PLACES'), findsNothing);
      expect(find.text('COMMUNITY RANKING'), findsNothing);
      expect(find.text('DINING TOGETHER'), findsNothing);
    });

    testWidgets('Community Ranking: title only (no explanatory sentence — '
        'the section name already explains the feature), rendered inside '
        'the ivory feature card with a restrained "See full ranking" '
        'action — the link always renders even with zero qualifying '
        'restaurants', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('Community Ranking'), findsOneWidget);
      expect(
        find.text('See how the community rates every restaurant.'),
        findsNothing,
      );
      expect(find.text('See full ranking'), findsOneWidget);
      expect(find.text('No restaurants have qualified yet.'), findsOneWidget);
      // Not tapped here: it pushes CommunityRankingsScreen, which embeds
      // the Supabase-eager CommunityRankingsTab — same established
      // limitation as every other pushed detail screen in this suite
      // (see this file's own Hottest Places hero-card tap test for the
      // identical reasoning). CommunityRankingsScreen has its own
      // dedicated mirror coverage in community_rankings_screen_test.dart.
    });

    testWidgets('Trending Now and Recently Discovered are completely '
        'absent — no canonical data source exists yet, so no placeholder '
        'or "coming soon" section is shown', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('Trending Now'), findsNothing);
      expect(find.text('Recently Discovered'), findsNothing);
      expect(
        find.text('Trending places will appear here.'),
        findsNothing,
      );
      expect(
        find.text('Recently discovered places will appear here.'),
        findsNothing,
      );
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

    testWidgets('Dining Together is tappable and opens its own concept '
        'page', (tester) async {
      await tester.pumpWidget(_wrap(loadCommunityRankings: () async => []));
      await tester.pumpAndSettle();
      // Dining Together may sit below the default test viewport — scroll
      // it into view before tapping, the same pattern used elsewhere in
      // this codebase for a target that may be off-screen.
      await tester.ensureVisible(find.text('Discover the concept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover the concept'));
      await tester.pumpAndSettle();
      expect(find.byType(DiningTogetherScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CommunityScreen — visual hierarchy (ivory content on deep green)', () {
    testWidgets('the Community Ranking feature card is an ivory surface '
        'with deep-green-family text, not ivory text on the deep-green '
        'canvas', (tester) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: () async => [_entry()]),
      );
      await tester.pumpAndSettle();

      final nameInCard = tester.widget<Text>(
        find.text('Maison Verte').last, // the ranking card's #1 row
      );
      expect(nameInCard.style?.color, isNot(AppColors.ivory));
      expect(nameInCard.style?.color, isNot(AppColors.gold));
    });

    testWidgets('the deep-green canvas remains the dominant page surface '
        '— the page is not converted to a mostly-ivory screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(loadCommunityRankings: () async => [_entry()]),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.deepGreen,
        ),
        findsWidgets,
      );
      // Exactly one ivory feature-card surface exists on this fixture
      // (Community Ranking) — Hottest Places/Upcoming Events/Dining
      // Together all stay on the dark canvas, never converted to ivory.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == AppColors.ivory,
        ),
        findsOneWidget,
      );
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
        'Connect, follow and explore together.',
        'Community Ranking',
        'Upcoming Events',
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
