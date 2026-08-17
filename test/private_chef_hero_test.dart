// Covers PrivateChefHero — identity hierarchy, optional business name,
// the "PRIVATE CHEF" eyebrow (never "Chasing Stars Selected"), and the
// gold/score/rating audit (none of that is ever rendered in the hero).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/private_chefs/widgets/private_chef_hero.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: CustomScrollView(slivers: [child])),
);

void main() {
  group('PrivateChefHero', () {
    testWidgets('renders the display name', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.text('Lucas'), findsWidgets);
    });

    testWidgets('the "PRIVATE CHEF" eyebrow renders, never "Chasing Stars '
        'Selected"', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrivateChefHero(displayName: 'Lucas')),
      );
      expect(find.text('PRIVATE CHEF'), findsOneWidget);
      expect(find.textContaining('Chasing Stars Selected'), findsNothing);
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
}
