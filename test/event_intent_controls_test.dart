// Covers EventIntentControls (Events V2 Step 3) — the Interested/Going
// pair that replaces EventGoingButton (Social Foundation Step 2B; see
// event_intent_test.dart for the pure state-machine coverage that used to
// live implicitly inside that widget's own tap handler). Pure
// presentation, no Supabase dependency — pumped directly.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/events/widgets/event_intent_controls.dart';
import 'package:michelin_passport/models/event_attendance.dart';

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
  group('EventIntentControls', () {
    testWidgets('NONE — neither pill selected', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: null,
            busy: false,
            pendingTarget: null,
            onTap: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('INTERESTED — Interested selected, Going unselected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.interested,
            busy: false,
            pendingTarget: null,
            onTap: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('GOING — Going selected, Interested unselected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.going,
            busy: false,
            pendingTarget: null,
            onTap: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('tapping Interested fires onTap(interested) regardless of '
        'current state', (tester) async {
      final taps = <EventIntentStatus>[];
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: null,
            busy: false,
            pendingTarget: null,
            onTap: taps.add,
          ),
        ),
      );
      await tester.tap(find.text('Interested'));
      expect(taps, [EventIntentStatus.interested]);
    });

    testWidgets('tapping Going fires onTap(going)', (tester) async {
      final taps = <EventIntentStatus>[];
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.interested,
            busy: false,
            pendingTarget: null,
            onTap: taps.add,
          ),
        ),
      );
      await tester.tap(find.text('Going'));
      expect(taps, [EventIntentStatus.going]);
    });

    testWidgets('tapping the already-selected pill still fires onTap with '
        'that same status — removal is resolved by the caller, not this '
        'widget', (tester) async {
      final taps = <EventIntentStatus>[];
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.going,
            busy: false,
            pendingTarget: null,
            onTap: taps.add,
          ),
        ),
      );
      await tester.tap(find.text('Going'));
      expect(taps, [EventIntentStatus.going]);
    });

    testWidgets('busy disables both pills, regardless of pendingTarget', (
      tester,
    ) async {
      final taps = <EventIntentStatus>[];
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.interested,
            busy: true,
            pendingTarget: EventIntentStatus.going,
            onTap: taps.add,
          ),
        ),
      );
      await tester.tap(find.text('Interested'), warnIfMissed: false);
      await tester.tap(find.text('Going'), warnIfMissed: false);
      expect(taps, isEmpty);
    });

    testWidgets('while busy with a pendingTarget, only the pending pill '
        'shows selected + a spinner; the other shows unselected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.interested,
            busy: true,
            pendingTarget: EventIntentStatus.going,
            onTap: (_) {},
          ),
        ),
      );
      // Going is the pending target: spinner shown, no static icon for it.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
      // Interested (the previous, non-pending status) shows unselected —
      // never still shown as selected mid-mutation.
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    });

    testWidgets('while busy with pendingTarget null (a removal in '
        'flight), neither pill shows selected or a spinner', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.going,
            busy: true,
            pendingTarget: null,
            onTap: (_) {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('accessibility: selected pill exposes Semantics.selected '
        'and a remove hint; unselected pill does not', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.going,
            busy: false,
            pendingTarget: null,
            onTap: (_) {},
          ),
        ),
      );
      final goingSemantics = tester.getSemantics(
        find
            .ancestor(of: find.text('Going'), matching: find.byType(Semantics))
            .first,
      );
      // ignore: deprecated_member_use
      expect(goingSemantics.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(goingSemantics.label, contains('Tap to remove'));

      final interestedSemantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Interested'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      // ignore: deprecated_member_use
      expect(interestedSemantics.hasFlag(SemanticsFlag.isSelected), isFalse);
      expect(interestedSemantics.label, isNot(contains('Tap to remove')));
    });

    testWidgets('never uses gold in any state — color rule reserves gold '
        'for Michelin stars/Keys only', (tester) async {
      for (final status in [
        null,
        EventIntentStatus.interested,
        EventIntentStatus.going,
      ]) {
        await tester.pumpWidget(
          _wrap(
            EventIntentControls(
              status: status,
              busy: false,
              pendingTarget: null,
              onTap: (_) {},
            ),
          ),
        );
        for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
          expect(icon.color, isNot(AppColors.gold));
          expect(icon.color, isNot(AppColors.goldLight));
        }
      }
    });

    testWidgets('both pills stay compact, intrinsically sized — never a '
        'full-width booking CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventIntentControls(
                    status: null,
                    busy: false,
                    pendingTarget: null,
                    onTap: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(EventIntentControls));
      expect(
        size.width,
        lessThan(300),
        reason:
            'intent is a restrained personal marker, not a '
            'SizedBox(width: double.infinity) booking CTA',
      );
    });

    testWidgets('320px width — no overflow, every state', (tester) async {
      for (final status in [
        null,
        EventIntentStatus.interested,
        EventIntentStatus.going,
      ]) {
        await tester.pumpWidget(
          _wrap(
            EventIntentControls(
              status: status,
              busy: false,
              pendingTarget: null,
              onTap: (_) {},
            ),
            width: 320,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventIntentControls(
            status: EventIntentStatus.going,
            busy: false,
            pendingTarget: null,
            onTap: (_) {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
