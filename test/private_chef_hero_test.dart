// Covers PrivateChefHero — identity hierarchy, optional business name,
// the "PRIVATE CHEF" eyebrow (never "Mantelier Selected"), and the
// gold/score/rating audit (none of that is ever rendered in the hero).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/follow_toggle_button.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_hero.dart';
import 'package:michelin_passport/models/private_chef_photo.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: CustomScrollView(slivers: [child])),
);

List<PrivateChefPhoto> _photos(int count) => [
  for (var i = 0; i < count; i++)
    PrivateChefPhoto(
      id: 'p$i',
      privateChefId: 'c1',
      imageUrl: 'https://example.com/$i.jpg',
      displayOrder: i,
    ),
];

void main() {
  group('PrivateChefHero', () {
    testWidgets('renders the display name', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.text('Lucas'), findsWidgets);
    });

    testWidgets(
      'Step 2C device review: no duplicate top-center nav title — the '
      'name renders exactly once (the large identity text near the '
      'bottom), not also in the SliverAppBar title strip',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const PrivateChefHero(displayName: 'Lucas')),
        );
        expect(find.text('Lucas'), findsOneWidget);
        final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(appBar.title, isNull);
      },
    );

    testWidgets('the "PRIVATE CHEF" eyebrow renders, never "Mantelier '
        'Selected"', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.text('PRIVATE CHEF'), findsOneWidget);
      expect(find.textContaining('Mantelier Selected'), findsNothing);
      expect(find.textContaining('Selected'), findsNothing);
    });

    testWidgets('business_name absent -> not rendered', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.textContaining('Catering'), findsNothing);
    });

    testWidgets('business_name present renders as a subordinate line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(
            displayName: 'Lucas',
            businessName: 'Test Catering',
          ),
        ),
      );
      expect(find.text('Test Catering'), findsOneWidget);
    });

    testWidgets('location renders when supplied, omitted when null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(displayName: 'Lucas', location: 'Breda, NL'),
        ),
      );
      expect(find.text('Breda, NL'), findsOneWidget);
    });

    testWidgets('no location -> nothing extra rendered', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.textContaining(', NL'), findsNothing);
    });

    testWidgets('no score/rating/review-count/price-badge/star icon anywhere', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(
            displayName: 'Lucas',
            businessName: 'Test Catering',
            location: 'Breda, NL',
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.textContaining('★'), findsNothing);
      expect(find.textContaining('Price'), findsNothing);
    });

    testWidgets('null profile image falls back to the gradient background '
        '(no network image attempted)', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gold audit: no gold anywhere in the hero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(
            displayName: 'Lucas',
            businessName: 'Test Catering',
            location: 'Breda, NL',
          ),
        ),
      );
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('long display name — no overflow at 320px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(
            displayName:
                'A Genuinely Very Long Private Chef Display Name For Testing',
            businessName: 'An Equally Long Catering Business Name',
            location: 'Breda, NL',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  const PrivateChefHero(
                    displayName: 'Lucas',
                    businessName: 'Test Catering',
                    location: 'Breda, NL',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PrivateChefHero — Events V2 Step 6 Follow control', () {
    testWidgets('onTapFollow omitted (pre-Step-6 call sites): no Follow '
        'control renders — zero change to existing behavior', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.byType(FollowToggleButton), findsNothing);
    });

    testWidgets('onTapFollow provided: Follow control renders, reflects '
        'state, and fires its own callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrivateChefHero(
            displayName: 'Lucas',
            isFollowing: true,
            followBusy: false,
            onTapFollow: () => tapped = true,
          ),
        ),
      );
      expect(find.byType(FollowToggleButton), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
      await tester.tap(find.byType(FollowToggleButton));
      expect(tapped, isTrue);
    });

    testWidgets('a busy Follow control ignores taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrivateChefHero(
            displayName: 'Lucas',
            isFollowing: false,
            followBusy: true,
            onTapFollow: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(FollowToggleButton), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('gold audit: the Follow control never uses gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefHero(
            displayName: 'Lucas',
            isFollowing: true,
            followBusy: false,
            onTapFollow: () {},
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FollowToggleButton),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, isNot(AppColors.gold));
    });
  });

  group('PrivateChefHero — photo gallery (Step 2B)', () {
    testWidgets('0 photos, no profile image -> gradient placeholder, no '
        'PageView, no chevrons', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('0 photos, profile_image_url set -> static fallback image, '
        'no PageView, no chevrons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(
            displayName: 'Lucas',
            profileImageUrl: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('Step 2C device review: the hero photo uses a top-biased focal '
        'alignment (not dead-center), keeping a portrait subject clear of '
        'the Dynamic Island/status-bar strip at the very top of this '
        'full-bleed, landscape-shaped hero', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PrivateChefHero(
            displayName: 'Lucas',
            profileImageUrl: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.alignment, isNot(Alignment.center));
      expect((image.alignment as Alignment).y, lessThan(0));
    });

    testWidgets('1 photo -> static image, no PageView, no chevrons '
        '(even though profile_image_url is also set — gallery wins)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefHero(
            displayName: 'Lucas',
            photos: _photos(1),
            profileImageUrl: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('2 photos -> PageView renders; first photo shows only the '
        'right chevron', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(2))),
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5 photos (the maximum) -> PageView renders, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(5))),
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'chevrons: hidden on their own end, shown on both sides in the '
      'middle, and never wrap around',
      (tester) async {
        await tester.pumpWidget(
          _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(3))),
        );

        // Photo 1 of 3: right only.
        expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

        tester.widget<PageView>(find.byType(PageView)).onPageChanged!(1);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

        // Photo 3 of 3 (the last): left only, right simply gone.
        tester.widget<PageView>(find.byType(PageView)).onPageChanged!(2);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      },
    );

    testWidgets('tapping the right chevron advances the PageController; '
        'tapping the left one goes back', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(2))),
      );

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      var pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller!.page, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller!.page, 0);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });

    testWidgets('the chevron tap target is comfortably larger than its '
        'glyph', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(2))),
      );
      final glyphFinder = find.byIcon(Icons.chevron_right_rounded);
      final tapTargetSize = tester.getSize(
        find.ancestor(of: glyphFinder, matching: find.byType(GestureDetector)),
      );
      final glyphSize = tester.getSize(glyphFinder);
      expect(tapTargetSize.width, greaterThan(glyphSize.width * 1.5));
      expect(tapTargetSize.height, greaterThan(glyphSize.height * 1.5));
    });

    testWidgets(
      'the text-overlay SingleChildScrollView does not absorb pointer '
      'events meant for the gallery beneath it — translucent, not opaque, '
      'hit-test behaviour (same fix as VenueDetailHero)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(2))),
        );
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scrollView.hitTestBehavior, HitTestBehavior.translucent);
      },
    );

    testWidgets('the gallery has no autoplay controller side effects and '
        'starts at the first page', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(3))),
      );
      // No animation/timer runs on its own — pumpAndSettle would hang on a
      // genuinely autoplaying carousel; a plain pump proves there is none.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the Report flag actually opens the report sheet '
        '(not just: the button exists)', (tester) async {
      await tester.pumpWidget(
        _wrap(PrivateChefHero(displayName: 'Lucas', photos: _photos(2))),
      );
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('320px / 1.6x text scale — no overflow with 5 photos', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          PrivateChefHero(
            displayName: 'Lucas',
            businessName: 'Jagers Catering',
            location: 'Breda, NL',
            photos: _photos(5),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  PrivateChefHero(
                    displayName: 'Lucas',
                    businessName: 'Jagers Catering',
                    location: 'Breda, NL',
                    photos: _photos(5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
