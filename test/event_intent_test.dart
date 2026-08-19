// Covers the Interested/Going pure domain logic (Events V2 Step 3):
// resolveIntentTap (the entire state machine), visibilityForIntent, and
// intentAnalyticsEvents (which AnalyticsEvents a transition fires, and in
// what order). All three are pure top-level functions with no Supabase
// dependency — pumped directly, mirroring canAttendEvent/
// eventMatchesTrip's own established testing pattern in this codebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/analytics/analytics_event.dart';
import 'package:michelin_passport/models/event_attendance.dart';
import 'package:michelin_passport/models/event_intent.dart';

void main() {
  group('resolveIntentTap — the state machine', () {
    test('NONE -> INTERESTED', () {
      expect(
        resolveIntentTap(current: null, tapped: EventIntentStatus.interested),
        EventIntentStatus.interested,
      );
    });

    test('NONE -> GOING', () {
      expect(
        resolveIntentTap(current: null, tapped: EventIntentStatus.going),
        EventIntentStatus.going,
      );
    });

    test('INTERESTED -> GOING', () {
      expect(
        resolveIntentTap(
          current: EventIntentStatus.interested,
          tapped: EventIntentStatus.going,
        ),
        EventIntentStatus.going,
      );
    });

    test('GOING -> INTERESTED', () {
      expect(
        resolveIntentTap(
          current: EventIntentStatus.going,
          tapped: EventIntentStatus.interested,
        ),
        EventIntentStatus.interested,
      );
    });

    test('INTERESTED -> NONE (tapping the already-selected pill removes '
        'it)', () {
      expect(
        resolveIntentTap(
          current: EventIntentStatus.interested,
          tapped: EventIntentStatus.interested,
        ),
        isNull,
      );
    });

    test('GOING -> NONE (tapping the already-selected pill removes it)', () {
      expect(
        resolveIntentTap(
          current: EventIntentStatus.going,
          tapped: EventIntentStatus.going,
        ),
        isNull,
      );
    });

    test('a user can select Going directly from NONE — Interested is '
        'never a mandatory first step', () {
      final result = resolveIntentTap(
        current: null,
        tapped: EventIntentStatus.going,
      );
      expect(result, EventIntentStatus.going);
    });
  });

  group('visibilityForIntent — the approved MVP rule', () {
    test('Interested is always private', () {
      expect(
        visibilityForIntent(EventIntentStatus.interested),
        AttendanceVisibility.private,
      );
    });

    test('Going uses the existing approved friends-visible default', () {
      expect(
        visibilityForIntent(EventIntentStatus.going),
        AttendanceVisibility.friends,
      );
    });
  });

  group('intentAnalyticsEvents — successful-write-first ordering and '
      'switch semantics', () {
    test('NONE -> INTERESTED fires only event_interested_added', () {
      expect(
        intentAnalyticsEvents(
          previous: null,
          next: EventIntentStatus.interested,
        ),
        [AnalyticsEvent.eventInterestedAdded],
      );
    });

    test('NONE -> GOING fires only event_going_added', () {
      expect(
        intentAnalyticsEvents(previous: null, next: EventIntentStatus.going),
        [AnalyticsEvent.eventGoingAdded],
      );
    });

    test('INTERESTED -> GOING fires event_interested_removed THEN '
        'event_going_added — a switch is two echoes for one database write, '
        'per the contract\'s own "or transition away from" wording', () {
      expect(
        intentAnalyticsEvents(
          previous: EventIntentStatus.interested,
          next: EventIntentStatus.going,
        ),
        [AnalyticsEvent.eventInterestedRemoved, AnalyticsEvent.eventGoingAdded],
      );
    });

    test('GOING -> INTERESTED fires event_going_removed THEN '
        'event_interested_added', () {
      expect(
        intentAnalyticsEvents(
          previous: EventIntentStatus.going,
          next: EventIntentStatus.interested,
        ),
        [AnalyticsEvent.eventGoingRemoved, AnalyticsEvent.eventInterestedAdded],
      );
    });

    test('INTERESTED -> NONE fires only event_interested_removed', () {
      expect(
        intentAnalyticsEvents(
          previous: EventIntentStatus.interested,
          next: null,
        ),
        [AnalyticsEvent.eventInterestedRemoved],
      );
    });

    test('GOING -> NONE fires only event_going_removed', () {
      expect(
        intentAnalyticsEvents(previous: EventIntentStatus.going, next: null),
        [AnalyticsEvent.eventGoingRemoved],
      );
    });

    test('no transition (previous == next) fires nothing', () {
      expect(
        intentAnalyticsEvents(
          previous: EventIntentStatus.going,
          next: EventIntentStatus.going,
        ),
        isEmpty,
      );
      expect(intentAnalyticsEvents(previous: null, next: null), isEmpty);
    });
  });
}
