// Pure-logic tests for formatGaultMillauDistinction plus widget tests for
// GuideGaultMillauMark (lib/features/guides/widgets/guide_gault_millau_mark.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/guides/widgets/guide_gault_millau_mark.dart';
import 'package:michelin_passport/models/gault_millau_award.dart';

GaultMillauAward _award({
  double? score,
  int? toqueCount,
  String? toqueColour,
  GaultMillauRecognitionType recognitionType =
      GaultMillauRecognitionType.scored,
  String? distinctionLabel,
}) => GaultMillauAward(
  restaurantId: 'r1',
  guideYear: 2026,
  score: score,
  toqueCount: toqueCount,
  toqueColour: toqueColour,
  recognitionType: recognitionType,
  distinctionLabel: distinctionLabel,
);

void main() {
  group('formatGaultMillauDistinction', () {
    test('a whole-number score renders without a trailing decimal', () {
      expect(formatGaultMillauDistinction(_award(score: 18)), '18/20');
    });

    test('a half-point score renders its decimal', () {
      expect(formatGaultMillauDistinction(_award(score: 17.5)), '17.5/20');
    });

    test('score and toque count combine on one line', () {
      expect(
        formatGaultMillauDistinction(_award(score: 18, toqueCount: 4)),
        '18/20 · 4 Toques',
      );
    });

    test('a single toque uses the singular "Toque"', () {
      expect(
        formatGaultMillauDistinction(_award(score: 15, toqueCount: 1)),
        '15/20 · 1 Toque',
      );
    });

    test('a red toque colour is called out explicitly', () {
      expect(
        formatGaultMillauDistinction(_award(toqueCount: 5, toqueColour: 'red')),
        '5 Toques (Red)',
      );
    });

    test('a black toque colour adds no suffix (the unmarked default)', () {
      expect(
        formatGaultMillauDistinction(
          _award(toqueCount: 5, toqueColour: 'black'),
        ),
        '5 Toques',
      );
    });

    test('toque count alone (no score) renders without a slash', () {
      expect(formatGaultMillauDistinction(_award(toqueCount: 4)), '4 Toques');
    });

    test('an unscored top-tier award shows its label verbatim, never a '
        'fabricated score', () {
      expect(
        formatGaultMillauDistinction(
          _award(
            recognitionType: GaultMillauRecognitionType.unscoredTopTier,
            distinctionLabel: "Toques d'Or",
          ),
        ),
        "Toques d'Or",
      );
    });

    test('an unscored casual award shows its label verbatim', () {
      expect(
        formatGaultMillauDistinction(
          _award(
            recognitionType: GaultMillauRecognitionType.unscoredCasual,
            distinctionLabel: 'H!P',
          ),
        ),
        'H!P',
      );
    });

    test('an unscored tier with no label yet still falls through to null '
        'rather than crashing', () {
      expect(
        formatGaultMillauDistinction(
          _award(recognitionType: GaultMillauRecognitionType.unscoredTopTier),
        ),
        isNull,
      );
    });

    test('a scored award with neither score nor toque falls back to its '
        'label if present', () {
      expect(
        formatGaultMillauDistinction(_award(distinctionLabel: 'Special')),
        'Special',
      );
    });

    test('an entirely empty award formats to null, never a fake string', () {
      expect(formatGaultMillauDistinction(_award()), isNull);
    });
  });

  group('GuideGaultMillauMark', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(backgroundColor: AppColors.ivory, body: child),
    );

    testWidgets('renders a scored award', (tester) async {
      await tester.pumpWidget(
        wrap(GuideGaultMillauMark(award: _award(score: 18, toqueCount: 4))),
      );
      expect(find.text('18/20 · 4 Toques'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a toque-only award (no score)', (tester) async {
      await tester.pumpWidget(
        wrap(GuideGaultMillauMark(award: _award(toqueCount: 5))),
      );
      expect(find.text('5 Toques'), findsOneWidget);
    });

    testWidgets('renders an unscored distinction label', (tester) async {
      await tester.pumpWidget(
        wrap(
          GuideGaultMillauMark(
            award: _award(
              recognitionType: GaultMillauRecognitionType.unscoredCasual,
              distinctionLabel: 'H!P',
            ),
          ),
        ),
      );
      expect(find.text('H!P'), findsOneWidget);
    });

    testWidgets('renders nothing (no crash) when there is truly no '
        'distinction to show', (tester) async {
      await tester.pumpWidget(wrap(GuideGaultMillauMark(award: _award())));
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long combined score+toque+colour string does not '
        'overflow at 320px or 390px', (tester) async {
      for (final width in [320.0, 390.0]) {
        await tester.binding.setSurfaceSize(Size(width, 844));
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 200,
              child: GuideGaultMillauMark(
                award: _award(score: 19.5, toqueCount: 5, toqueColour: 'red'),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale does not overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.ivory,
              body: SizedBox(
                width: 200,
                child: GuideGaultMillauMark(
                  award: _award(score: 19.5, toqueCount: 5, toqueColour: 'red'),
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
