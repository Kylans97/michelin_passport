// Events V2 Time Precision Phase B — Event Detail Hierarchy UX correction.
// Covers EventActionsRow (lib/features/events/widgets/event_actions_row.dart)
// — the Tickets/Official website action area moved up from the former
// LOCATION section: every conditional URL-combination state, the
// identical-URL dedup case (Vergeet Mij Niet Gala's own real production
// shape), Tickets-first priority, semantics, and responsive behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/events/widgets/event_actions_row.dart';

Widget _wrap(Widget child, {double width = 390, double textScale = 1.0}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('EventActionsRow — conditional rendering', () {
    testWidgets('ticket URL + official URL: both actions render, Tickets '
        'first (stronger priority via reading order)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/preuvenemint',
            officialUrl: 'https://preuvenemint.nl/en',
            ticketLabel: 'Tickets',
            eventName: "'t Preuvenemint",
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      final ticketsX = tester.getTopLeft(find.text('Tickets')).dx;
      final websiteX = tester.getTopLeft(find.text('Website')).dx;
      expect(ticketsX, lessThan(websiteX));
    });

    testWidgets('ticket URL only: only Tickets renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/preuvenemint',
            officialUrl: null,
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Website'), findsNothing);
    });

    testWidgets('official URL only: only Website renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: null,
            officialUrl: 'https://example.com',
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(find.text('Tickets'), findsNothing);
      expect(find.text('Website'), findsOneWidget);
    });

    testWidgets('neither URL: renders nothing at all — no empty action '
        'area, no empty Row', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EventActionsRow(
            ticketUrl: null,
            officialUrl: null,
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: _noop,
          ),
        ),
      );
      expect(find.text('Tickets'), findsNothing);
      expect(find.text('Website'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget); // SizedBox.shrink()
    });

    testWidgets('empty-string URLs are treated the same as null (no '
        'action rendered)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EventActionsRow(
            ticketUrl: '',
            officialUrl: '',
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: _noop,
          ),
        ),
      );
      expect(find.text('Tickets'), findsNothing);
      expect(find.text('Website'), findsNothing);
    });

    testWidgets('the admission-aware "Optional ticket" label is honored '
        'as-is — this widget never overrides the caller-supplied label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/mixed',
            officialUrl: null,
            ticketLabel: 'Optional ticket',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(find.text('Optional ticket'), findsOneWidget);
      expect(find.text('Tickets'), findsNothing);
    });

    testWidgets("identical ticket and official URLs — Vergeet Mij Niet "
        "Gala's own real production shape — render only ONE action "
        '(Tickets), never two visually-duplicated links to the same '
        'destination', (tester) async {
      const sameUrl = 'https://www.vergeetmijnietgala.nl';
      await tester.pumpWidget(
        _wrap(
          const EventActionsRow(
            ticketUrl: sameUrl,
            officialUrl: sameUrl,
            ticketLabel: 'Tickets',
            eventName: 'Vergeet Mij Niet Gala',
            onTapUrl: _noop,
          ),
        ),
      );
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Website'), findsNothing);
    });
  });

  group('EventActionsRow — tap behavior', () {
    testWidgets('tapping Tickets calls onTapUrl with the ticket URL', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: 'https://example.com/e1',
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (url) => tapped = url,
          ),
        ),
      );
      await tester.tap(find.text('Tickets'));
      expect(tapped, 'https://tickets.example/e1');
    });

    testWidgets('tapping Website calls onTapUrl with the official URL', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: 'https://example.com/e1',
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (url) => tapped = url,
          ),
        ),
      );
      await tester.tap(find.text('Website'));
      expect(tapped, 'https://example.com/e1');
    });
  });

  group('EventActionsRow — accessibility', () {
    testWidgets('Tickets carries a descriptive "{label} for {event name}" '
        'semantic label, not just the bare visible text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: null,
            ticketLabel: 'Tickets',
            eventName: "'t Preuvenemint",
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel("Tickets for 't Preuvenemint"),
        findsOneWidget,
      );
    });

    testWidgets('Website carries a descriptive "Official website for '
        '{event name}" semantic label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: null,
            officialUrl: 'https://example.com',
            ticketLabel: 'Tickets',
            eventName: "'t Preuvenemint",
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel("Official website for 't Preuvenemint"),
        findsOneWidget,
      );
    });
  });

  group('EventActionsRow — visual regression', () {
    testWidgets('never renders gold anywhere', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: 'https://example.com/e1',
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width with both actions and a long event name — no '
        'overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: 'https://example.com/e1',
            ticketLabel: 'Optional ticket',
            eventName:
                'An Exceptionally Long Curated Gastronomic Festival '
                'Name That Really Tests The Layout',
            onTapUrl: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale with both actions — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: 'https://example.com/e1',
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
          width: 320,
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop(String _) {}
