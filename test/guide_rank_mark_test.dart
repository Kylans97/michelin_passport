// Covers GuideRankMark (Step 2C) — presentation-only, no Supabase involved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_rank_mark.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.ivory,
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('GuideRankMark', () {
    for (final rank in [1, 50, 100]) {
      testWidgets('renders #$rank with a leading hash, no leading zero', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(GuideRankMark(rank: rank)));
        expect(find.text('#$rank'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('#1 and #100 render in the same fixed-width column, so a '
        'scrolling list stays aligned', (tester) async {
      await tester.pumpWidget(_wrap(const GuideRankMark(rank: 1)));
      final oneWidth = tester.getSize(find.byType(GuideRankMark)).width;
      await tester.pumpWidget(_wrap(const GuideRankMark(rank: 100)));
      final hundredWidth = tester.getSize(find.byType(GuideRankMark)).width;
      expect(oneWidth, hundredWidth);
    });

    testWidgets('at 320px does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(const GuideRankMark(rank: 100), width: 320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: const SizedBox(width: 320, child: GuideRankMark(rank: 100)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
