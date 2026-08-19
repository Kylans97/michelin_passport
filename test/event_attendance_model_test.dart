// Covers EventAttendance/AttendanceVisibility/EventIntentStatus (Social
// Foundation Step 2B, widened by Events V2 Step 1/Step 3).

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/event_attendance.dart';

void main() {
  group('EventIntentStatus.fromDbValue', () {
    test('parses "interested" and "going" correctly', () {
      expect(
        EventIntentStatus.fromDbValue('interested'),
        EventIntentStatus.interested,
      );
      expect(EventIntentStatus.fromDbValue('going'), EventIntentStatus.going);
    });

    test('fails safe to interested for null or unrecognised values', () {
      expect(EventIntentStatus.fromDbValue(null), EventIntentStatus.interested);
      expect(
        EventIntentStatus.fromDbValue('attending'),
        EventIntentStatus.interested,
      );
    });
  });

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
      expect(attendance.status, EventIntentStatus.going);
      expect(attendance.visibility, AttendanceVisibility.friends);
    });

    test('parses an interested row correctly', () {
      final attendance = EventAttendance.fromJson({
        'id': 'a1',
        'event_id': 'e1',
        'user_id': 'u1',
        'status': 'interested',
        'visibility': 'private',
        'created_at': '2026-08-15T12:00:00Z',
      });
      expect(attendance.status, EventIntentStatus.interested);
      expect(attendance.visibility, AttendanceVisibility.private);
    });

    test('defaults status to interested and visibility to private when '
        'missing', () {
      final attendance = EventAttendance.fromJson({
        'id': 'a1',
        'event_id': 'e1',
        'user_id': 'u1',
        'created_at': '2026-08-15T12:00:00Z',
      });
      expect(attendance.status, EventIntentStatus.interested);
      expect(attendance.visibility, AttendanceVisibility.private);
    });
  });
}
