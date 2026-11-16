import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/wishlist/widgets/planned_month_sheet.dart';
import 'package:michelin_passport/models/app_notification.dart';
import 'package:michelin_passport/models/booking_window.dart';
import 'package:michelin_passport/models/notification_preferences.dart';
import 'package:michelin_passport/models/opening_hours.dart' show HoursTime;

// The date logic itself (when a month opens, open yet, when the reminder
// is due) lives in SQL and is tested in supabase/tests/
// booking_window_test.sql; the push copy in send-push/index.test.ts.
// These cover what the app does with the answers.

void main() {
  final now = DateTime(2026, 11, 16);

  group('WishlistPlan.statusLine', () {
    WishlistPlan plan({
      String? status,
      String? opensOn,
      String? opensTime,
      bool reminders = true,
    }) => WishlistPlan.fromRow({
      'restaurant_id': 'r1',
      'planned_month': '2027-05-01',
      'opens_on': opensOn,
      'opens_time': opensTime,
      'timezone': opensOn == null ? null : 'Europe/Paris',
      'status': status,
      'reminders_enabled': reminders,
    });

    test('upcoming, with time and city, and the reminder promise', () {
      expect(
        plan(
          status: 'upcoming',
          opensOn: '2027-03-02',
          opensTime: '10:00:00',
        ).statusLine(now),
        'Bookings for May open 2 March 2027 at 10:00 (Paris time). '
        'We’ll remind you the day before.',
      );
    });

    test('upcoming this year leaves the year out', () {
      expect(
        plan(
          status: 'upcoming',
          opensOn: '2026-12-01',
          opensTime: '09:30:00',
        ).statusLine(now),
        startsWith('Bookings for May open 1 December at 09:30 (Paris time).'),
      );
    });

    test('a date without a known time names no time', () {
      expect(
        plan(status: 'upcoming', opensOn: '2027-01-31').statusLine(now),
        'Bookings for May open 31 January 2027. We’ll remind you the day before.',
      );
    });

    test('reminders switched off server-side: no promise', () {
      expect(
        plan(
          status: 'upcoming',
          opensOn: '2027-03-02',
          opensTime: '10:00:00',
          reminders: false,
        ).statusLine(now),
        'Bookings for May open 2 March 2027 at 10:00 (Paris time).',
      );
    });

    test('already open says so instead of reminding', () {
      expect(
        plan(
          status: 'open',
          opensOn: '2026-03-02',
          opensTime: '10:00:00',
        ).statusLine(now),
        'May is open for booking now.',
      );
    });

    test('opens today (date known, time not)', () {
      expect(
        plan(status: 'opens_today', opensOn: '2026-11-16').statusLine(now),
        'Bookings for May open today.',
      );
    });

    test('unknown window: nothing, never a guess', () {
      final p = plan();
      expect(p.statusLine(now), isNull);
      expect(p.monthLabel, 'Going in May 2027');
    });
  });

  group('BookingWindow', () {
    test('rolling round-trips to the RPC shape', () {
      const w = BookingWindow(
        kind: BookingWindowKind.rolling,
        timezone: 'Europe/Paris',
        rollingAmount: 60,
        rollingUnit: 'day',
        releaseTime: HoursTime(10, 0),
        platform: BookingPlatform.sevenrooms,
      );
      expect(w.validationError(), isNull);
      expect(w.toRpcJson(), {
        'kind': 'rolling',
        'timezone': 'Europe/Paris',
        'rolling_amount': 60,
        'rolling_unit': 'day',
        'release_time': '10:00',
        'platform': 'sevenrooms',
        'source_url': null,
      });
      expect(
        w.summary,
        'Bookable 60 days ahead, a new day opens daily at 10:00',
      );
    });

    test('monthly with no fixed time sends a null time', () {
      const w = BookingWindow(
        kind: BookingWindowKind.monthly,
        timezone: 'Europe/Amsterdam',
        releaseDay: 1,
        monthsAhead: 2,
      );
      expect(w.toRpcJson()['release_time'], isNull);
      expect(w.toRpcJson().containsKey('rolling_amount'), isFalse);
      expect(
        w.summary,
        'On the 1st of each month, the month 2 months ahead opens',
      );
    });

    test('seasonal sends its releases', () {
      final w = BookingWindow(
        kind: BookingWindowKind.seasonal,
        timezone: 'Europe/Paris',
        releases: [
          BookingRelease(
            releaseOn: DateTime(2027, 3, 1),
            releaseTime: const HoursTime(10, 0),
            coversFrom: DateTime(2027, 6, 1),
            coversTo: DateTime(2027, 9, 30),
          ),
        ],
      );
      expect(w.validationError(), isNull);
      expect(w.toRpcJson()['releases'], [
        {
          'release_on': '2027-03-01',
          'release_time': '10:00',
          'covers_from': '2027-06-01',
          'covers_to': '2027-09-30',
        },
      ]);
      expect(w.toRpcJson().containsKey('release_time'), isFalse);
    });

    test('validation mirrors the table checks', () {
      expect(
        const BookingWindow(
          kind: BookingWindowKind.rolling,
          timezone: 'Europe/Paris',
          rollingAmount: 25,
          rollingUnit: 'month',
        ).validationError(),
        'Choose between 1 and 24 months.',
      );
      expect(
        const BookingWindow(
          kind: BookingWindowKind.seasonal,
          timezone: 'Europe/Paris',
        ).validationError(),
        'Add at least one release.',
      );
      expect(
        BookingWindow(
          kind: BookingWindowKind.seasonal,
          timezone: 'Europe/Paris',
          releases: [
            BookingRelease(
              releaseOn: DateTime(2027, 7, 1),
              coversFrom: DateTime(2027, 6, 1),
              coversTo: DateTime(2027, 9, 30),
            ),
          ],
        ).validationError(),
        'Bookings must open on or before the first date they cover.',
      );
    });

    test('reads a row with releases', () {
      final w = BookingWindow.fromRow({
        'kind': 'rolling',
        'timezone': 'Asia/Tokyo',
        'rolling_amount': 30,
        'rolling_unit': 'day',
        'release_time': null,
        'platform': 'tock',
        'source_kind': 'research',
        'source_url': 'https://example.test',
        'verified_on': '2026-11-16',
      });
      expect(w.releaseTime, isNull);
      expect(w.platform, BookingPlatform.tock);
      expect(w.sourceKind, 'research');
      expect(w.summary, 'Bookable 30 days ahead, a new day opens daily');
    });
  });

  test('ordinals', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 31].map(ordinal), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
      '31st',
    ]);
  });

  group('booking reminder notification', () {
    Map<String, dynamic> row({String? time = '10:00:00'}) => {
      'id': 'n1',
      'type': 'booking_window_opening',
      'subject_type': 'booking_reminder',
      'subject_id': 'b1',
      'is_read': false,
      'created_at': '2026-12-31T09:05:00Z',
      'booking_restaurant_id': 'r1',
      'booking_restaurant_name': 'Le Pré Catelan',
      'booking_planned_month': '2027-03-01',
      'booking_opens_on': '2027-01-01',
      'booking_opens_time': time,
      'booking_timezone': 'Europe/Paris',
    };

    test('is a known type and reads its columns', () {
      final n = AppNotification.tryFromRow(row())!;
      expect(n.type, AppNotificationType.bookingWindowOpening);
      expect(n.bookingRestaurantId, 'r1');
      expect(
        n.bookingReminderDescription,
        'Bookings for March 2027 at Le Pré Catelan open on 1 January 2027 '
        'at 10:00 (Paris time).',
      );
    });

    test('without a known time names none', () {
      expect(
        AppNotification.fromRow(row(time: null)).bookingReminderDescription,
        'Bookings for March 2027 at Le Pré Catelan open on 1 January 2027.',
      );
    });
  });

  test('booking reminders default on, also for a row from before them', () {
    expect(
      NotificationPreferences.fromRow({
        'push_friend_requests': false,
        'push_followed_venue_events': true,
      }).bookingReminders,
      isTrue,
    );
    expect(
      const NotificationPreferences(bookingReminders: false).toRow(),
      containsPair('push_booking_reminders', false),
    );
  });

  group('PlannedMonthSheet', () {
    Future<PlannedMonthChoice?> open(
      WidgetTester tester, {
      DateTime? initial,
      required Future<void> Function() act,
    }) async {
      // A phone, not the default 800x600 test window.
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      PlannedMonthChoice? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<PlannedMonthChoice>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => PlannedMonthSheet(
                    restaurantName: 'Le Pré Catelan',
                    initial: initial,
                    now: DateTime(2026, 11, 16),
                  ),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      return result;
    }

    testWidgets('choosing a month saves it', (tester) async {
      final result = await open(
        tester,
        act: () async {
          await tester.tap(find.text('2027'));
          await tester.pump();
          await tester.tap(find.text('May'));
          await tester.pump();
          await tester.tap(find.text('Save May 2027'));
        },
      );
      expect(result, isA<PlannedMonthSet>());
      expect((result! as PlannedMonthSet).month, DateTime(2027, 5));
    });

    testWidgets('a year chip is as wide as its label, not the sheet', (
      tester,
    ) async {
      await open(
        tester,
        act: () async {
          final chip = tester.getSize(
            find.ancestor(
              of: find.text('2027'),
              matching: find.byType(InkWell),
            ),
          );
          expect(chip.width, lessThan(200));
          await tester.tap(find.text('Not sure yet'));
        },
      );
    });

    testWidgets('a past month cannot be chosen', (tester) async {
      final result = await open(
        tester,
        act: () async {
          // 2026: October has passed.
          await tester.tap(find.text('Oct'));
          await tester.pump();
          expect(find.text('Choose a month'), findsOneWidget);
          await tester.tap(find.text('Not sure yet'));
        },
      );
      expect(result, isNull);
    });

    testWidgets('"Not sure yet" skips without a choice', (tester) async {
      final result = await open(
        tester,
        act: () => tester.tap(find.text('Not sure yet')),
      );
      expect(result, isNull);
    });

    testWidgets('with a month already set, it can be cleared', (tester) async {
      final result = await open(
        tester,
        initial: DateTime(2027, 3),
        act: () async {
          expect(find.text('Save March 2027'), findsOneWidget);
          await tester.tap(find.text('Clear the month'));
        },
      );
      expect(result, isA<PlannedMonthCleared>());
    });
  });
}
