// Events V2 Time Precision Phase B — Event Detail Hierarchy UX correction,
// plus the Editorial Hero + Essentials/Actions polish pass.
// Covers EventActionsRow (lib/features/events/widgets/event_actions_row.dart)
// — the Tickets/Official website action area moved up from the former
// LOCATION section, then refined from a pair of loose "Label →" text links
// into deliberate full-width action rows: every conditional URL-combination
// state, the identical-URL dedup case (Vergeet Mij Niet Gala's own real
// production shape), Tickets-first priority (now top-to-bottom, not
// left-to-right), the restrained hairline between rows, semantics, and
// responsive behavior.

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
        'first (stronger priority, now expressed top-to-bottom since each '
        'action is its own full-width row)', (tester) async {
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
      expect(find.text('Official website'), findsOneWidget);
      final ticketsY = tester.getTopLeft(find.text('Tickets')).dy;
      final websiteY = tester.getTopLeft(find.text('Official website')).dy;
      expect(ticketsY, lessThan(websiteY));
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
      expect(find.text('Official website'), findsNothing);
    });

    testWidgets('official URL only: only Official website renders', (
      tester,
    ) async {
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
      expect(find.text('Official website'), findsOneWidget);
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
      expect(find.text('Official website'), findsNothing);
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
      expect(find.text('Official website'), findsNothing);
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
        '(Tickets), never two visually-duplicated rows to the same '
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
      expect(find.text('Official website'), findsNothing);
    });
  });

  group('EventActionsRow — full-width rows + separator', () {
    testWidgets('each action row spans the full available width, not a '
        'loose inline text link', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: null,
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
          width: 390,
        ),
      );
      final sizedBox = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .firstWhere((box) => box.width == double.infinity);
      expect(sizedBox.width, double.infinity);
      // A comfortable, consistent tap target — not a tight inline link.
      expect(sizedBox.height, greaterThanOrEqualTo(44));
    });

    testWidgets('a restrained hairline separates the two rows when both '
        'exist', (tester) async {
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
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('no separator renders for a single action', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EventActionsRow(
            ticketUrl: 'https://tickets.example/e1',
            officialUrl: null,
            ticketLabel: 'Tickets',
            eventName: 'Test Event',
            onTapUrl: (_) {},
          ),
        ),
      );
      expect(find.byType(Divider), findsNothing);
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

    testWidgets('tapping Official website calls onTapUrl with the '
        'official URL', (tester) async {
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
      await tester.tap(find.text('Official website'));
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

    testWidgets('Official website carries a descriptive "Official website '
        'for {event name}" semantic label', (tester) async {
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

    testWidgets('never renders a filled CTA block — background stays '
        'transparent, no ColoredBox/Container decoration behind either '
        'row', (tester) async {
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
      // Scoped to Materials inside EventActionsRow itself — the ancestor
      // Scaffold also creates its own (non-transparent) Material, which
      // is irrelevant to this widget's own background.
      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(EventActionsRow),
          matching: find.byType(Material),
        ),
      );
      expect(materials, isNotEmpty);
      for (final material in materials) {
        expect(material.color, Colors.transparent);
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
