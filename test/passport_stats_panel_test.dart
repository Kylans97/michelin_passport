// Covers PassportStatsPanel (Passport UI Polish V2) — the open, editorial
// stats row: a single globe emblem to the left, three value/label
// columns with thin dividers, no per-metric icon, no bordered/background
// container. Replaces this feature's own previous pass (a bordered panel
// with a tonal icon circle above each metric), which itself already
// departed from the original bare CsMetricStrip row — this is the
// explicit "remove the dashboard-card container, this area should
// breathe" direction from the approved visual reference. A pure,
// standalone widget with no Supabase dependency, so it's pumped directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stats_panel.dart';

List<PassportStat> _stats() => const [
  PassportStat(value: '42', label: 'VISITED'),
  PassportStat(value: '9', label: 'COUNTRIES'),
  PassportStat(value: '61', label: 'STARS'),
];

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  group('PassportStatsPanel', () {
    testWidgets('renders exactly three columns — value + label each', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(PassportStatsPanel(stats: _stats())));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('VISITED'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('COUNTRIES'), findsOneWidget);
      expect(find.text('61'), findsOneWidget);
      expect(find.text('STARS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders exactly one globe emblem to the left of the row', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(PassportStatsPanel(stats: _stats())));
      expect(find.byIcon(Icons.public_outlined), findsOneWidget);
      final globeX = tester.getTopLeft(find.byIcon(Icons.public_outlined)).dx;
      final visitedX = tester.getTopLeft(find.text('42')).dx;
      expect(globeX, lessThan(visitedX), reason: 'globe sits left of Visited');
    });

    testWidgets('renders two dividers between three columns', (tester) async {
      await tester.pumpWidget(_wrap(PassportStatsPanel(stats: _stats())));
      // One divider container per gap between columns (n-1 for n stats).
      final dividers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxWidth == 1)
          .toList();
      expect(dividers.length, 2);
    });

    testWidgets('no per-metric icon — only the single globe emblem exists, '
        'never one icon per column', (tester) async {
      await tester.pumpWidget(_wrap(PassportStatsPanel(stats: _stats())));
      expect(find.byType(Icon), findsOneWidget); // the globe, and only it.
    });

    testWidgets('the panel has no bordered/background container — the old '
        'dashboard-card treatment is gone', (tester) async {
      await tester.pumpWidget(_wrap(PassportStatsPanel(stats: _stats())));
      // The only bordered Containers left are the globe's own circular
      // outline and the thin 1px column dividers — neither is a panel
      // wrapping the whole row. Assert no Container both contains all
      // three metric values AND carries a border/background — i.e. no
      // single enclosing "card" decoration around the row.
      final wrappingPanels = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) {
            final decoration = c.decoration as BoxDecoration?;
            final hasChrome =
                decoration?.border != null || decoration?.color != null;
            final isThinDivider = c.constraints?.maxWidth == 1;
            final isGlobeCircle = decoration?.shape == BoxShape.circle;
            return hasChrome && !isThinDivider && !isGlobeCircle;
          })
          .toList();
      expect(wrappingPanels, isEmpty);
    });

    testWidgets('globe and values are never gold', (tester) async {
      await tester.pumpWidget(_wrap(PassportStatsPanel(stats: _stats())));
      final globeIcon = tester.widget<Icon>(find.byIcon(Icons.public_outlined));
      expect(globeIcon.color, isNot(AppColors.gold));
      for (final value in ['42', '9', '61']) {
        final text = tester.widget<Text>(find.text(value));
        expect(text.style?.color, isNot(AppColors.gold), reason: value);
      }
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('no overflow at ${width.toInt()}px', (tester) async {
        await tester.pumpWidget(
          _wrap(PassportStatsPanel(stats: _stats()), width: width),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow with long values at 320px', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PassportStatsPanel(
            stats: [
              PassportStat(value: '1,284', label: 'VISITED'),
              PassportStat(value: '96', label: 'COUNTRIES'),
              PassportStat(value: '2,310', label: 'STARS'),
            ],
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 1.6x text scale, 320px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 320,
                child: PassportStatsPanel(stats: _stats()),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
