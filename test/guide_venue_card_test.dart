// Covers GuideVenueCard/GuideVenueCardDivider (Step 2B) — presentation-only,
// no Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/guides/widgets/guide_gault_millau_mark.dart';
import 'package:michelin_passport/features/guides/widgets/guide_rank_mark.dart';
import 'package:michelin_passport/features/guides/widgets/guide_venue_card.dart';
import 'package:michelin_passport/models/gault_millau_award.dart';

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

    testWidgets('distinction is optional — omitted entirely when null '
        '(Step 2C: World\'s 50 Best has nothing to put there)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Noma',
            locationLabel: 'Copenhagen, Denmark',
            leading: const GuideRankMark(rank: 1),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Noma'), findsOneWidget);
      expect(find.byType(StarRow), findsNothing);
      expect(find.byType(KeyRow), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leading (Step 2C: GuideRankMark) renders before the '
        'thumbnail, and is absent by default (Michelin, Step 2B, is '
        'pixel-unaffected)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Noma',
            locationLabel: 'Copenhagen, Denmark',
            leading: const GuideRankMark(rank: 1),
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(GuideRankMark), findsOneWidget);

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
      expect(find.byType(GuideRankMark), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final rank in [1, 50, 100]) {
      testWidgets(
        'a #$rank ranked entry with a long name/location at 320px does '
        'not overflow',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              GuideVenueCard(
                title:
                    'A Deliberately Extremely Long Restaurant Name Used '
                    'To Confirm This Ranked Row Never Overflows',
                locationLabel:
                    'A Deliberately Long City Name, A Deliberately '
                    'Long Country Name',
                leading: GuideRankMark(rank: rank),
                onTap: () {},
              ),
              width: 320,
            ),
          );
          expect(find.text('#$rank'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('a ranked entry at 1.6x text scale does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                child: GuideVenueCard(
                  title: 'Noma',
                  locationLabel: 'Copenhagen, Denmark',
                  leading: const GuideRankMark(rank: 100),
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

  group('GuideVenueCard with GuideGaultMillauMark (Step 2D)', () {
    testWidgets('renders a Gault&Millau distinction with no leading mark, '
        'Michelin/50 Best unaffected by the addition', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Comme chez Soi',
            locationLabel: 'Brussels, Belgium',
            distinction: GuideGaultMillauMark(
              award: const GaultMillauAward(
                restaurantId: 'r1',
                guideYear: 2026,
                score: 18,
                toqueCount: 4,
              ),
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Comme chez Soi'), findsOneWidget);
      expect(find.text('18/20 · 4 Toques'), findsOneWidget);
      expect(find.byType(GuideRankMark), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long name with a combined score+toque distinction at '
        '320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title:
                'A Deliberately Extremely Long Restaurant Name Used To '
                'Confirm This Card Never Overflows At A Narrow Width',
            locationLabel:
                'A Deliberately Long City Name, A Deliberately '
                'Long Country Name',
            distinction: GuideGaultMillauMark(
              award: const GaultMillauAward(
                restaurantId: 'r1',
                guideYear: 2026,
                score: 19.5,
                toqueCount: 5,
                toqueColour: 'red',
              ),
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unscored distinction label renders truthfully, never a '
        'fabricated score', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'A Belgian Bistro',
            locationLabel: 'Ghent, Belgium',
            distinction: GuideGaultMillauMark(
              award: const GaultMillauAward(
                restaurantId: 'r1',
                guideYear: 2026,
                recognitionType: GaultMillauRecognitionType.unscoredCasual,
                distinctionLabel: 'H!P',
              ),
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('H!P'), findsOneWidget);
      expect(find.textContaining('/20'), findsNothing);
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
