import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/venue_opening_hours_section.dart';
import 'package:michelin_passport/data/repositories/opening_hours_repository.dart';
import 'package:michelin_passport/features/profile/venue_opening_hours_screen.dart';
import 'package:michelin_passport/models/opening_hours.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

HoursRange r(String opens, String closes) =>
    HoursRange(HoursTime.parse(opens), HoursTime.parse(closes));

final lunch = r('12:00', '14:00');
final dinner = r('19:00', '22:00');

class _FakeRepo extends OpeningHoursRepository {
  _FakeRepo(this.stored)
    : super(
        SupabaseClient(
          'https://example.invalid',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  OpeningHours stored;
  final saved = <OpeningHours>[];
  bool fail = false;

  @override
  Future<OpeningHours> load(String restaurantId) async => stored;

  @override
  Future<void> save(String restaurantId, OpeningHours hours) async {
    if (fail) throw Exception('offline');
    saved.add(hours);
    stored = hours;
  }
}

void main() {
  group('OpeningHours', () {
    test('reads rows in slot order and writes them back for the RPC', () {
      final hours = OpeningHours.fromRows([
        {
          'weekday': 2,
          'slot': 2,
          'opens_at': '19:00:00',
          'closes_at': '22:00:00',
        },
        {
          'weekday': 2,
          'slot': 1,
          'opens_at': '12:00:00',
          'closes_at': '14:00:00',
        },
      ]);
      expect(hours.on(2), [lunch, dinner]);
      expect(hours.on(1), isEmpty);
      expect(hours.toRpcJson(), [
        {'weekday': 2, 'opens': '12:00', 'closes': '14:00'},
        {'weekday': 2, 'opens': '19:00', 'closes': '22:00'},
      ]);
    });

    test('folds days with the same hours into one line, closed days too', () {
      final hours = OpeningHours({
        for (final d in [2, 3, 4, 5, 6]) d: [lunch, dinner],
        7: [r('18:00', '01:00')],
      });
      expect(hours.lines.map((l) => '${l.daysLabel}: ${l.hoursLabel}'), [
        'Mon: Closed',
        'Tue – Sat: 12:00–14:00 · 19:00–22:00',
        'Sun: 18:00–01:00',
      ]);
      expect(r('18:00', '01:00').pastMidnight, isTrue);
    });

    test('a second time follows the first without ever being empty', () {
      expect(suggestSecondRange(lunch), r('18:00', '22:00'));
      expect(suggestSecondRange(r('12:00', '22:00')), r('23:00', '01:00'));
      final late = suggestSecondRange(r('17:00', '20:00'));
      expect(late, r('21:00', '23:00'));
      for (final first in [lunch, r('12:00', '22:00'), r('17:00', '20:00')]) {
        expect(
          OpeningHours({1: [first, suggestSecondRange(first)]}).validationError(),
          isNull,
          reason: first.label,
        );
      }
    });

    test('an empty week shows nothing', () {
      expect(OpeningHours.empty.isEmpty, isTrue);
      expect(const OpeningHours({1: []}).isEmpty, isTrue);
    });

    test('checks the same rules as the database', () {
      expect(
        OpeningHours({
          1: [lunch, dinner],
        }).validationError(),
        isNull,
      );
      expect(
        OpeningHours({
          1: [r('12:00', '15:00'), r('14:00', '22:00')],
        }).validationError(),
        'Monday: the two times overlap.',
      );
      expect(
        OpeningHours({
          1: [r('12:00', '12:00')],
        }).validationError(),
        'Monday: opening and closing times must differ.',
      );
      expect(
        OpeningHours({
          2: [r('11:00', '01:00'), r('12:00', '14:00')],
        }).validationError(),
        'Tuesday: only the last time of the day can run past midnight.',
      );
      expect(
        OpeningHours({
          3: [lunch, dinner, r('23:00', '23:30')],
        }).validationError(),
        'Wednesday: at most two times a day.',
      );
    });
  });

  group('VenueOpeningHoursSection', () {
    testWidgets('lists the week, and nothing at all without hours', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenueOpeningHoursSection(
              hours: OpeningHours({
                2: [lunch],
              }),
            ),
          ),
        ),
      );
      expect(find.text('OPENING HOURS'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('12:00–14:00'), findsOneWidget);
      expect(find.text('Wed – Sun'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VenueOpeningHoursSection(hours: OpeningHours.empty),
          ),
        ),
      );
      expect(find.text('OPENING HOURS'), findsNothing);
    });
  });

  group('VenueOpeningHoursScreen', () {
    Future<_FakeRepo> pump(WidgetTester tester, OpeningHours stored) async {
      final repo = _FakeRepo(stored);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: VenueOpeningHoursScreen(restaurantId: 'r1', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('opening a day copies the nearest earlier open day, and Save '
        'sends the week at once', (tester) async {
      final repo = await pump(
        tester,
        OpeningHours({
          2: [lunch, dinner],
        }),
      );
      expect(find.text('Closed'), findsNWidgets(6));

      // Wednesday is the third switch.
      await tester.tap(find.byType(Switch).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Closed'), findsNWidgets(5));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.on(3), [lunch, dinner]);
      expect(find.text('Saved. Your page shows them now.'), findsOneWidget);
    });

    testWidgets('a week that breaks a rule is not sent', (tester) async {
      final repo = await pump(
        tester,
        OpeningHours({
          1: [r('12:00', '15:00'), r('14:00', '22:00')],
        }),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.text('Monday: the two times overlap.'), findsOneWidget);
    });

    testWidgets('Remove takes the hours off the page', (tester) async {
      final repo = await pump(
        tester,
        OpeningHours({
          2: [lunch],
        }),
      );
      await tester.tap(find.text('Remove opening hours from page'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.isEmpty, isTrue);
      expect(find.text('Remove opening hours from page'), findsNothing);
      expect(find.text('Closed'), findsNWidgets(7));
    });

    test('the landing summary', () {
      expect(
        VenueOpeningHoursScreen.summary(OpeningHours.empty),
        'Not on your page yet',
      );
      expect(
        VenueOpeningHoursScreen.summary(
          OpeningHours({
            for (var d = 1; d <= 7; d++) d: [lunch],
          }),
        ),
        'Open every day',
      );
      expect(
        VenueOpeningHoursScreen.summary(
          OpeningHours({
            2: [lunch],
            3: [lunch],
          }),
        ),
        'Open 2 days a week',
      );
    });
  });
}
