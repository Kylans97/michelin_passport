// Covers EventAttendanceSection (Events V2 Step 4) — Event Detail's single
// completed-event attendance widget, switching over AttendanceUiState's
// four values.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event_attendance_eligibility.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';
import 'package:michelin_passport/features/events/widgets/event_attendance_section.dart';

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

EventAttendanceSection _section({
  required AttendanceUiState state,
  EventConfirmedAttendance? attendance,
  bool busy = false,
  VoidCallback? onYes,
  VoidCallback? onNo,
  VoidCallback? onNotNow,
  VoidCallback? onManualAttend,
  VoidCallback? onEdit,
  VoidCallback? onRemove,
}) => EventAttendanceSection(
  state: state,
  attendance: attendance,
  eventName: 'Wildfestival',
  busy: busy,
  onYes: onYes ?? () {},
  onNo: onNo ?? () {},
  onNotNow: onNotNow ?? () {},
  onManualAttend: onManualAttend ?? () {},
  onEdit: onEdit ?? () {},
  onRemove: onRemove ?? () {},
);

EventConfirmedAttendance _attendance({int? rating}) => EventConfirmedAttendance(
  id: 'att-1',
  eventId: 'evt-1',
  userId: 'user-1',
  confirmedAt: DateTime.utc(2026, 9, 2),
  rating: rating,
  visibility: ConfirmedAttendanceVisibility.private,
  source: EventAttendanceSource.postEventPrompt,
  createdAt: DateTime.utc(2026, 9, 2),
);

void main() {
  group('EventAttendanceSection — state rendering', () {
    testWidgets('none renders nothing', (tester) async {
      await tester.pumpWidget(_wrap(_section(state: AttendanceUiState.none)));
      expect(find.text('Did you make it?'), findsNothing);
      expect(find.text('Add to Passport'), findsNothing);
      expect(find.text('In your Passport'), findsNothing);
    });

    testWidgets('promptable renders the Yes/No/Not now prompt', (tester) async {
      await tester.pumpWidget(
        _wrap(_section(state: AttendanceUiState.promptable)),
      );
      expect(find.text('Did you make it?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('manualOnly renders the plain "Add to Passport" CTA, not '
        'a Yes/No prompt', (tester) async {
      await tester.pumpWidget(
        _wrap(_section(state: AttendanceUiState.manualOnly)),
      );
      expect(find.text('Add to Passport'), findsOneWidget);
      expect(find.text('Did you make it?'), findsNothing);
    });

    testWidgets('attended renders "In your Passport" with no rating shown '
        'when null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _section(
            state: AttendanceUiState.attended,
            attendance: _attendance(),
          ),
        ),
      );
      expect(find.text('In your Passport'), findsOneWidget);
      expect(find.textContaining('Your rating'), findsNothing);
    });

    testWidgets('attended shows the saved rating when present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _section(
            state: AttendanceUiState.attended,
            attendance: _attendance(rating: 9),
          ),
        ),
      );
      expect(find.text('Your rating: 9/10'), findsOneWidget);
    });
  });

  group('EventAttendanceSection — interaction', () {
    testWidgets('manualOnly CTA fires onManualAttend', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          _section(
            state: AttendanceUiState.manualOnly,
            onManualAttend: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Add to Passport'));
      expect(taps, 1);
    });

    testWidgets('attended overflow menu reads "Edit your experience" — '
        'Step 4.1\'s renamed management CTA — and fires onEdit when '
        'tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          _section(
            state: AttendanceUiState.attended,
            attendance: _attendance(),
            onEdit: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Edit your experience'), findsOneWidget);
      expect(find.text('Edit rating, photos & notes'), findsNothing);
      await tester.tap(find.text('Edit your experience'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('EventAttendanceSection — responsive', () {
    testWidgets('promptable at 320px, no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(_section(state: AttendanceUiState.promptable), width: 320),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('attended with rating at 1.6x text scale, no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _section(
            state: AttendanceUiState.attended,
            attendance: _attendance(rating: 10),
          ),
          textScale: 1.6,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('manualOnly at 320px, no overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(_section(state: AttendanceUiState.manualOnly), width: 320),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
