// Covers Events V2 Step 4's model layer: EventConfirmedAttendance parsing,
// EventAttendanceSource/ConfirmedAttendanceVisibility fail-safe defaults
// (§13 "Attendance defaults private" regression guard), the DB-layer ->
// analytics-layer source translation, and AttendancePromptDismissal's
// session-only dismissal mechanism (§5). Also covers Step 4.1's
// `wouldRecommend` parsing and its recommendationAnalyticsEvent decision
// function.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_event.dart';
import 'package:michelin_passport/core/analytics/analytics_properties.dart';
import 'package:michelin_passport/features/events/attendance_prompt_dismissal.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';
import 'package:michelin_passport/models/event_confirmed_attendance_analytics.dart';

void main() {
  group('EventAttendanceSource.fromDbValue', () {
    test('parses every legal CHECK-constraint value', () {
      expect(
        EventAttendanceSource.fromDbValue('manual'),
        EventAttendanceSource.manual,
      );
      expect(
        EventAttendanceSource.fromDbValue('post_event_prompt'),
        EventAttendanceSource.postEventPrompt,
      );
      expect(
        EventAttendanceSource.fromDbValue('trip_completion'),
        EventAttendanceSource.tripCompletion,
      );
    });

    test('fails safe to manual for null/unrecognized input', () {
      expect(
        EventAttendanceSource.fromDbValue(null),
        EventAttendanceSource.manual,
      );
      expect(
        EventAttendanceSource.fromDbValue('bogus'),
        EventAttendanceSource.manual,
      );
    });
  });

  group('ConfirmedAttendanceVisibility.fromDbValue — §13 privacy default', () {
    test('parses both legal values', () {
      expect(
        ConfirmedAttendanceVisibility.fromDbValue('private'),
        ConfirmedAttendanceVisibility.private,
      );
      expect(
        ConfirmedAttendanceVisibility.fromDbValue('friends'),
        ConfirmedAttendanceVisibility.friends,
      );
    });

    test('fails safe to private (the more restrictive option) for '
        'null/unrecognized input — a Dart-layer regression guard for the '
        "database's own conservative default", () {
      expect(
        ConfirmedAttendanceVisibility.fromDbValue(null),
        ConfirmedAttendanceVisibility.private,
      );
      expect(
        ConfirmedAttendanceVisibility.fromDbValue('bogus'),
        ConfirmedAttendanceVisibility.private,
      );
    });
  });

  group('EventConfirmedAttendance.fromJson', () {
    Map<String, dynamic> baseJson() => {
      'id': 'att-1',
      'event_id': 'evt-1',
      'user_id': 'user-1',
      'confirmed_at': '2026-09-02T10:00:00+00:00',
      'rating': null,
      'comment': null,
      'visibility': 'private',
      'source': 'post_event_prompt',
      'created_at': '2026-09-02T10:00:00+00:00',
    };

    test('parses a full row with rating and comment', () {
      final json = baseJson()
        ..['rating'] = 8
        ..['comment'] = 'Loved the pairing menu.';
      final attendance = EventConfirmedAttendance.fromJson(json);
      expect(attendance.id, 'att-1');
      expect(attendance.eventId, 'evt-1');
      expect(attendance.userId, 'user-1');
      expect(attendance.rating, 8);
      expect(attendance.comment, 'Loved the pairing menu.');
      expect(attendance.visibility, ConfirmedAttendanceVisibility.private);
      expect(attendance.source, EventAttendanceSource.postEventPrompt);
    });

    test('parses a bare confirmation with no rating/comment — §10/§12 '
        '"never required"', () {
      final attendance = EventConfirmedAttendance.fromJson(baseJson());
      expect(attendance.rating, isNull);
      expect(attendance.comment, isNull);
    });

    test('a manual-source row parses correctly', () {
      final attendance = EventConfirmedAttendance.fromJson(
        baseJson()..['source'] = 'manual',
      );
      expect(attendance.source, EventAttendanceSource.manual);
    });
  });

  group('EventConfirmedAttendance.fromJson — Step 4.1 wouldRecommend', () {
    Map<String, dynamic> baseJson() => {
      'id': 'att-1',
      'event_id': 'evt-1',
      'user_id': 'user-1',
      'confirmed_at': '2026-09-02T10:00:00+00:00',
      'rating': null,
      'comment': null,
      'visibility': 'private',
      'source': 'post_event_prompt',
      'created_at': '2026-09-02T10:00:00+00:00',
    };

    test('true parses as true', () {
      final json = baseJson()..['would_recommend'] = true;
      expect(EventConfirmedAttendance.fromJson(json).wouldRecommend, isTrue);
    });

    test('false parses as false — never coerced to null', () {
      final json = baseJson()..['would_recommend'] = false;
      expect(EventConfirmedAttendance.fromJson(json).wouldRecommend, isFalse);
    });

    test('an explicit JSON null parses as null', () {
      final json = baseJson()..['would_recommend'] = null;
      expect(EventConfirmedAttendance.fromJson(json).wouldRecommend, isNull);
    });

    test('a missing key (pre-migration row) parses as null, never false', () {
      final json = baseJson()..remove('would_recommend');
      expect(json.containsKey('would_recommend'), isFalse);
      expect(EventConfirmedAttendance.fromJson(json).wouldRecommend, isNull);
    });
  });

  group('recommendationAnalyticsEvent — Step 4.1 analytics decision', () {
    test('first Yes answer (previous null, next true) fires added', () {
      expect(
        recommendationAnalyticsEvent(previous: null, next: true),
        AnalyticsEvent.eventRecommendationAdded,
      );
    });

    test('first No answer (previous null, next false) fires added — No is '
        'still a definite answer, not "no event"', () {
      expect(
        recommendationAnalyticsEvent(previous: null, next: false),
        AnalyticsEvent.eventRecommendationAdded,
      );
    });

    test('Yes -> No fires added again — same event, no separate "updated" '
        'event, mirroring event_rating_added', () {
      expect(
        recommendationAnalyticsEvent(previous: true, next: false),
        AnalyticsEvent.eventRecommendationAdded,
      );
    });

    test('No -> Yes fires added again', () {
      expect(
        recommendationAnalyticsEvent(previous: false, next: true),
        AnalyticsEvent.eventRecommendationAdded,
      );
    });

    test('clearing an existing Yes back to null fires removed', () {
      expect(
        recommendationAnalyticsEvent(previous: true, next: null),
        AnalyticsEvent.eventRecommendationRemoved,
      );
    });

    test('clearing an existing No back to null fires removed', () {
      expect(
        recommendationAnalyticsEvent(previous: false, next: null),
        AnalyticsEvent.eventRecommendationRemoved,
      );
    });

    test('null -> null fires nothing — never a fake "removed" for an '
        'answer that was never given', () {
      expect(recommendationAnalyticsEvent(previous: null, next: null), isNull);
    });
  });

  group('attendanceSourceForAnalytics — DB-layer to analytics-layer '
      'translation (§22)', () {
    test('every EventAttendanceSource maps to its mirrored '
        'AttendanceSource', () {
      expect(
        attendanceSourceForAnalytics(EventAttendanceSource.manual),
        AttendanceSource.manual,
      );
      expect(
        attendanceSourceForAnalytics(EventAttendanceSource.postEventPrompt),
        AttendanceSource.postEventPrompt,
      );
      expect(
        attendanceSourceForAnalytics(EventAttendanceSource.tripCompletion),
        AttendanceSource.tripCompletion,
      );
    });

    test('the wire names stay in lockstep with the DB CHECK vocabulary', () {
      for (final source in EventAttendanceSource.values) {
        expect(attendanceSourceForAnalytics(source).wireName, source.dbValue);
      }
    });
  });

  group('AttendancePromptDismissal — §5 session-only "Not now"', () {
    test('an event is not dismissed until explicitly dismissed', () {
      expect(
        AttendancePromptDismissal.isDismissed('evt-never-touched'),
        isFalse,
      );
    });

    test('dismiss() marks exactly that event id as dismissed, no others', () {
      AttendancePromptDismissal.dismiss('evt-dismiss-me');
      expect(AttendancePromptDismissal.isDismissed('evt-dismiss-me'), isTrue);
      expect(
        AttendancePromptDismissal.isDismissed('evt-untouched-sibling'),
        isFalse,
      );
    });
  });
}
