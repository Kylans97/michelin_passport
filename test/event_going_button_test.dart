// Covers EventGoingButton (Social Foundation Step 2B §11-12; reskinned in
// Events UI Consistency Step 1). Pure presentation, no Supabase
// dependency — pumped directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/events/widgets/event_going_button.dart';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SizedBox(width: width, child: child),
        ),
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
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
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
      await tester.tap(find.text("I'm going"), warnIfMissed: false);
      expect(calls, 0);
    });

    testWidgets('is a compact, intrinsically-sized pill — not a full-width '
        'booking button', (tester) async {
      // Wrapped in a left-aligned Column, matching how it actually sits in
      // Event Detail's own content column — a SizedBox(width:) parent (as
      // _wrap uses elsewhere in this file) would impose a tight width and
      // defeat the very thing this test checks.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventGoingButton(going: false, busy: false, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(EventGoingButton));
      expect(
        size.width,
        lessThan(200),
        reason:
            'attendance is a restrained personal-intent marker, not a '
            'SizedBox(width: double.infinity) booking CTA',
      );
    });

    testWidgets('never uses gold in either state — color rule reserves '
        'gold for Michelin stars/Keys only', (tester) async {
      for (final going in [false, true]) {
        await tester.pumpWidget(
          _wrap(EventGoingButton(going: going, busy: false, onTap: () {})),
        );
        final icon = tester.widget<Icon>(
          find.byIcon(
            going
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
          ),
        );
        expect(icon.color, isNot(AppColors.gold));
        expect(icon.color, isNot(AppColors.goldLight));
      }
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
        _wrap(
          EventGoingButton(going: true, busy: false, onTap: () {}),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
