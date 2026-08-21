// Events V2 Step 5 §9/§10/§12/§25 — covers the Event map preview sheet
// (lib/features/map/widgets/event_map_preview_sheet.dart): content,
// deepGreen "View event" CTA (no gold), no Interested/Going controls (this
// is a historical-attendance surface, not an intent surface), and
// responsiveness.
//
// Does not exercise the CTA's actual navigation into EventDetailScreen:
// EventDetailScreen is Supabase-eager (constructs
// EventRepository/EventAttendanceRepository/EventConfirmedAttendanceRepository
// against Supabase.instance.client in initState), which throws in this
// sandbox without a live Supabase.initialize() call — the same established
// limitation venue_preview_sheet's own "View restaurant" test already
// accepts (it verifies label/color, never taps through to
// RestaurantDetailScreen either). See docs/Architecture's Step 5 report for
// the full reasoning and the physical-device gate this defers to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/features/map/models/map_pin.dart';
import 'package:michelin_passport/features/map/widgets/event_map_preview_sheet.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';

Event _event({
  String name = 'Wildfestival',
  String? venueName = 'Vrijthof',
  String? city = 'Maastricht',
  String? imageUrl,
}) => Event(
  id: 'evt-1',
  name: name,
  startAt: DateTime.utc(2026, 6, 1, 18),
  endAt: DateTime.utc(2026, 6, 1, 23),
  countryCode: 'NL',
  city: city,
  venueName: venueName,
  latitude: 50.85,
  longitude: 5.69,
  imageUrl: imageUrl,
  eventType: EventType.festival,
  status: EventStatus.completed,
  createdAt: DateTime.utc(2026, 1, 1),
);

EventMapPin _pin({Event? event, int? rating}) {
  final e = event ?? _event();
  return EventMapPin(
    entry: EventAttendanceEntry(
      attendance: EventConfirmedAttendance(
        id: 'att-1',
        eventId: e.id,
        userId: 'u1',
        confirmedAt: DateTime.utc(2026, 6, 2),
        rating: rating,
        visibility: ConfirmedAttendanceVisibility.private,
        source: EventAttendanceSource.manual,
        createdAt: DateTime.utc(2026, 6, 2),
      ),
      event: e,
    ),
    latitude: e.latitude!,
    longitude: e.longitude!,
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  EventMapPin pin, {
  double width = 390,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEventMapPreviewSheet(context, pin),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Event map preview sheet — content', () {
    testWidgets('shows title, subtitle (venue + city) and date range', (
      tester,
    ) async {
      await _openSheet(tester, _pin());
      expect(find.text('Wildfestival'), findsOneWidget);
      expect(find.text('Vrijthof, Maastricht'), findsOneWidget);
      expect(find.textContaining('2026'), findsWidgets);
    });

    testWidgets('shows the attendance rating when present', (tester) async {
      await _openSheet(tester, _pin(rating: 4));
      expect(find.text('4/5'), findsOneWidget);
    });

    testWidgets('omits the rating row entirely when no rating was given', (
      tester,
    ) async {
      await _openSheet(tester, _pin(rating: null));
      expect(find.textContaining('/5'), findsNothing);
    });

    testWidgets('no image block when imageUrl is absent — never crashes', (
      tester,
    ) async {
      await _openSheet(tester, _pin());
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('Event map preview sheet — CTA', () {
    testWidgets('"View event" renders as a deepGreen FilledButton, never '
        'gold', (tester) async {
      await _openSheet(tester, _pin());
      expect(find.text('View event'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style!.backgroundColor!.resolve({});
      expect(bg, AppColors.deepGreen);
      expect(bg, isNot(AppColors.gold));
    });

    testWidgets('§9/§12 no Interested/Going controls anywhere on the sheet '
        '— historical attendance only, no intent surface', (tester) async {
      await _openSheet(tester, _pin());
      expect(find.textContaining('Interested'), findsNothing);
      expect(find.textContaining('Going'), findsNothing);
    });

    testWidgets('gold audit: no gold color anywhere on the sheet', (
      tester,
    ) async {
      await _openSheet(tester, _pin(rating: 5));
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });
  });

  group('Event map preview sheet — §25 responsive', () {
    testWidgets('320px width — no overflow', (tester) async {
      await _openSheet(tester, _pin(rating: 5), width: 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await _openSheet(tester, _pin(rating: 5), textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  });
}
