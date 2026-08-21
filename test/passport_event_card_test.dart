// Covers PassportEventCard (Events V2 Step 4 §15) — the confirmed-Event
// history card in Passport's additive Events section.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/cs_image_placeholder.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/features/passport/widgets/passport_event_card.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';

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

Event _event({
  String id = 'evt-1',
  String name = 'Club Leroy at Parkheuvel',
  String? city = 'Rotterdam',
  String? imageUrl,
}) => Event(
  id: id,
  name: name,
  startAt: DateTime.utc(2026, 9, 20, 18),
  endAt: DateTime.utc(2026, 9, 20, 22),
  timezone: 'Europe/Amsterdam',
  countryCode: 'NL',
  city: city,
  imageUrl: imageUrl,
  eventType: EventType.dinner,
  status: EventStatus.completed,
  createdAt: DateTime.utc(2026, 1, 1),
);

EventConfirmedAttendance _attendance({int? rating}) => EventConfirmedAttendance(
  id: 'att-1',
  eventId: 'evt-1',
  userId: 'user-1',
  confirmedAt: DateTime.utc(2026, 9, 21),
  rating: rating,
  visibility: ConfirmedAttendanceVisibility.private,
  source: EventAttendanceSource.manual,
  createdAt: DateTime.utc(2026, 9, 21),
);

void main() {
  group('PassportEventCard', () {
    testWidgets('renders event name, type eyebrow, location and date '
        'range', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(),
            ),
          ),
        ),
      );
      expect(find.text('Club Leroy at Parkheuvel'), findsOneWidget);
      expect(find.text('DINNER'), findsOneWidget);
      expect(find.text('Rotterdam, NL'), findsOneWidget);
      expect(find.textContaining('20 Sep 2026'), findsOneWidget);
    });

    testWidgets('shows the saved rating when present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(rating: 8),
              event: _event(),
            ),
          ),
        ),
      );
      expect(find.text('Your rating: 8/10'), findsOneWidget);
    });

    testWidgets('omits the rating line entirely when unrated', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(),
            ),
          ),
        ),
      );
      expect(find.textContaining('Your rating'), findsNothing);
    });

    testWidgets('tapping the card fires navigation without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('long name/city at 320px — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(rating: 10),
              event: _event(
                name:
                    'An Extraordinarily Long Culinary Festival Name That '
                    'Keeps Going',
                city: 'A Very Long City Name Indeed',
              ),
            ),
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.6x text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(rating: 7),
              event: _event(),
            ),
          ),
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('PassportEventCard — image priority (photos pre-apply report §12)', () {
    testWidgets('attendance photo preferred over the official Event image '
        'when both exist', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(imageUrl: 'https://example.com/event.jpg'),
              coverPhotoUrl: 'https://example.com/attendance-cover.jpg',
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final networkImage = image.image as NetworkImage;
      expect(networkImage.url, 'https://example.com/attendance-cover.jpg');
    });

    testWidgets('falls back to the official Event image when no attendance '
        'photo exists', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(imageUrl: 'https://example.com/event.jpg'),
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final networkImage = image.image as NetworkImage;
      expect(networkImage.url, 'https://example.com/event.jpg');
    });

    testWidgets('falls back to the branded placeholder when neither an '
        'attendance photo nor an official Event image exists', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(),
            ),
          ),
        ),
      );
      expect(find.byType(CsImagePlaceholder), findsOneWidget);
    });

    testWidgets('an empty-string coverPhotoUrl is treated as absent, not '
        'as a broken image URL', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PassportEventCard(
            entry: EventAttendanceEntry(
              attendance: _attendance(),
              event: _event(imageUrl: 'https://example.com/event.jpg'),
              coverPhotoUrl: '',
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      final networkImage = image.image as NetworkImage;
      expect(networkImage.url, 'https://example.com/event.jpg');
    });
  });
}
