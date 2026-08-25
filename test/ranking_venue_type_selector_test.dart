// PASSPORT — RANKING UI REDESIGN V1 (Color Hierarchy Correction pass):
// covers the restyled RankingVenueTypeSelector — ivory fill + deep-green
// label when selected, transparent/dark fill + subtle outline + ivory
// label when not, now that this selector lives on Ranking's deep-green
// Passport canvas rather than a light one. No gold either way. Same
// RankingVenueType state/callback as before; only the visuals are under
// test here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/rankings/widgets/ranking_venue_type_selector.dart';
import 'package:michelin_passport/models/ranking_venue_type.dart';

Widget _wrap(RankingVenueType selected, ValueChanged<RankingVenueType> onSelect) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.deepGreen,
        body: RankingVenueTypeSelector(selected: selected, onSelect: onSelect),
      ),
    );

void main() {
  group('RankingVenueTypeSelector', () {
    testWidgets('renders both segment labels', (tester) async {
      await tester.pumpWidget(_wrap(RankingVenueType.restaurant, (_) {}));
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Hotels'), findsOneWidget);
    });

    testWidgets('the selected segment is ivory filled with a deep-green '
        'label; the unselected segment is transparent/dark with an ivory '
        'label', (tester) async {
      await tester.pumpWidget(_wrap(RankingVenueType.restaurant, (_) {}));

      final selectedContainer = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final selectedDecoration = selectedContainer.decoration as BoxDecoration;
      expect(selectedDecoration.color, AppColors.ivory);
      expect(
        tester.widget<Text>(find.text('Restaurants')).style?.color,
        AppColors.deepGreen,
      );

      final unselectedContainer = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .last;
      final unselectedDecoration =
          unselectedContainer.decoration as BoxDecoration;
      expect(unselectedDecoration.color, Colors.transparent);
      expect(
        tester.widget<Text>(find.text('Hotels')).style?.color,
        AppColors.textOnDark,
      );
    });

    testWidgets('no gold appears anywhere in either state', (tester) async {
      await tester.pumpWidget(_wrap(RankingVenueType.hotel, (_) {}));
      for (final label in ['Restaurants', 'Hotels']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.color, isNot(AppColors.gold));
      }
      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      for (final c in containers) {
        final decoration = c.decoration as BoxDecoration;
        expect(decoration.color, isNot(AppColors.gold));
      }
    });

    testWidgets('tapping the unselected segment reports the tapped type', (
      tester,
    ) async {
      RankingVenueType? selected;
      await tester.pumpWidget(
        _wrap(RankingVenueType.restaurant, (t) => selected = t),
      );
      await tester.tap(find.text('Hotels'));
      expect(selected, RankingVenueType.hotel);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.background,
              body: SizedBox(
                width: width,
                child: RankingVenueTypeSelector(
                  selected: RankingVenueType.restaurant,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
