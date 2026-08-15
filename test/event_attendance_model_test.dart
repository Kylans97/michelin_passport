// Covers EventAttendance/AttendanceVisibility (Social Foundation Step 2B).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event_attendance.dart';

void main() {
  group('AttendanceVisibility.fromDbValue', () {
    test('parses "private" and "friends" correctly', () {
      expect(
        AttendanceVisibility.fromDbValue('private'),
        AttendanceVisibility.private,
      );
      expect(
        AttendanceVisibility.fromDbValue('friends'),
        AttendanceVisibility.friends,
      );
    });

    test('fails safe to private for null or unrecognised values', () {
      expect(
        AttendanceVisibility.fromDbValue(null),
        AttendanceVisibility.private,
      );
      expect(
        AttendanceVisibility.fromDbValue('public'),
        AttendanceVisibility.private,
      );
    });
  });

  group('EventAttendance.fromJson', () {
    test('parses a full row correctly', () {
      final attendance = EventAttendance.fromJson({
        'id': 'a1',
        'event_id': 'e1',
        'user_id': 'u1',
        'status': 'going',
        'visibility': 'friends',
        'created_at': '2026-08-15T12:00:00Z',
      });
      expect(attendance.id, 'a1');
      expect(attendance.eventId, 'e1');
      expect(attendance.userId, 'u1');
      expect(attendance.status, 'going');
      expect(attendance.visibility, AttendanceVisibility.friends);
    });

    test('defaults status to going and visibility to private when missing', () {
      final attendance = EventAttendance.fromJson({
        'id': 'a1',
        'event_id': 'e1',
        'user_id': 'u1',
        'created_at': '2026-08-15T12:00:00Z',
      });
      expect(attendance.status, 'going');
      expect(attendance.visibility, AttendanceVisibility.private);
    });
  });
}
