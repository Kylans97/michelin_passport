// Covers GuideCatalogueLoading/GuideCatalogueEmptyState/
// GuideCatalogueErrorState (Step 2B) and GuideResultCountLine (Step 2C) —
// presentation-only, no Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_catalogue_states.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('GuideCatalogueLoading', () {
    testWidgets('shows a restrained CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(const GuideCatalogueLoading()));
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 1.5);
      expect(tester.takeException(), isNull);
    });
  });

  group('GuideCatalogueEmptyState', () {
    testWidgets('active-filters variant suggests adjusting search/filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const GuideCatalogueEmptyState(hasActiveFilters: true)),
      );
      expect(find.text('No places found'), findsOneWidget);
      expect(
        find.text('Try adjusting your search or filters.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no-active-filters variant uses different, non-blaming '
        'copy', (tester) async {
      await tester.pumpWidget(
        _wrap(const GuideCatalogueEmptyState(hasActiveFilters: false)),
      );
      expect(find.text('No places found'), findsOneWidget);
      expect(find.text('Try adjusting your search or filters.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('GuideCatalogueErrorState', () {
    testWidgets('shows restrained copy and a working retry button', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(GuideCatalogueErrorState(onRetry: () => retried = true)),
      );
      expect(find.text('Unable to load places'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('never surfaces a raw error string', (tester) async {
      await tester.pumpWidget(_wrap(GuideCatalogueErrorState(onRetry: () {})));
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('Postgrest'), findsNothing);
      expect(find.textContaining('Supabase'), findsNothing);
    });
  });

  group('GuideResultCountLine', () {
    testWidgets('singular count reads "1 place"', (tester) async {
      await tester.pumpWidget(
        _wrap(const GuideResultCountLine(count: 1, loading: false)),
      );
      expect(find.text('1 place'), findsOneWidget);
    });

    testWidgets('plural count reads "N places", never shouting the '
        'catalogue name', (tester) async {
      await tester.pumpWidget(
        _wrap(const GuideResultCountLine(count: 50, loading: false)),
      );
      expect(find.text('50 places'), findsOneWidget);
      expect(find.textContaining("WORLD'S 50 BEST"), findsNothing);
    });

    testWidgets('shows an inline spinner only while loading', (tester) async {
      await tester.pumpWidget(
        _wrap(const GuideResultCountLine(count: 50, loading: false)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(
        _wrap(const GuideResultCountLine(count: 50, loading: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
