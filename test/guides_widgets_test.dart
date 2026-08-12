// Covers the Guides-specific shared widgets (Step 2A):
// GuideDestinationRow, GuideFamilySection. Presentation-only, no
// Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_destination_row.dart';
import 'package:michelin_passport/features/guides/widgets/guide_family_section.dart';

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
      'renders no divider/hairline under the family title (spacing-only '
      'hierarchy, TRIPS+GUIDES MICRO-POLISH)',
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
        expect(find.byType(Divider), findsNothing);
        // GuideFamilySection itself contributes no Container/DecoratedBox at
        // all — every Container found here belongs to GuideDestinationRow's
        // own InkWell/Padding machinery, none of which paints a border. The
        // stronger, decoration-level assertion below is the one that would
        // actually have caught the original bug (a bordered/colored
        // Container standing in for a hairline).
        for (final element in tester.widgetList<Container>(
          find.byType(Container),
        )) {
          expect(element.decoration, isNull);
        }
        for (final element in tester.widgetList<DecoratedBox>(
          find.byType(DecoratedBox),
        )) {
          final decoration = element.decoration;
          if (decoration is BoxDecoration) {
            expect(decoration.border, isNull);
          }
        }
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
