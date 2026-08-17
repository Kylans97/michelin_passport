// Covers the "Private Chefs" entry ExploreScreen adds in Private Chefs
// Step 2 — GuideDestinationRow itself is already fully covered by
// guides_widgets_test.dart and explore_guides_entry_test.dart already
// covers "Browse the Guides" in isolation, so this file: (a) exercises the
// exact copy/surface used for the new Private Chefs row, mirroring
// explore_guides_entry_test.dart's own established pattern, and (b)
// confirms both rows render together without interfering with each other
// — the explicit "Browse Guides still works" regression check.
//
// ExploreScreen constructs repositories against Supabase.instance.client
// eagerly in initState, so it can't be pumped directly — same established
// limitation as every other Supabase-eager screen in this app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_spacing.dart';
import 'package:michelin_passport/core/theme/cs_surface_context.dart';
import 'package:michelin_passport/features/guides/widgets/guide_destination_row.dart';

const _guidesLabel = 'Browse the Guides';
const _guidesDescriptor = "Michelin, World's 50 Best & Gault&Millau.";
const _chefsLabel = 'Private Chefs';
const _chefsDescriptor = 'Exceptional chefs, selected for private dining.';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

// Mirrors the real Column of the two GuideDestinationRows exactly as
// composed in explore_screen.dart's _discoverySlivers().
Widget _discoveryEntryRows({
  required VoidCallback onGuides,
  required VoidCallback onChefs,
}) => Column(
  children: [
    GuideDestinationRow(
      label: _guidesLabel,
      descriptor: _guidesDescriptor,
      onTap: onGuides,
      surface: CsSurface.dark,
    ),
    GuideDestinationRow(
      label: _chefsLabel,
      descriptor: _chefsDescriptor,
      onTap: onChefs,
      surface: CsSurface.dark,
    ),
  ],
);

void main() {
  group('Explore "Private Chefs" entry', () {
    testWidgets('renders the exact label and descriptor', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: _chefsLabel,
            descriptor: _chefsDescriptor,
            onTap: () => tapped = true,
            surface: CsSurface.dark,
          ),
        ),
      );
      expect(find.text(_chefsLabel), findsOneWidget);
      expect(find.text(_chefsDescriptor), findsOneWidget);
      await tester.tap(find.text(_chefsLabel));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on the deepGreen canvas the label is ivory, never gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideDestinationRow(
            label: _chefsLabel,
            descriptor: _chefsDescriptor,
            onTap: () {},
            surface: CsSurface.dark,
          ),
        ),
      );
      final label = tester.widget<Text>(find.text(_chefsLabel));
      expect(label.style?.color, AppColors.ivory);
      expect(label.style?.color, isNot(AppColors.gold));
    });

    testWidgets(
      'both rows render together — "Browse the Guides" is unaffected by '
      'the new "Private Chefs" row existing alongside it',
      (tester) async {
        var guidesTapped = false;
        var chefsTapped = false;
        await tester.pumpWidget(
          _wrap(
            _discoveryEntryRows(
              onGuides: () => guidesTapped = true,
              onChefs: () => chefsTapped = true,
            ),
          ),
        );
        expect(find.text(_guidesLabel), findsOneWidget);
        expect(find.text(_guidesDescriptor), findsOneWidget);
        expect(find.text(_chefsLabel), findsOneWidget);
        expect(find.text(_chefsDescriptor), findsOneWidget);

        await tester.tap(find.text(_guidesLabel));
        expect(guidesTapped, isTrue);
        expect(chefsTapped, isFalse);

        await tester.tap(find.text(_chefsLabel));
        expect(chefsTapped, isTrue);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Private Chefs row sits below Browse the Guides, not '
        'above it', (tester) async {
      await tester.pumpWidget(
        _wrap(_discoveryEntryRows(onGuides: () {}, onChefs: () {})),
      );
      final guidesY = tester.getTopLeft(find.text(_guidesLabel)).dy;
      final chefsY = tester.getTopLeft(find.text(_chefsLabel)).dy;
      expect(guidesY, lessThan(chefsY));
    });

    testWidgets('320px and 390px widths — no overflow with both rows '
        'present', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          _wrap(_discoveryEntryRows(onGuides: () {}, onChefs: () {})),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow with both rows present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: _discoveryEntryRows(onGuides: () {}, onChefs: () {}),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('CsSpacing.pageHorizontal padding wrapper does not clip '
        'either row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CsSpacing.pageHorizontal,
            ),
            child: _discoveryEntryRows(onGuides: () {}, onChefs: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
