// Covers the UI Consistency pass on the shared Log Visit / Plan Visit
// building blocks: SaveButton, RatingMeter, DateCard — each moved from a
// gold accent to deepGreen/forestGreen (the app's primary-action/accent
// colors), with no change to their interaction shape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/visits/widgets/date_card.dart';
import 'package:michelin_passport/features/visits/widgets/rating_meter.dart';
import 'package:michelin_passport/features/visits/widgets/save_button.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.card, body: child),
);

void main() {
  group('SaveButton', () {
    testWidgets('renders the given label', (tester) async {
      await tester.pumpWidget(
        _wrap(SaveButton(saving: false, label: 'Save visit', onTap: () {})),
      );
      expect(find.text('Save visit'), findsOneWidget);
    });

    testWidgets('is deep green, not gold — the new primary-action color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(SaveButton(saving: false, label: 'Save plan', onTap: () {})),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style!.backgroundColor!.resolve({});
      expect(bg, AppColors.deepGreen);
      expect(bg, isNot(AppColors.gold));
    });

    testWidgets('saving shows a spinner instead of the label, tap disabled', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SaveButton(
            saving: true,
            label: 'Save visit',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save visit'), findsNothing);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('not saving fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SaveButton(
            saving: false,
            label: 'Save visit',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      expect(tapped, isTrue);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.card,
              body: SaveButton(
                saving: false,
                label: 'Save changes',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('RatingMeter', () {
    testWidgets('renders label and "Not rated" when value is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RatingMeter(label: 'Overall', value: null, onChanged: (_) {})),
      );
      expect(find.text('Overall'), findsOneWidget);
      expect(find.text('Not rated'), findsOneWidget);
    });

    testWidgets('shows "N/10" in forestGreen when rated, not gold', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RatingMeter(label: 'Room', value: 8, onChanged: (_) {})),
      );
      expect(find.text('8/10'), findsOneWidget);
      final text = tester.widget<Text>(find.text('8/10'));
      expect(text.style?.color, AppColors.forestGreen);
      expect(text.style?.color, isNot(AppColors.gold));
    });

    testWidgets('tapping a segment reports its value', (tester) async {
      int? reported;
      await tester.pumpWidget(
        _wrap(
          RatingMeter(
            label: 'Experience',
            value: null,
            onChanged: (v) => reported = v,
          ),
        ),
      );
      // Tap the last (10th) segment — GestureDetectors, found via the
      // rightmost tappable area of the meter row.
      final gestures = find.byType(GestureDetector);
      await tester.tap(gestures.last);
      expect(reported, 10);
    });

    testWidgets('the "Not rated" pill clears the value', (tester) async {
      int? reported = 5;
      await tester.pumpWidget(
        _wrap(
          RatingMeter(label: 'Value', value: 5, onChanged: (v) => reported = v),
        ),
      );
      await tester.tap(find.text('—'));
      expect(reported, isNull);
    });
  });

  group('DateCard', () {
    testWidgets('renders label and formatted date, forestGreen icon badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DateCard(
            label: 'VISIT DATE',
            date: DateTime(2025, 6, 1),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('VISIT DATE'), findsOneWidget);
      expect(find.text('Jun 1, 2025'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.calendar_today_rounded),
      );
      expect(icon.color, AppColors.forestGreen);
      expect(icon.color, isNot(AppColors.gold));
    });

    testWidgets('tapping fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          DateCard(
            label: 'CHECK-IN',
            date: DateTime(2025, 6, 1),
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(DateCard));
      expect(tapped, isTrue);
    });
  });
}
