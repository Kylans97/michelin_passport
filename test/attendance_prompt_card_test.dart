// Covers AttendancePromptCard (Events V2 Step 4 §6) — the Yes/No/Not now
// "Did you make it?" card used on both Event Detail and the Events
// screen's own top-of-list nudge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/theme/cs_surface_context.dart';
import 'package:michelin_passport/features/events/widgets/attendance_prompt_card.dart';

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
  group('AttendancePromptCard', () {
    testWidgets('renders the event name and all three actions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AttendancePromptCard(
            eventName: 'Club Leroy at Parkheuvel',
            busy: false,
            onYes: () {},
            onNo: () {},
            onNotNow: () {},
          ),
        ),
      );
      expect(find.text('Did you make it?'), findsOneWidget);
      expect(find.text('Club Leroy at Parkheuvel'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('tapping Yes/No/Not now fires the matching callback exactly '
        'once', (tester) async {
      var yes = 0, no = 0, notNow = 0;
      await tester.pumpWidget(
        _wrap(
          AttendancePromptCard(
            eventName: 'Test Event',
            busy: false,
            onYes: () => yes++,
            onNo: () => no++,
            onNotNow: () => notNow++,
          ),
        ),
      );
      await tester.tap(find.text('Yes'));
      await tester.tap(find.text('No'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(yes, 1);
      expect(no, 1);
      expect(notNow, 1);
    });

    testWidgets('while busy, Yes/No/Not now are disabled — no double-tap '
        'writes', (tester) async {
      var yes = 0, no = 0, notNow = 0;
      await tester.pumpWidget(
        _wrap(
          AttendancePromptCard(
            eventName: 'Test Event',
            busy: true,
            onYes: () => yes++,
            onNo: () => no++,
            onNotNow: () => notNow++,
          ),
        ),
      );
      await tester.tap(find.text('No'), warnIfMissed: false);
      await tester.tap(find.text('Not now'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(yes, 0);
      expect(no, 0);
      expect(notNow, 0);
    });

    testWidgets('renders on the dark surface variant with no overflow at '
        '320px', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AttendancePromptCard(
            eventName: "'t Preuvenemint",
            busy: false,
            onYes: () {},
            onNo: () {},
            onNotNow: () {},
            surface: CsSurface.dark,
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long event name wraps/truncates without overflow at '
        '320px', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AttendancePromptCard(
            eventName:
                'An Extraordinarily Long Multi-Word Festival Name That '
                'Keeps Going And Going Across Many Words',
            busy: false,
            onYes: () {},
            onNo: () {},
            onNotNow: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AttendancePromptCard(
            eventName: 'Wildfestival',
            busy: false,
            onYes: () {},
            onNo: () {},
            onNotNow: () {},
          ),
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
