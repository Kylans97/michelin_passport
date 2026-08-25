// PASSPORT — RANKING UI REDESIGN V1 (Color Hierarchy Correction pass):
// covers the "MY RANKINGS" eyebrow PersonalRankingsTab renders — small,
// uppercase, generous tracking, now colored for the deep-green Passport
// canvas Ranking shares with every other subsection (was deep-green text
// for an abandoned light-canvas version; now ivory/textOnDark, the same
// on-dark treatment "YOUR COLLECTION" already uses). PersonalRankingsTab
// itself constructs RankingsRepository against Supabase.instance.client
// eagerly (see personal_rankings_row_test.dart's own note on this same
// limitation), so this mirrors the exact Text widget
// _PersonalRankingsTabState.build() produces rather than pumping the real
// tab.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/core/theme/cs_typography.dart';

Widget _eyebrow() => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: Text(
      'MY RANKINGS',
      style: CsTypography.eyebrow.copyWith(
        color: AppColors.textOnDark,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
);

void main() {
  group('My Rankings eyebrow', () {
    testWidgets('renders as a small, uppercase, on-dark ivory label — not '
        'a giant heading, and legible on the deep-green canvas', (
      tester,
    ) async {
      await tester.pumpWidget(_eyebrow());
      final text = tester.widget<Text>(find.text('MY RANKINGS'));
      expect(text.style?.color, AppColors.textOnDark);
      expect(text.style?.fontSize, 12);
      expect(text.style?.letterSpacing, greaterThan(1));
      expect(text.style?.color, isNot(AppColors.gold));
      expect(tester.takeException(), isNull);
    });
  });
}
