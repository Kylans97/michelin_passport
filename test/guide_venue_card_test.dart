// Covers GuideVenueCard/GuideVenueCardDivider (Step 1B: photo-ready
// catalogue rows) — presentation-only, no Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/core/widgets/venue_thumbnail.dart';
import 'package:michelin_passport/features/guides/widgets/guide_gault_millau_mark.dart';
import 'package:michelin_passport/features/guides/widgets/guide_venue_card.dart';
import 'package:michelin_passport/models/gault_millau_award.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.ivory,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('GuideVenueCard', () {
    testWidgets('renders title, city, flag and the inline-recognition slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Le Bernardin',
            inlineRecognition: const StarRow(count: 3, size: 12),
            cityName: 'New York',
            countryName: 'United States',
            flagEmoji: '🇺🇸',
            onTap: () {},
          ),
        ),
      );
      // Text.rich (the title carries an inline StarRow via a WidgetSpan) —
      // toPlainText() includes the WidgetSpans' placeholder characters, so
      // an exact find.text match needs textContaining instead.
      expect(
        find.textContaining('Le Bernardin', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('New York'), findsOneWidget);
      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the leading slot is VenueThumbnail — the same photo-ready seam '
      'Explore\'s RestaurantTile/HotelTile already use (Step 1B)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideVenueCard(
              title: 'Le Bernardin',
              cityName: 'New York',
              onTap: () {},
            ),
          ),
        );
        final thumbnail = tester.widget<VenueThumbnail>(
          find.byType(VenueThumbnail),
        );
        expect(thumbnail.imageUrl, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a real imageUrl and a null imageUrl produce the same row geometry '
      '(Step 1B photography stress test — the row must not shift '
      'depending on the image source)',
      (tester) async {
        Future<Size> pumpAndMeasure(String? imageUrl) async {
          await tester.pumpWidget(
            _wrap(
              GuideVenueCard(
                title: 'Le Bernardin',
                cityName: 'New York',
                imageUrl: imageUrl,
                onTap: () {},
              ),
            ),
          );
          return tester.getSize(find.byType(VenueThumbnail));
        }

        final placeholderSize = await pumpAndMeasure(null);
        final photoSize = await pumpAndMeasure('https://example.com/venue.jpg');
        expect(placeholderSize, photoSize);
      },
    );

    testWidgets('the whole row is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GuideVenueCard(
            title: 'Le Bernardin',
            inlineRecognition: const StarRow(count: 3, size: 12),
            cityName: 'New York',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.textContaining('Le Bernardin', findRichText: true));
      expect(tapped, isTrue);
    });

    testWidgets('an empty city is omitted, not rendered blank', (tester) async {
      await tester.pumpWidget(
        _wrap(GuideVenueCard(title: 'Le Bernardin', onTap: () {})),
      );
      expect(find.text(''), findsNothing);
      expect(tester.takeException(), isNull);
    });

    group('accessibility semantics', () {
      testWidgets(
        'combines name, city, country and recognition into one spoken '
        'label — "Arzak, San Sebastián, Spain, 3 Michelin stars"',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              GuideVenueCard(
                title: 'Arzak',
                inlineRecognition: const StarRow(count: 3, size: 12),
                cityName: 'San Sebastián',
                countryName: 'Spain',
                recognitionSemanticLabel: '3 Michelin stars',
                onTap: () {},
              ),
            ),
          );
          final semantics = tester.getSemantics(find.byType(GuideVenueCard));
          expect(
            semantics.label,
            'Arzak, San Sebastián, Spain, 3 Michelin stars',
          );
        },
      );

      testWidgets(
        'a hotel row reports "2 Michelin Keys", never relying on the gold '
        'icon alone',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              GuideVenueCard(
                title: 'Hotel X',
                inlineRecognition: const KeyRow(count: 2, size: 12),
                cityName: 'Paris',
                countryName: 'France',
                recognitionSemanticLabel: '2 Michelin Keys',
                onTap: () {},
              ),
            ),
          );
          final semantics = tester.getSemantics(find.byType(GuideVenueCard));
          expect(semantics.label, 'Hotel X, Paris, France, 2 Michelin Keys');
        },
      );

      testWidgets('tap target spans the full row width', (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideVenueCard(
              title: 'Arzak',
              cityName: 'San Sebastián',
              onTap: () {},
            ),
            width: 390,
          ),
        );
        final size = tester.getSize(find.byType(InkWell));
        expect(size.width, greaterThan(300));
      });
    });

    group('Michelin restaurant examples', () {
      for (final entry in {
        'Arzak': 3,
        'Tout a Fait': 1,
        'A Deliberately Long Canonical-Style Restaurant Name Used To '
                'Confirm This Row Never Overflows':
            2,
      }.entries) {
        testWidgets(
          '"${entry.key}" with ${entry.value}★ at 320px does not overflow '
          'and the name wraps rather than truncating',
          (tester) async {
            await tester.pumpWidget(
              _wrap(
                GuideVenueCard(
                  title: entry.key,
                  inlineRecognition: StarRow(count: entry.value, size: 12),
                  cityName: 'San Sebastián',
                  countryName: 'Spain',
                  flagEmoji: '🇪🇸',
                  onTap: () {},
                ),
                width: 320,
              ),
            );
            expect(tester.takeException(), isNull);
            // The title (first Text in the tree, ahead of the city line)
            // is a Text.rich carrying the inline StarRow — still a [Text]
            // widget, just with a TextSpan instead of `data`.
            final title = tester.widget<Text>(
              find
                  .descendant(
                    of: find.byType(GuideVenueCard),
                    matching: find.byType(Text),
                  )
                  .first,
            );
            expect(title.maxLines, isNull);
            expect(title.overflow, isNull);
          },
        );
      }
    });

    group('Michelin hotel examples', () {
      for (final keys in [1, 2, 3]) {
        testWidgets(
          'a $keys-Key hotel with a long name at 320px does not overflow',
          (tester) async {
            await tester.pumpWidget(
              _wrap(
                GuideVenueCard(
                  title:
                      'A Deliberately Extremely Long Hotel Name Used To '
                      'Confirm This Card Never Overflows At A Narrow Width',
                  inlineRecognition: KeyRow(count: keys, size: 12),
                  cityName: 'Paris',
                  countryName: 'France',
                  flagEmoji: '🇫🇷',
                  onTap: () {},
                ),
                width: 320,
              ),
            );
            expect(find.byType(KeyRow), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    });

    group("World's 50 Best examples", () {
      for (final rank in [1, 10, 50]) {
        testWidgets('rank #$rank with a year metadata line renders cleanly '
            'without affecting venue-name hierarchy', (tester) async {
          await tester.pumpWidget(
            _wrap(
              GuideVenueCard(
                title: 'Noma',
                metadataLine: Text(
                  '#$rank · 2026',
                  style: const TextStyle(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                cityName: 'Copenhagen',
                countryName: 'Denmark',
                flagEmoji: '🇩🇰',
                onTap: () {},
              ),
            ),
          );
          expect(find.text('#$rank · 2026'), findsOneWidget);
          expect(find.text('Noma'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('rank is never rendered in gold', (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideVenueCard(
              title: 'Noma',
              metadataLine: const Text(
                '#1 · 2026',
                style: TextStyle(color: AppColors.forestGreen),
              ),
              cityName: 'Copenhagen',
              onTap: () {},
            ),
          ),
        );
        final metadata = tester.widget<Text>(find.text('#1 · 2026'));
        expect(metadata.style?.color, isNot(AppColors.gold));
      });

      testWidgets('distinction is optional — omitted entirely when there is '
          'nothing to show', (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideVenueCard(
              title: 'Noma',
              cityName: 'Copenhagen',
              countryName: 'Denmark',
              onTap: () {},
            ),
          ),
        );
        expect(find.text('Noma'), findsOneWidget);
        expect(find.byType(StarRow), findsNothing);
        expect(find.byType(KeyRow), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    group('GuideVenueCard with GuideGaultMillauMark', () {
      testWidgets(
        'renders a Gault&Millau distinction as the metadata line, never '
        'gold',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              GuideVenueCard(
                title: 'Comme chez Soi',
                metadataLine: GuideGaultMillauMark(
                  award: const GaultMillauAward(
                    restaurantId: 'r1',
                    guideYear: 2026,
                    score: 18,
                    toqueCount: 4,
                  ),
                ),
                cityName: 'Brussels',
                countryName: 'Belgium',
                flagEmoji: '🇧🇪',
                onTap: () {},
              ),
            ),
          );
          expect(find.text('Comme chez Soi'), findsOneWidget);
          expect(find.text('18/20 · 4 Toques'), findsOneWidget);
          final mark = tester.widget<Text>(find.text('18/20 · 4 Toques'));
          expect(mark.style?.color, AppColors.forestGreen);
          expect(mark.style?.color, isNot(AppColors.gold));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('an unscored distinction label renders truthfully, never a '
          'fabricated score', (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideVenueCard(
              title: 'A Belgian Bistro',
              metadataLine: GuideGaultMillauMark(
                award: const GaultMillauAward(
                  restaurantId: 'r1',
                  guideYear: 2026,
                  recognitionType: GaultMillauRecognitionType.unscoredCasual,
                  distinctionLabel: 'H!P',
                ),
              ),
              cityName: 'Ghent',
              countryName: 'Belgium',
              onTap: () {},
            ),
          ),
        );
        expect(find.text('H!P'), findsOneWidget);
        expect(find.textContaining('/20'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('1.6x text scale does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: SizedBox(
                width: 320,
                child: GuideVenueCard(
                  title: 'Le Bernardin',
                  inlineRecognition: const StarRow(count: 3, size: 12),
                  cityName: 'New York',
                  countryName: 'United States',
                  flagEmoji: '🇺🇸',
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

  group('GuideVenueCardDivider', () {
    testWidgets('renders a hairline', (tester) async {
      await tester.pumpWidget(_wrap(const GuideVenueCardDivider()));
      expect(find.byType(GuideVenueCardDivider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'uses the strengthened, unmistakably-visible taupe token — never '
      'gold, never a heavy/dark rule',
      (tester) async {
        await tester.pumpWidget(_wrap(const GuideVenueCardDivider()));
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxHeight, 0.75);
        expect(container.color, AppColors.taupe.withValues(alpha: 0.55));
        expect(container.color, isNot(AppColors.gold));
        expect(container.color, isNot(AppColors.forestGreen));
      },
    );
  });
}
