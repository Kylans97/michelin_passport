// Covers GuideYearSelector (Step 2C) — presentation-only, no Supabase
// involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_year_selector.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('GuideYearSelector', () {
    testWidgets('renders the selected year on its trigger', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideYearSelector(
            years: const [2025, 2024, 2023],
            selectedYear: 2025,
            onSelect: (_) {},
          ),
        ),
      );
      expect(find.text('2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening the sheet lists every year, with no "All time" '
        'option', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GuideYearSelector(
            years: const [2025, 2024, 2023],
            selectedYear: 2025,
            onSelect: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      expect(find.text('All time'), findsNothing);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2023'), findsOneWidget);
      // '2025' now appears twice: once on the (still-mounted) trigger
      // behind the sheet, once as the selected row inside the sheet.
      expect(find.text('2025'), findsNWidgets(2));
    });

    testWidgets('picking a year calls onSelect with a non-null int and '
        'closes the sheet', (tester) async {
      int? picked;
      await tester.pumpWidget(
        _wrap(
          GuideYearSelector(
            years: const [2025, 2024, 2023],
            selectedYear: 2025,
            onSelect: (year) => picked = year,
          ),
        ),
      );
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2023'));
      await tester.pumpAndSettle();
      expect(picked, 2023);
      // Sheet closed — the trigger itself still reads "2025" here since
      // this bare widget instance has no parent updating [selectedYear] in
      // response to onSelect (that's the screen's job); the check_rounded
      // icon (only rendered inside the now-dismissed sheet) confirms the
      // sheet itself is gone.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('a single-year list still renders without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          GuideYearSelector(
            years: const [2025],
            selectedYear: 2025,
            onSelect: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
