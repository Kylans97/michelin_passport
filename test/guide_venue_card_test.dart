// Covers GuideVenueCard/GuideVenueCardDivider (Step 2B) — presentation-only,
// no Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/guides/widgets/guide_venue_card.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('GuideVenueCard', () {
    testWidgets('renders title, location and the distinction slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Le Bernardin',
            locationLabel: 'New York, United States',
            distinction: const StarRow(count: 3, size: 12),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Le Bernardin'), findsOneWidget);
      expect(find.text('New York, United States'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole row is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Le Bernardin',
            locationLabel: 'New York, United States',
            distinction: const StarRow(count: 3, size: 12),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('Le Bernardin'));
      expect(tapped, isTrue);
    });

    testWidgets('an empty location label is omitted, not rendered blank', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Le Bernardin',
            locationLabel: '',
            distinction: const StarRow(count: 3, size: 12),
            onTap: () {},
          ),
        ),
      );
      expect(find.text(''), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long name at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title:
                'A Deliberately Extremely Long Restaurant Name Used To '
                'Confirm This Card Never Overflows At A Narrow Width',
            locationLabel:
                'A Deliberately Long City Name, A Deliberately '
                'Long Country Name',
            distinction: const StarRow(count: 3, size: 12),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                child: GuideVenueCard(
                  title: 'Le Bernardin',
                  locationLabel: 'New York, United States',
                  distinction: const StarRow(count: 3, size: 12),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 3-Key hotel with a long name/location at 320px does not '
        'overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title:
                'A Deliberately Extremely Long Hotel Name Used To '
                'Confirm This Card Never Overflows At A Narrow Width',
            locationLabel:
                'A Deliberately Long City Name, A Deliberately '
                'Long Country Name',
            distinction: const KeyRow(count: 3, size: 12),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(find.byType(KeyRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GuideVenueCardDivider', () {
    testWidgets('renders a hairline', (tester) async {
      await tester.pumpWidget(_wrap(const GuideVenueCardDivider()));
      expect(find.byType(GuideVenueCardDivider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
