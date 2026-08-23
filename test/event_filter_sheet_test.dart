// Events V2 Discovery Taxonomy Phase C Correction Pass §10/§39 — the
// advanced Filters sheet (lib/features/events/widgets/event_filter_sheet.
// dart) now covers ONLY Social/Type/Theme; Location and Date were
// promoted to their own first-class controls (event_location_context.
// dart's CountryFilterControl reuse, event_date_control.dart) and no
// longer live in this sheet at all. The sheet remains fully Supabase-
// free, so the REAL widget is pumped directly here via the real
// showEventFilterSheet entry point, exactly the same showModalBottomSheet
// -from-a-trigger-button pattern already established by
// create_trip_sheet_dismiss_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/widgets/event_filter_sheet.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_discovery_filters.dart';
import 'package:michelin_passport/models/event_tag.dart';

const _tags = [
  EventTag(id: '1', slug: 'wine', name: 'Wine'),
  EventTag(id: '2', slug: 'guest_chef', name: 'Guest Chef'),
  EventTag(id: '3', slug: 'four_hands', name: 'Four Hands'),
];

/// Holds whatever [showEventFilterSheet] eventually resolves to — `null`
/// until the sheet is actually dismissed one way or another.
class _Harness {
  EventFilterSheetResult? result;
  bool resolved = false;
}

Future<_Harness> _open(
  WidgetTester tester, {
  EventDiscoveryFilters? committed,
  bool signedIn = true,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                harness.result = await showEventFilterSheet(
                  context,
                  committed: committed ?? EventDiscoveryFilters.empty,
                  tags: _tags,
                  signedIn: signedIn,
                );
                harness.resolved = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  group('EventFilterSheet — open/close', () {
    testWidgets('opens showing only SOCIAL/TYPE/THEMES — no LOCATION or '
        'DATE group', (tester) async {
      await _open(tester);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('SOCIAL'), findsOneWidget);
      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('THEMES'), findsOneWidget);
      expect(find.text('LOCATION'), findsNothing);
      expect(find.text('DATE'), findsNothing);
    });

    testWidgets('dismissing without Apply (tap outside) returns null — '
        'committed state is untouched by the caller', (tester) async {
      final harness = await _open(
        tester,
        committed: EventDiscoveryFilters(eventTypes: {EventType.dinner}),
      );
      await tester.tap(find.text('Wine'));
      await tester.pump();
      await tester.tapAt(const Offset(50, 60));
      await tester.pumpAndSettle();

      expect(harness.resolved, isTrue);
      expect(harness.result, isNull);
    });

    testWidgets('Apply returns a committed result with no Location/Date '
        'fields', (tester) async {
      final harness = await _open(tester);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(harness.result, isNotNull);
      expect(harness.result!.filters.isEmpty, isTrue);
      expect(harness.result!.filters.countryCodes, isEmpty);
      expect(harness.result!.filters.dateRange.isEmpty, isTrue);
    });
  });

  group('EventFilterSheet — initial state reflects committed filters', () {
    testWidgets('a pre-selected Type, Theme and Social value are all '
        'shown selected on open', (tester) async {
      await _open(
        tester,
        committed: EventDiscoveryFilters(
          social: {EventSocialFilter.following},
          eventTypes: {EventType.dinner},
          tagSlugs: {'wine'},
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('a committed Country/Date (from before this correction, or '
        'set by some other path) has no effect on the sheet — it never '
        'reads those fields', (tester) async {
      await _open(
        tester,
        committed: EventDiscoveryFilters(
          countryCodes: {'NL'},
          dateRange: EventDiscoveryDateRange(from: DateTime.utc(2026, 9, 1)),
          eventTypes: {EventType.dinner},
        ),
      );
      // Only the Type selection shows — Country/Date are invisible here.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Netherlands'), findsNothing);
    });
  });

  group('EventFilterSheet — multi-select', () {
    testWidgets('multiple Social values can be selected simultaneously', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(find.text('Friends Going'));
      await tester.pump();
      await tester.tap(find.text('Following'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('multiple Types can be selected simultaneously', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(find.text('Dinner'));
      await tester.pump();
      await tester.tap(find.text('Lunch'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('multiple Themes can be selected simultaneously', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(find.text('Wine'));
      await tester.pump();
      await tester.tap(find.text('Guest Chef'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('tapping an already-selected option deselects it', (
      tester,
    ) async {
      await _open(tester);
      await tester.tap(find.text('Wine'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text('Wine'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('EventFilterSheet — Apply commits Social/Type/Theme correctly', () {
    testWidgets('Apply with a Theme selected commits exactly that slug, '
        'nothing else', (tester) async {
      final harness = await _open(tester);
      await tester.tap(find.text('Wine'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(harness.result!.filters.tagSlugs, {'wine'});
      expect(harness.result!.filters.eventTypes, isEmpty);
      expect(harness.result!.filters.social, isEmpty);
    });
  });

  group('EventFilterSheet — Clear all', () {
    testWidgets('Clear all resets every group in the draft', (tester) async {
      await _open(
        tester,
        committed: EventDiscoveryFilters(
          eventTypes: {EventType.dinner},
          tagSlugs: {'wine'},
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('Clear all keeps the sheet open — it does not implicitly '
        'Apply', (tester) async {
      await _open(
        tester,
        committed: EventDiscoveryFilters(eventTypes: {EventType.dinner}),
      );
      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(find.text('Filters'), findsOneWidget); // sheet still visible
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('EventFilterSheet — signed-out', () {
    testWidgets('the Social group is hidden entirely when signed out', (
      tester,
    ) async {
      await _open(tester, signedIn: false);
      expect(find.text('SOCIAL'), findsNothing);
      expect(find.text('Friends Going'), findsNothing);
      expect(find.text('TYPE'), findsOneWidget);
    });
  });

  group('EventFilterSheet — responsive', () {
    testWidgets('320px width — no overflow', (tester) async {
      await _open(tester, size: const Size(320, 700));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await _open(tester, textScale: 1.6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px width AND 1.6x text scale together, with values '
        'already selected — no overflow', (tester) async {
      await _open(
        tester,
        size: const Size(320, 700),
        textScale: 1.6,
        committed: EventDiscoveryFilters(
          social: {EventSocialFilter.following},
          eventTypes: {EventType.dinner, EventType.lunch},
          tagSlugs: {'wine', 'guest_chef'},
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('EventFilterSheet — accessibility', () {
    testWidgets('an option exposes selected/unselected semantics', (
      tester,
    ) async {
      await _open(tester);
      final semantics = tester.getSemantics(find.text('Wine'));
      // ignore: deprecated_member_use
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isFalse);
      await tester.tap(find.text('Wine'));
      await tester.pump();
      final selectedSemantics = tester.getSemantics(find.text('Wine'));
      // ignore: deprecated_member_use
      expect(selectedSemantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    });
  });
}
