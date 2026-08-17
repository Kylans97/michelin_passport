// Covers the Guides-specific shared widgets (Step 2A):
// GuideDestinationRow, GuideFamilySection. Presentation-only, no
// Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/features/guides/widgets/guide_destination_row.dart';
import 'package:michelin_passport/features/guides/widgets/guide_family_section.dart';
import 'package:michelin_passport/features/guides/widgets/guide_venue_card.dart';

// Step 1A: both widgets now live on GuidesScreen's deep-green canvas
// (Green Token Consistency Migration: AppColors.deepGreen, not
// forestGreen) — GuideFamilySection paints its own ivory block on top
// of it.
Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('GuideDestinationRow', () {
    testWidgets('renders label and descriptor', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: 'Restaurants',
            descriptor: "The world's most celebrated tables.",
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text("The world's most celebrated tables."), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole row is tappable, not just the arrow', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: 'Hotels',
            descriptor: 'A descriptor.',
            onTap: () => tapped = true,
          ),
        ),
      );
      // Tap the label text itself, not the trailing icon.
      await tester.tap(find.text('Hotels'));
      expect(tapped, isTrue);
    });

    testWidgets('exposes button semantics with a navigation hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: 'Restaurants',
            descriptor: 'A descriptor.',
            onTap: () {},
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(GuideDestinationRow));
      expect(semantics.hint, contains('Opens'));
    });

    testWidgets('uses a plain arrow, not the app\'s settings-row chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(label: 'Hotels', descriptor: 'x', onTap: () {}),
        ),
      );
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('long descriptor at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: 'Restaurants',
            descriptor:
                'A deliberately long descriptor used to confirm this row '
                'never causes a RenderFlex overflow at a narrow width, even '
                'when the supporting copy runs long.',
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
                child: GuideDestinationRow(
                  label: 'Restaurants',
                  descriptor: "The world's most celebrated tables.",
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

  group('GuideFamilySection', () {
    testWidgets('renders the family title and every destination', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideFamilySection(
            title: 'MICHELIN GUIDE',
            destinations: [
              GuideDestinationRow(
                label: 'Restaurants',
                descriptor: 'x',
                onTap: () {},
              ),
              GuideDestinationRow(
                label: 'Hotels',
                descriptor: 'y',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('MICHELIN GUIDE'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders as an ivory editorial block — no border, no shadow, only a '
      'modest corner radius (Step 1A: forest-green canvas + ivory blocks)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideFamilySection(
              title: 'MICHELIN GUIDE',
              destinations: [
                GuideDestinationRow(
                  label: 'Restaurants',
                  descriptor: 'x',
                  onTap: () {},
                ),
                GuideDestinationRow(
                  label: 'Hotels',
                  descriptor: 'y',
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, AppColors.ivory);
        expect(decoration.border, isNull);
        expect(decoration.boxShadow, anyOf(isNull, isEmpty));
        expect(decoration.borderRadius, BorderRadius.circular(CsRadius.medium));
      },
    );

    testWidgets(
      'shows exactly one internal hairline between two destinations, never '
      'gold and never a thick forest-green rule (Step 1A)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideFamilySection(
              title: 'MICHELIN GUIDE',
              destinations: [
                GuideDestinationRow(
                  label: 'Restaurants',
                  descriptor: 'x',
                  onTap: () {},
                ),
                GuideDestinationRow(
                  label: 'Hotels',
                  descriptor: 'y',
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
        expect(find.byType(GuideVenueCardDivider), findsOneWidget);
      },
    );

    testWidgets('a single-destination family (Gault&Millau) shows no internal '
        'hairline — nothing to separate', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideFamilySection(
            title: 'GAULT&MILLAU',
            destinations: [
              GuideDestinationRow(
                label: 'Restaurants',
                descriptor: 'x',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(GuideVenueCardDivider), findsNothing);
    });

    testWidgets(
      'the family title reads larger than each destination label and stays '
      'forest-green (Step 1A hierarchy: masthead > navigation label)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            GuideFamilySection(
              title: 'MICHELIN GUIDE',
              destinations: [
                GuideDestinationRow(
                  label: 'Restaurants',
                  descriptor: 'x',
                  onTap: () {},
                ),
                GuideDestinationRow(
                  label: 'Hotels',
                  descriptor: 'y',
                  onTap: () {},
                ),
              ],
            ),
          ),
        );
        final titleText = tester.widget<Text>(find.text('MICHELIN GUIDE'));
        final labelText = tester.widget<Text>(find.text('Restaurants'));
        expect(
          titleText.style!.fontSize,
          greaterThan(labelText.style!.fontSize!),
        );
        expect(titleText.style!.color, AppColors.forestGreen);
        expect(titleText.style!.color, isNot(AppColors.gold));
      },
    );

    testWidgets('long family title ("THE WORLD\'S 50 BEST") at 320px does '
        'not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideFamilySection(
            title: "THE WORLD'S 50 BEST",
            destinations: [
              GuideDestinationRow(
                label: 'Restaurants',
                descriptor: 'The restaurants shaping global dining.',
                onTap: () {},
              ),
              GuideDestinationRow(
                label: 'Hotels',
                descriptor: "The world's most remarkable stays.",
                onTap: () {},
              ),
            ],
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
