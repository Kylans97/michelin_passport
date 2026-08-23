// Events V2 Discovery Taxonomy Phase C Correction Pass §7/§8/§20 — the
// Date control (lib/features/events/widgets/event_date_control.dart):
// its pure label formatter, and the widget's own "commits immediately,
// no Apply step" contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/widgets/event_date_control.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';

void main() {
  group('eventDateControlLabel — pure formatting', () {
    test('none preset -> "Date"', () {
      expect(
        eventDateControlLabel(
          EventDiscoveryDatePreset.none,
          EventDiscoveryDateRange.none,
        ),
        'Date',
      );
    });

    test('today preset -> "Today"', () {
      expect(
        eventDateControlLabel(
          EventDiscoveryDatePreset.today,
          EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 16)),
        ),
        'Today',
      );
    });

    test('thisWeekend preset -> "This weekend"', () {
      expect(
        eventDateControlLabel(
          EventDiscoveryDatePreset.thisWeekend,
          EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 19),
            to: DateTime.utc(2026, 9, 20),
          ),
        ),
        'This weekend',
      );
    });

    test('thisMonth preset -> "This month"', () {
      expect(
        eventDateControlLabel(
          EventDiscoveryDatePreset.thisMonth,
          EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 1),
            to: DateTime.utc(2026, 9, 30),
          ),
        ),
        'This month',
      );
    });

    test('custom range within one month -> compact "D–D Mon"', () {
      expect(
        eventDateControlLabel(
          EventDiscoveryDatePreset.custom,
          EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 23),
            to: DateTime.utc(2026, 9, 25),
          ),
        ),
        '23–25 Sep',
      );
    });

    test('custom range spanning two months -> both month names', () {
      expect(
        eventDateControlLabel(
          EventDiscoveryDatePreset.custom,
          EventDiscoveryDateRange(
            from: DateTime.utc(2026, 9, 28),
            to: DateTime.utc(2026, 10, 3),
          ),
        ),
        '28 Sep – 3 Oct',
      );
    });
  });

  group('EventDateControl — commits immediately, no Apply step', () {
    Future<EventDateSelection?> openAndPick(
      WidgetTester tester,
      String optionLabel,
    ) async {
      EventDateSelection? received;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDateControl(
              preset: EventDiscoveryDatePreset.none,
              range: EventDiscoveryDateRange.none,
              onChanged: (selection) => received = selection,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EventDateControl));
      await tester.pumpAndSettle();
      await tester.tap(find.text(optionLabel));
      await tester.pumpAndSettle();
      return received;
    }

    testWidgets('tapping "Today" immediately closes the sheet and reports '
        'a resolved Today selection — no Apply button exists', (tester) async {
      final selection = await openAndPick(tester, 'Today');
      expect(selection, isNotNull);
      expect(selection!.preset, EventDiscoveryDatePreset.today);
      expect(selection.range.isEmpty, isFalse);
      expect(find.text('Apply'), findsNothing);
    });

    testWidgets('tapping "This month" immediately reports a resolved, '
        'non-empty range', (tester) async {
      final selection = await openAndPick(tester, 'This month');
      expect(selection!.preset, EventDiscoveryDatePreset.thisMonth);
      expect(selection.range.isEmpty, isFalse);
    });

    testWidgets('"Any date" is the sheet\'s own independent-clear option '
        '— resolves to the empty/none selection', (tester) async {
      final selection = await openAndPick(tester, 'Any date');
      expect(selection!.preset, EventDiscoveryDatePreset.none);
      expect(selection.range.isEmpty, isTrue);
    });

    testWidgets('the closed control label reflects the current selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDateControl(
              preset: EventDiscoveryDatePreset.thisWeekend,
              range: EventDiscoveryDateRange(
                from: DateTime.utc(2026, 9, 19),
                to: DateTime.utc(2026, 9, 20),
              ),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('This weekend'), findsOneWidget);
    });
  });
}
