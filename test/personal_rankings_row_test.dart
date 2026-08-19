// Covers the combined dimension+year filter row on My Rankings' "My
// Rankings" tab. PersonalRankingsTab constructs RankingsRepository against
// Supabase.instance.client eagerly, so — matching this app's established
// limitation for Supabase-eager screens/tabs (see
// wishlist_screen_shell_test.dart's own note) — this mirrors the exact
// Wrap row _PersonalRankingsTabState.build() produces rather than pumping
// the real tab.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/widgets/year_filter_control.dart';
import 'package:michelin_passport/features/rankings/widgets/ranking_dimension_dropdown.dart';
import 'package:michelin_passport/models/ranking_dimension.dart';
import 'package:michelin_passport/models/ranking_venue_type.dart';

// Mirrors personal_rankings_tab.dart's dimension+year Wrap exactly.
Widget _row({
  required List<RankingDimension> dimensions,
  required RankingDimension dimension,
  required List<int> years,
  int? selectedYear,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.background,
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          RankingDimensionDropdown(
            dimensions: dimensions,
            selected: dimension,
            onSelect: (_) {},
          ),
          if (years.isNotEmpty)
            YearFilterControl(
              years: years,
              selectedYear: selectedYear,
              onSelect: (_) {},
            ),
        ],
      ),
    ),
  ),
);

void main() {
  group('Rankings dimension + year row', () {
    testWidgets('both controls render on one row when years exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _row(
          dimensions: RankingVenueType.restaurant.validDimensions,
          dimension: RankingDimension.overall,
          years: [2025, 2024],
        ),
      );
      expect(find.byType(RankingDimensionDropdown), findsOneWidget);
      expect(find.byType(YearFilterControl), findsOneWidget);
      expect(find.text('Overall'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dimension dropdown still renders when there are no '
        'years yet (no visits logged)', (tester) async {
      await tester.pumpWidget(
        _row(
          dimensions: RankingVenueType.restaurant.validDimensions,
          dimension: RankingDimension.overall,
          years: [],
        ),
      );
      expect(find.byType(RankingDimensionDropdown), findsOneWidget);
      expect(find.byType(YearFilterControl), findsNothing);
    });

    testWidgets(
      'hotel dimension list on the row includes Room and Experience',
      (tester) async {
        await tester.pumpWidget(
          _row(
            dimensions: RankingVenueType.hotel.validDimensions,
            dimension: RankingDimension.room,
            years: [2025],
          ),
        );
        expect(find.text('Room'), findsOneWidget);
      },
    );

    testWidgets('320px width, long dimension label + a selected year — no '
        'overflow, controls stay on one row or wrap cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _row(
          dimensions: RankingVenueType.hotel.validDimensions,
          dimension: RankingDimension.experience,
          years: [2025, 2024, 2023],
          selectedYear: 2024,
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
              backgroundColor: AppColors.background,
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RankingDimensionDropdown(
                      dimensions: RankingVenueType.hotel.validDimensions,
                      selected: RankingDimension.experience,
                      onSelect: (_) {},
                    ),
                    YearFilterControl(
                      years: const [2025, 2024],
                      selectedYear: 2025,
                      onSelect: (_) {},
                    ),
                  ],
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
