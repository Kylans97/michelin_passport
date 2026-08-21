// Covers RecommendationSelector — Events V2 Step 4.1's "Would you
// recommend this event?" Yes/No control inside AttendanceDetailsSheet.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/widgets/recommendation_selector.dart';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

void main() {
  group('RecommendationSelector — rendering', () {
    testWidgets('shows the question and both choices', (tester) async {
      await tester.pumpWidget(
        _wrap(RecommendationSelector(value: null, onChanged: (_) {})),
      );
      expect(find.text('Would you recommend this event?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('null = neither choice shows the selected check icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RecommendationSelector(value: null, onChanged: (_) {})),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('true renders exactly one selected check icon (on Yes)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RecommendationSelector(value: true, onChanged: (_) {})),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('false renders exactly one selected check icon (on No)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RecommendationSelector(value: false, onChanged: (_) {})),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('RecommendationSelector — interaction', () {
    testWidgets('tapping Yes from null selects true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: null, onChanged: (v) => result = v),
        ),
      );
      await tester.tap(find.text('Yes'));
      expect(result, isTrue);
    });

    testWidgets('tapping No from null selects false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: null, onChanged: (v) => result = v),
        ),
      );
      await tester.tap(find.text('No'));
      expect(result, isFalse);
    });

    testWidgets('tapping No while Yes is selected switches to false — only '
        'one choice is ever selected at a time', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: true, onChanged: (v) => result = v),
        ),
      );
      await tester.tap(find.text('No'));
      expect(result, isFalse);
    });

    testWidgets('tapping Yes while No is selected switches to true', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: false, onChanged: (v) => result = v),
        ),
      );
      await tester.tap(find.text('Yes'));
      expect(result, isTrue);
    });

    testWidgets('tapping the already-selected Yes again clears back to '
        'null', (tester) async {
      bool? result = true;
      var called = false;
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(
            value: true,
            onChanged: (v) {
              result = v;
              called = true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Yes'));
      expect(called, isTrue);
      expect(result, isNull);
    });

    testWidgets('tapping the already-selected No again clears back to '
        'null', (tester) async {
      bool? result = false;
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: false, onChanged: (v) => result = v),
        ),
      );
      await tester.tap(find.text('No'));
      expect(result, isNull);
    });
  });

  group('RecommendationSelector — responsive', () {
    testWidgets('320px width — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: null, onChanged: (_) {}),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RecommendationSelector(value: true, onChanged: (_) {}),
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
