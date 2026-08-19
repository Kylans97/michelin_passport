// Covers PrivateChefDiscoveryCard — Step 2C's large editorial replacement
// for PrivateChefRow: person-first identity, business/location joined on
// one subordinate line, up to 3 quiet descriptors, a large branded
// placeholder (never a small circular avatar) when there's no cover photo,
// the whole block tappable, no "View chef" button, no gold.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_discovery_card.dart';
import 'package:michelin_passport/models/private_chef.dart';

const _chef = PrivateChef(id: 'c1', slug: 'lucas', displayName: 'Test Chef');

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.ivory,
    body: SingleChildScrollView(child: child),
  ),
);

void main() {
  group('PrivateChefDiscoveryCard', () {
    testWidgets('renders display_name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: null,
            location: null,
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Test Chef'), findsOneWidget);
    });

    testWidgets('business name + location join on one subordinate line, '
        'name still comes first (person-first)', (tester) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'Lucas de Jager',
        businessName: 'Jagers Catering',
      );
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: chef,
            coverImageUrl: null,
            location: 'Breda, Netherlands',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Lucas de Jager'), findsOneWidget);
      expect(find.text('Jagers Catering · Breda, Netherlands'), findsOneWidget);
      final nameY = tester.getTopLeft(find.text('Lucas de Jager')).dy;
      final subtitleY = tester
          .getTopLeft(find.text('Jagers Catering · Breda, Netherlands'))
          .dy;
      expect(nameY, lessThan(subtitleY));
    });

    testWidgets('no business name -> location renders alone, no dangling '
        'separator', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: null,
            location: 'Breda, Netherlands',
            onTap: () {},
          ),
        ),
      );
      // Exact-text match (not textContaining) is itself proof there's no
      // leading/trailing "· " left dangling around the location alone.
      expect(find.text('Breda, Netherlands'), findsOneWidget);
    });

    testWidgets('no business name and no location -> no subtitle line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: null,
            location: null,
            onTap: () {},
          ),
        ),
      );
      // The subtitle line (business/location) renders in taupe; descriptors
      // render in deepGreen and the name in forestGreen — no taupe text at
      // all means the subtitle line itself was correctly omitted.
      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts.any((t) => t.style?.color == AppColors.taupe), isFalse);
    });

    testWidgets('descriptors render joined, max 3, PRIVATE DINING always '
        'present', (tester) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'Lucas',
        winePairingAvailable: true,
        travelAvailable: true,
      );
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: chef,
            coverImageUrl: null,
            location: null,
            onTap: () {},
          ),
        ),
      );
      expect(find.textContaining('PRIVATE DINING'), findsOneWidget);
      expect(find.textContaining('WINE PAIRING'), findsOneWidget);
      expect(find.textContaining('TRAVELS'), findsOneWidget);
    });

    testWidgets(
      'wine_pairing_available and travel_available both false -> only '
      'PRIVATE DINING shown, never a misleading descriptor',
      (tester) async {
        const chef = PrivateChef(
          id: 'c1',
          slug: 'lucas',
          displayName: 'Lucas',
          winePairingAvailable: false,
          travelAvailable: false,
        );
        await tester.pumpWidget(
          _wrap(
            PrivateChefDiscoveryCard(
              chef: chef,
              coverImageUrl: null,
              location: null,
              onTap: () {},
            ),
          ),
        );
        expect(find.text('PRIVATE DINING'), findsOneWidget);
        expect(find.textContaining('WINE PAIRING'), findsNothing);
        expect(find.textContaining('TRAVELS'), findsNothing);
      },
    );

    testWidgets(
      'no cover photo -> large branded placeholder, not a small circular '
      'avatar',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            PrivateChefDiscoveryCard(
              chef: _chef,
              coverImageUrl: null,
              location: null,
              onTap: () {},
            ),
          ),
        );
        expect(find.byType(CsImagePlaceholder), findsOneWidget);
        expect(find.byType(ClipOval), findsNothing);
        final size = tester.getSize(find.byType(CsImagePlaceholder));
        expect(size.width, greaterThan(120));
      },
    );

    testWidgets('empty-string cover photo url also falls back to the '
        'placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: '',
            location: null,
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
    });

    testWidgets('a real cover photo url renders via Image.network, not the '
        'placeholder — the Lucas-shaped state once a photo exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: 'https://example.com/private-chefs/test/0.jpg',
            location: null,
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(CsImagePlaceholder), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
    });

    testWidgets('tapping anywhere on the card fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: null,
            location: null,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(PrivateChefDiscoveryCard));
      expect(tapped, isTrue);
    });

    testWidgets('no "View chef"/"View Chef" CTA button is rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: _chef,
            coverImageUrl: null,
            location: null,
            onTap: () {},
          ),
        ),
      );
      expect(
        find.textContaining('View chef', findRichText: true),
        findsNothing,
      );
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('gold audit: no gold color anywhere in this card', (
      tester,
    ) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'Lucas',
        businessName: 'Jagers Catering',
        winePairingAvailable: true,
        travelAvailable: true,
      );
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: chef,
            coverImageUrl: null,
            location: 'Breda, Netherlands',
            onTap: () {},
          ),
        ),
      );
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width — no overflow with a long name/business name', (
      tester,
    ) async {
      const chef = PrivateChef(
        id: 'c1',
        slug: 'lucas',
        displayName: 'A Genuinely Very Long Private Chef Display Name Indeed',
        businessName: 'An Equally Long Catering Business Name For Testing',
        winePairingAvailable: true,
        travelAvailable: true,
      );
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          PrivateChefDiscoveryCard(
            chef: chef,
            coverImageUrl: null,
            location: 'A Genuinely Long City Name, Netherlands',
            onTap: () {},
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
              backgroundColor: AppColors.ivory,
              body: SingleChildScrollView(
                child: PrivateChefDiscoveryCard(
                  chef: _chef,
                  coverImageUrl: null,
                  location: 'Breda, Netherlands',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
