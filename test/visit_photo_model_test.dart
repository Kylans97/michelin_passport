// Covers VisitPhoto's Events V2 Step 4 widening from visit-only to
// polymorphic (nullable visitId, new attendanceId) — both the new
// attendance-photo parsing path and a regression guard proving existing
// visit-photo JSON (as PostgREST has always sent it, with no
// attendance_id key at all) still parses identically to before.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';
import 'package:michelin_passport/models/visit_photo.dart';

void main() {
  group('VisitPhoto.fromJson — regression: existing visit-photo shape', () {
    test('a real visit-photo row (visit_id set, no attendance_id key at '
        'all — exactly what PostgREST sent before this widening) parses '
        'with attendanceId null', () {
      final photo = VisitPhoto.fromJson({
        'id': 'photo-1',
        'user_id': 'user-1',
        'visit_id': 'visit-1',
        'storage_path': 'user-1/visit-1/abc.jpg',
        'caption': null,
        'taken_at': '2026-06-01T12:00:00+00:00',
        'is_public': true,
      });
      expect(photo.visitId, 'visit-1');
      expect(photo.attendanceId, isNull);
      expect(photo.storagePath, 'user-1/visit-1/abc.jpg');
    });

    test('an explicit JSON null attendance_id also parses to null', () {
      final photo = VisitPhoto.fromJson({
        'id': 'photo-1',
        'user_id': 'user-1',
        'visit_id': 'visit-1',
        'attendance_id': null,
        'storage_path': 'user-1/visit-1/abc.jpg',
        'is_public': true,
      });
      expect(photo.attendanceId, isNull);
    });
  });

  group('VisitPhoto.fromJson — attendance-photo shape', () {
    test('an attendance photo row (attendance_id set, no visit_id) parses '
        'with visitId null', () {
      final photo = VisitPhoto.fromJson({
        'id': 'photo-2',
        'user_id': 'user-1',
        'visit_id': null,
        'attendance_id': 'attendance-1',
        'storage_path': 'user-1/attendance-1/def.jpg',
        'is_public': true,
      });
      expect(photo.visitId, isNull);
      expect(photo.attendanceId, 'attendance-1');
    });

    test('a row with visit_id key entirely absent (not just null) also '
        'parses with visitId null', () {
      final photo = VisitPhoto.fromJson({
        'id': 'photo-2',
        'user_id': 'user-1',
        'attendance_id': 'attendance-1',
        'storage_path': 'user-1/attendance-1/def.jpg',
        'is_public': true,
      });
      expect(photo.visitId, isNull);
    });
  });

  group('EventAttendanceEntry', () {
    Event event() => Event(
      id: 'evt-1',
      name: 'Test Event',
      startAt: DateTime.utc(2026, 9, 20, 18),
      endAt: DateTime.utc(2026, 9, 20, 22),
      timezone: 'Europe/Amsterdam',
      countryCode: 'NL',
      eventType: EventType.dinner,
      status: EventStatus.completed,
      createdAt: DateTime.utc(2026, 1, 1),
    );

    EventConfirmedAttendance attendance() => EventConfirmedAttendance(
      id: 'att-1',
      eventId: 'evt-1',
      userId: 'user-1',
      confirmedAt: DateTime.utc(2026, 9, 21),
      visibility: ConfirmedAttendanceVisibility.private,
      source: EventAttendanceSource.manual,
      createdAt: DateTime.utc(2026, 9, 21),
    );

    test('coverPhotoUrl defaults to null when not supplied', () {
      final entry = EventAttendanceEntry(
        attendance: attendance(),
        event: event(),
      );
      expect(entry.coverPhotoUrl, isNull);
    });

    test('coverPhotoUrl carries the resolved signed URL when supplied', () {
      final entry = EventAttendanceEntry(
        attendance: attendance(),
        event: event(),
        coverPhotoUrl: 'https://example.com/signed.jpg',
      );
      expect(entry.coverPhotoUrl, 'https://example.com/signed.jpg');
    });
  });
}
