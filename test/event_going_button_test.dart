// Covers EventGoingButton (Social Foundation Step 2B §11-12). Pure
// presentation, no Supabase dependency — pumped directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/widgets/event_going_button.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: width, child: child),
  ),
);

void main() {
  group('EventGoingButton', () {
    testWidgets('not-going state shows "I\'m going"', (tester) async {
      await tester.pumpWidget(
        _wrap(EventGoingButton(going: false, busy: false, onTap: () {})),
      );
      expect(find.text("I'm going"), findsOneWidget);
      expect(find.text('Going'), findsNothing);
    });

    testWidgets('going state shows "Going" with a distinct icon (not '
        'color-only)', (tester) async {
      await tester.pumpWidget(
        _wrap(EventGoingButton(going: true, busy: false, onTap: () {})),
      );
      expect(find.text('Going'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('tapping while not going fires onTap', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          EventGoingButton(going: false, busy: false, onTap: () => calls++),
        ),
      );
      await tester.tap(find.text("I'm going"));
      expect(calls, 1);
    });

    testWidgets('tapping while going fires onTap (undo, no confirmation '
        'dialog)', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(EventGoingButton(going: true, busy: false, onTap: () => calls++)),
      );
      await tester.tap(find.text('Going'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('busy state disables tap', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(EventGoingButton(going: false, busy: true, onTap: () => calls++)),
      );
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(calls, 0);
    });

    testWidgets('320px width — no overflow, both states', (tester) async {
      for (final going in [false, true]) {
        await tester.pumpWidget(
          _wrap(
            EventGoingButton(going: going, busy: false, onTap: () {}),
            width: 320,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: EventGoingButton(going: true, busy: false, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
