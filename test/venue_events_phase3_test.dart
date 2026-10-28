// Venue events phase 3 (20261018130000): the draft the form sends, the
// manager's Events list and its groups, the event form's own rules and
// save, the two new review kinds, and notifications that skip a type
// this build doesn't know. Fake repositories over a dummy client only.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/review_repository.dart';
import 'package:michelin_passport/data/repositories/venue_events_repository.dart';
import 'package:michelin_passport/features/profile/venue_event_form_screen.dart';
import 'package:michelin_passport/features/profile/venue_events_screen.dart';
import 'package:michelin_passport/features/review/review_event_screen.dart';
import 'package:michelin_passport/features/review/review_queue_screen.dart';
import 'package:michelin_passport/models/app_notification.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_local_time.dart';
import 'package:michelin_passport/models/event_tag.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/review_item.dart';
import 'package:michelin_passport/models/venue_event.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

final _venue = ManagedRestaurant(
  Restaurant.fromJson({
    'id': 'r1',
    'name': 'Flore',
    'city_name': 'Amsterdam',
    'country_code': 'NL',
    'address': 'Amstel 1',
  }),
);

DateTime _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return DateTime.utc(d.year, d.month, d.day);
}

Event _event(
  String id, {
  String name = 'Four Hands Dinner',
  DateTime? date,
  DateTime? cancelledAt,
  EventLocalTime? startTime,
}) => Event(
  id: id,
  name: name,
  description: 'Two kitchens.',
  startDate: date ?? _day(30),
  endDate: date ?? _day(30),
  startTime: startTime,
  timezone: 'Europe/Amsterdam',
  countryCode: 'NL',
  venueName: 'Flore',
  address: 'Amstel 1',
  city: 'Amsterdam',
  eventType: EventType.dinner,
  cancelledAt: cancelledAt,
  createdAt: DateTime.utc(2026, 1, 1),
);

class _FakeVenueEventsRepo extends VenueEventsRepository {
  _FakeVenueEventsRepo({this.events = const [], this.saveError}) : super(_dummyClient());
  final List<VenueEvent> events;
  final Object? saveError;
  final submitted = <VenueEventDraft>[];
  final updated = <(String, VenueEventDraft)>[];
  final cancelled = <String>[];

  @override
  Future<List<VenueEvent>> loadVenueEvents(ManagedVenue venue) async => events;
  @override
  Future<List<EventTag>> loadTags() async => const [
    EventTag(id: 't1', slug: 'four_hands', name: 'Four Hands'),
    EventTag(id: 't2', slug: 'wine', name: 'Wine'),
  ];
  @override
  Future<List<EventCountry>> loadCountries() async => const [
    EventCountry(code: 'NL', name: 'Netherlands', flag: '', timezones: ['Europe/Amsterdam']),
    EventCountry(
      code: 'ES',
      name: 'Spain',
      flag: '',
      timezones: ['Europe/Madrid', 'Africa/Ceuta', 'Atlantic/Canary'],
    ),
  ];
  @override
  Future<String> submit(ManagedVenue venue, VenueEventDraft draft) async {
    if (saveError != null) throw saveError!;
    submitted.add(draft);
    return 'new-1';
  }

  @override
  Future<void> update(String eventId, VenueEventDraft draft) async {
    if (saveError != null) throw saveError!;
    updated.add((eventId, draft));
  }

  @override
  Future<void> cancel(String eventId) async => cancelled.add(eventId);
}

class _FakeReviewRepo extends ReviewRepository {
  _FakeReviewRepo({this.queue = const [], this.event}) : super(_dummyClient());
  final List<ReviewItem> queue;
  final Event? event;
  final calls = <String>[];

  @override
  Future<List<ReviewItem>> loadQueue() async => queue;
  @override
  Future<Event?> loadEvent(String eventId) async => event;
  @override
  Future<void> approveEvent(ReviewItem item) async => calls.add('approve:${item.eventId}');
  @override
  Future<void> rejectEvent(ReviewItem item, String note) async =>
      calls.add('reject:${item.eventId}:$note');
  @override
  Future<void> markEventEditSeen(ReviewItem item) async => calls.add('seen:${item.itemId}');
}

Map<String, dynamic> _queueRow(String kind, {Map<String, dynamic> extra = const {}}) => {
  'kind': kind,
  'item_id': '$kind-1',
  'venue_type': 'restaurant',
  'venue_id': 'r1',
  'venue_name': 'Flore',
  'venue_city': 'Amsterdam',
  'submitted_by': 'u1',
  'submitter_label': '@manager_one',
  'submitted_at': '2026-10-28T10:00:00Z',
  'event_id': 'e1',
  'event_name': 'Four Hands Dinner',
  'event_start_date': '2026-11-14',
  ...extra,
};

Future<void> _pumpTall(WidgetTester tester, Widget home) async {
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
}

void main() {
  group('VenueEventDraft.toParams', () {
    test('a date-only event sends no times at all, never a filled-in one', () {
      final p = VenueEventDraft(
        name: ' X ',
        description: 'Y',
        eventType: EventType.dinner,
        startDate: DateTime.utc(2026, 11, 14),
        timezone: 'Europe/Amsterdam',
        atVenue: true,
      ).toParams();
      expect(p['p_start_date'], '2026-11-14');
      expect(p['p_start_time'], isNull);
      expect(p['p_end_time'], isNull);
      expect(p['p_end_date'], isNull);
      expect(p['p_name'], 'X');
    });

    test('an end time without a start is never sent', () {
      final p = VenueEventDraft(
        name: 'X',
        description: 'Y',
        eventType: EventType.dinner,
        startDate: DateTime.utc(2026, 11, 14),
        endTime: const EventLocalTime(hour: 23, minute: 0),
        timezone: 'Europe/Amsterdam',
        atVenue: true,
      ).toParams();
      expect(p['p_end_time'], isNull);
    });

    test('held at the venue sends no location: the server copies the venue\'s own', () {
      final p = VenueEventDraft(
        name: 'X',
        description: 'Y',
        eventType: EventType.dinner,
        startDate: DateTime.utc(2026, 11, 14),
        startTime: const EventLocalTime(hour: 19, minute: 30),
        timezone: 'Europe/Amsterdam',
        atVenue: true,
        venueName: 'Typed by hand',
        latitude: 1,
        longitude: 2,
      ).toParams();
      expect(p['p_start_time'], '19:30:00');
      expect(p['p_venue_name'], isNull);
      expect(p['p_latitude'], isNull);
    });
  });

  group('VenueEvent', () {
    test('status follows moderation_status, and cancelled wins', () {
      Map<String, dynamic> row(String m, {String? cancelled}) => {
        'id': 'e1',
        'name': 'X',
        'start_date': '2026-11-14',
        'end_date': '2026-11-14',
        'country_code': 'NL',
        'event_type': 'dinner',
        'created_at': '2026-10-28T10:00:00Z',
        'moderation_status': m,
        'cancelled_at': cancelled,
        'review_note': 'Add the chef.',
      };
      expect(VenueEvent.fromJson(row('submitted')).status, VenueEventStatus.awaitingReview);
      expect(VenueEvent.fromJson(row('rejected')).status, VenueEventStatus.notApproved);
      expect(VenueEvent.fromJson(row('rejected')).reviewNote, 'Add the chef.');
      expect(VenueEvent.fromJson(row('published')).status, VenueEventStatus.live);
      expect(
        VenueEvent.fromJson(row('published', cancelled: '2026-10-29T10:00:00Z')).status,
        VenueEventStatus.cancelled,
      );
    });
  });

  group('VenueEventsScreen', () {
    testWidgets('groups events by status, shows the reviewer\'s note, and a summary', (tester) async {
      final events = [
        VenueEvent(event: _event('a', name: 'Waiting'), status: VenueEventStatus.awaitingReview),
        VenueEvent(
          event: _event('b', name: 'Sent back'),
          status: VenueEventStatus.notApproved,
          reviewNote: 'Add the guest chef.',
        ),
        VenueEvent(event: _event('c', name: 'Live one'), status: VenueEventStatus.live),
        VenueEvent(event: _event('d', name: 'Old one', date: _day(-10)), status: VenueEventStatus.live),
        VenueEvent(
          event: _event('e', name: 'Called off', cancelledAt: DateTime.now()),
          status: VenueEventStatus.cancelled,
        ),
      ];
      await _pumpTall(
        tester,
        VenueEventsScreen(venue: _venue, repository: _FakeVenueEventsRepo(events: events)),
      );
      for (final h in ['AWAITING REVIEW', 'NOT APPROVED', 'LIVE', 'PAST', 'CANCELLED']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(find.text('"Add the guest chef."'), findsOneWidget);
      expect(find.text('Create an event'), findsOneWidget);
      expect(
        VenueEventsScreen.summary(events, DateTime.now()),
        '1 upcoming · 1 awaiting review · 1 not approved',
      );
      expect(VenueEventsScreen.summary(const [], DateTime.now()), 'None upcoming');
    });

    testWidgets('a cancelled or past event can\'t be opened for editing', (tester) async {
      final repo = _FakeVenueEventsRepo(
        events: [
          VenueEvent(event: _event('d', name: 'Old one', date: _day(-10)), status: VenueEventStatus.live),
        ],
      );
      await _pumpTall(tester, VenueEventsScreen(venue: _venue, repository: repo));
      await tester.tap(find.text('Old one'));
      await tester.pumpAndSettle();
      expect(find.byType(VenueEventFormScreen), findsNothing);
    });
  });

  group('VenueEventFormScreen', () {
    testWidgets('a new event needs a name, description, type and date before it is sent', (tester) async {
      final repo = _FakeVenueEventsRepo();
      await _pumpTall(tester, VenueEventFormScreen(venue: _venue, repository: repo));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Give the event a name.'), findsOneWidget);
      expect(repo.submitted, isEmpty);
    });

    testWidgets('a date-only event at the venue is submitted with no times', (tester) async {
      final repo = _FakeVenueEventsRepo();
      await _pumpTall(tester, VenueEventFormScreen(venue: _venue, repository: repo));
      await tester.enterText(find.byType(TextField).at(0), 'Four Hands Dinner');
      await tester.enterText(find.byType(TextField).at(1), 'Two kitchens, one evening.');
      await tester.tap(find.text('Dinner'));
      await tester.tap(find.text('Four Hands'));
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Times are in Europe/Amsterdam.'), findsOneWidget);
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(repo.submitted, hasLength(1));
      final d = repo.submitted.single;
      expect(d.atVenue, isTrue);
      expect(d.startTime, isNull);
      expect(d.endTime, isNull);
      expect(d.timezone, 'Europe/Amsterdam');
      expect(d.tagSlugs, ['four_hands']);
      expect(d.eventType, EventType.dinner);
    });

    testWidgets('a past start, and an end before the start on one day, are refused', (tester) async {
      final repo = _FakeVenueEventsRepo();
      final pastEvent = VenueEvent(
        event: _event('e1', date: _day(5), startTime: const EventLocalTime(hour: 20, minute: 0)),
        status: VenueEventStatus.awaitingReview,
      );
      // "Today" in the event's timezone is ten days later: the event has
      // already ended there.
      await _pumpTall(
        tester,
        VenueEventFormScreen(
          venue: _venue,
          existing: pastEvent,
          repository: repo,
          todayIn: (_) => _day(10),
        ),
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text("The event can't end in the past."), findsOneWidget);
      expect(repo.updated, isEmpty);
    });

    testWidgets('editing a live event says changes go live, and sends the update', (tester) async {
      final repo = _FakeVenueEventsRepo();
      final live = VenueEvent(event: _event('e1'), status: VenueEventStatus.live, tagSlugs: const ['wine']);
      await _pumpTall(tester, VenueEventFormScreen(venue: _venue, existing: live, repository: repo));
      expect(find.text('This event is live: changes go live straight away.'), findsOneWidget);
      // Recognised as held at the venue: its name and address match.
      final atVenue = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(atVenue.value, isTrue);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.updated.single.$1, 'e1');
      expect(repo.updated.single.$2.tagSlugs, ['wine']);
    });

    testWidgets('held elsewhere in a country with several zones, the timezone is asked', (tester) async {
      final repo = _FakeVenueEventsRepo();
      final elsewhere = VenueEvent(
        event: Event(
          id: 'e2',
          name: 'Guest night',
          description: 'X',
          startDate: _day(20),
          endDate: _day(20),
          timezone: 'Europe/Madrid',
          countryCode: 'ES',
          venueName: 'Somewhere',
          city: 'Madrid',
          latitude: 40.4,
          longitude: -3.7,
          eventType: EventType.dinner,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        status: VenueEventStatus.awaitingReview,
      );
      await _pumpTall(tester, VenueEventFormScreen(venue: _venue, existing: elsewhere, repository: repo));
      expect(find.text('Timezone (Spain has several)'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final d = repo.updated.single.$2;
      expect(d.atVenue, isFalse);
      expect(d.countryCode, 'ES');
      expect(d.timezone, 'Europe/Madrid');
      expect(d.latitude, 40.4);
    });

    testWidgets('a refused save shows the server\'s own message', (tester) async {
      final repo = _FakeVenueEventsRepo(
        saveError: const PostgrestException(message: 'Events can be added at most one year ahead.', code: 'P0001'),
      );
      final live = VenueEvent(event: _event('e1'), status: VenueEventStatus.live);
      await _pumpTall(tester, VenueEventFormScreen(venue: _venue, existing: live, repository: repo));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Events can be added at most one year ahead.'), findsOneWidget);
    });

    testWidgets('cancelling asks first, then cancels', (tester) async {
      final repo = _FakeVenueEventsRepo();
      final live = VenueEvent(event: _event('e1'), status: VenueEventStatus.live);
      await _pumpTall(tester, VenueEventFormScreen(venue: _venue, existing: live, repository: repo));
      await tester.tap(find.text('Cancel this event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, isEmpty);
      await tester.tap(find.text('Cancel this event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel event'));
      await tester.pumpAndSettle();
      expect(repo.cancelled, ['e1']);
    });
  });

  group('Review', () {
    test('ReviewItem reads both event kinds, with the changes sorted by field', () {
      final submitted = ReviewItem.fromJson(_queueRow('venue_event'))!;
      expect(submitted.kind, ReviewKind.venueEvent);
      expect(submitted.eventName, 'Four Hands Dinner');
      expect(submitted.eventStartDate, DateTime.utc(2026, 11, 14));
      final edit = ReviewItem.fromJson(
        _queueRow(
          'venue_event_edit',
          extra: {
            'event_changes': {
              'start_time': {'old': null, 'new': '19:00:00'},
              'name': {'old': 'A', 'new': 'B'},
            },
          },
        ),
      )!;
      expect(edit.kind, ReviewKind.venueEventEdit);
      expect([for (final c in edit.eventChanges) c.field], ['name', 'start_time']);
    });

    testWidgets('the queue groups events under their own heading, by event name', (tester) async {
      await _pumpTall(
        tester,
        ReviewQueueScreen(
          repository: _FakeReviewRepo(queue: [ReviewItem.fromJson(_queueRow('venue_event'))!]),
        ),
      );
      expect(find.text('EVENTS · 1'), findsOneWidget);
      expect(find.text('Four Hands Dinner'), findsOneWidget);
    });

    testWidgets('a submitted event shows its details; Approve publishes it', (tester) async {
      final repo = _FakeReviewRepo(event: _event('e1', startTime: const EventLocalTime(hour: 19, minute: 30)));
      await _pumpTall(
        tester,
        ReviewEventScreen(item: ReviewItem.fromJson(_queueRow('venue_event'))!, repository: repo),
      );
      expect(find.text('Two kitchens.'), findsOneWidget);
      expect(find.text('Preview the event page'), findsOneWidget);
      await tester.tap(find.text('Approve and publish'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['approve:e1']);
    });

    testWidgets('a change to a live event shows old and new; unknown reads "not given"', (tester) async {
      final repo = _FakeReviewRepo(event: _event('e1'));
      final item = ReviewItem.fromJson(
        _queueRow(
          'venue_event_edit',
          extra: {
            'event_changes': {
              'start_time': {'old': null, 'new': '19:00:00'},
            },
          },
        ),
      )!;
      await _pumpTall(tester, ReviewEventScreen(item: item, repository: repo));
      expect(find.text('START TIME'), findsOneWidget);
      expect(find.text('not given'), findsOneWidget);
      expect(find.text('19:00'), findsOneWidget);
      await tester.tap(find.text('Mark as seen'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['seen:venue_event_edit-1']);
    });

    testWidgets('taking a live event offline needs a note', (tester) async {
      final repo = _FakeReviewRepo(event: _event('e1'));
      final item = ReviewItem.fromJson(_queueRow('venue_event_edit'))!;
      await _pumpTall(tester, ReviewEventScreen(item: item, repository: repo));
      await tester.tap(find.text('Take offline with a note'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(TextButton, 'Take offline');
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Wrong date.');
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.calls, ['reject:e1:Wrong date.']);
    });
  });

  group('Notifications', () {
    Map<String, dynamic> row(String type) => {
      'id': 'n1',
      'type': type,
      'subject_type': 'event',
      'subject_id': 'e1',
      'is_read': false,
      'created_at': '2026-10-28T10:00:00Z',
      'event_name': 'Four Hands Dinner',
      'event_start_date': '2026-11-14',
      'event_review_note': 'Add the chef.',
      'event_venue_name': 'Flore',
    };

    test('event notifications carry the event', () {
      final n = AppNotification.tryFromRow(row('event_rejected'))!;
      expect(n.type, AppNotificationType.eventRejected);
      expect(n.eventName, 'Four Hands Dinner');
      expect(n.eventReviewNote, 'Add the chef.');
      expect(n.eventVenueName, 'Flore');
      expect(n.eventStartDate, DateTime.utc(2026, 11, 14));
    });

    test('a type this build doesn\'t know is skipped, never a crash', () {
      expect(AppNotification.tryFromRow(row('something_new')), isNull);
      expect(AppNotificationType.tryFromWire('something_new'), isNull);
      expect(AppNotificationType.tryFromWire('event_approved'), AppNotificationType.eventApproved);
    });
  });
}
