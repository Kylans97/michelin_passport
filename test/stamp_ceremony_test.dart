// Covers stamp_ceremony.dart: the trigger rules of celebrateNewStamp (it
// opens only for a confirmed stamp that is actually in the member's
// booklet, never for a dismissed/failed save or an Interested/Going
// intent, and only once per stamp), that it returns to the screen
// underneath untouched, that a tap skips it, and the reduced-motion path.
//
// The real booklet widgets are pumped (PassportFlipBook, the cover, the
// pages and the stamp painters) — only the network load is injected,
// since loadOwnPassport needs Supabase.instance.client.
//
// Not covered here: the five call sites themselves (restaurant/hotel
// detail, the Passport add flow, event detail and the Events feed
// prompt) construct their repositories against Supabase.instance.client
// eagerly, the same documented limitation as add_visit_sheet_shell_test
// .dart. Each passes celebrateNewStamp only the row its save returned, so
// a failed save — which throws before any row exists — has nothing to
// pass; the null case below is what a dismissed sheet hands over.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/event_confirmed_attendance_repository.dart';
import 'package:michelin_passport/features/passport/own_passport_loader.dart';
import 'package:michelin_passport/features/passport/passport_booklet_data.dart';
import 'package:michelin_passport/features/passport/stamp_ceremony.dart';
import 'package:michelin_passport/features/passport/widgets/passport_booklet_view.dart';
import 'package:michelin_passport/features/passport/widgets/passport_cover.dart';
import 'package:michelin_passport/features/passport/widgets/passport_stamp.dart';
import 'package:michelin_passport/features/passport/widgets/stamp_ceremony_stamper.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/event_confirmed_attendance.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

final _year = DateTime.now().year;

Restaurant _restaurant(String id) => Restaurant(
  id: id,
  restaurantCode: id,
  name: 'Flore',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Prinsengracht',
);

Visit _visit(String id, {DateTime? on}) => Visit(
  id: id,
  userId: 'u1',
  entityType: 'restaurant',
  entityId: 'r-1',
  visitedOn: on ?? DateTime(_year, 1, 15),
  starsAtVisit: 2,
);

EventConfirmedAttendance _attendance(String id) => EventConfirmedAttendance(
  id: id,
  eventId: 'evt-1',
  userId: 'u1',
  confirmedAt: DateTime.utc(_year, 2, 2),
  visibility: ConfirmedAttendanceVisibility.private,
  source: EventAttendanceSource.manual,
  createdAt: DateTime.utc(_year, 2, 2),
);

Event _event() => Event(
  id: 'evt-1',
  name: 'Wildfestival',
  startAt: DateTime.utc(_year, 2, 1, 18),
  endAt: DateTime.utc(_year, 2, 1, 23),
  countryCode: 'NL',
  city: 'Maastricht',
  venueName: 'Vrijthof',
  eventType: EventType.festival,
  createdAt: DateTime.utc(_year, 1, 1),
);

/// The member's confirmed history, as loadOwnPassport would return it.
OwnPassport _passport({
  List<Visit> visits = const [],
  List<EventConfirmedAttendance> attendances = const [],
}) {
  final entries = visits.isEmpty
      ? <VenueEntry>[]
      : [VenueEntry(venue: RestaurantVenue(_restaurant('r-1')), visits: visits)];
  final eventEntries = [
    for (final a in attendances) EventAttendanceEntry(attendance: a, event: _event()),
  ];
  return OwnPassport(
    volumes: buildPassportVolumes(entries: entries, eventEntries: eventEntries),
    entries: entries,
    eventEntries: eventEntries,
    holderName: 'Kylan',
    avatarUrl: null,
    memberNumber: 17,
    countryNameByCode: const {'NL': 'Netherlands'},
  );
}

/// Counts loads so a test can prove the ceremony never even looked.
class _Loader {
  _Loader(this._result);
  final Future<OwnPassport> Function() _result;
  int calls = 0;
  Future<OwnPassport> call() {
    calls++;
    return _result();
  }
}

/// A screen with state of its own, to prove the ceremony returns to it
/// untouched: same State object, same text in its field.
class _Home extends StatefulWidget {
  const _Home({super.key});
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final controller = TextEditingController(text: 'where I was');
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: TextField(controller: controller)));
}

final _homeKey = GlobalKey<_HomeState>();

Future<BuildContext> _pumpHome(WidgetTester tester, {bool reduceMotion = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: _Home(key: _homeKey),
    ),
  );
  return _homeKey.currentContext!;
}

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _ceremony = find.byType(StampCeremonyOverlay);
final _stamper = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is StamperPainter,
);

double _stampOpacity(WidgetTester tester, String stampId) {
  final stamp = find.byWidgetPredicate(
    (w) => w is PassportStampWidget && w.item.id == stampId,
  );
  expect(stamp, findsOneWidget);
  return tester
      .widget<Opacity>(find.descendant(of: stamp, matching: find.byType(Opacity)).first)
      .opacity;
}

void main() {
  late List<String> haptics;

  setUp(() {
    StampCeremony.resetForTesting();
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('celebrateNewStamp — trigger rules', () {
    testWidgets(
      'a confirmed visit opens the real booklet, the rubber stamp presses '
      'the stamp on contact with one haptic, and it returns to the same '
      'screen untouched',
      (tester) async {
        final context = await _pumpHome(tester);
        final homeState = _homeKey.currentState;
        final visit = _visit('v-new');
        final loader = _Loader(() async => _passport(visits: [_visit('v-old', on: DateTime(_year, 1, 2)), visit]));

        final done = celebrateNewStamp(context, EarnedStamp.visit(visit), load: loader.call);
        await tester.pump();
        await tester.pump();

        expect(_ceremony, findsOneWidget);
        expect(find.byType(PassportFlipBook), findsOneWidget);
        // The real, closed cover is what the member sees first.
        expect(find.byType(PassportCoverFace), findsOneWidget);
        // The route carries its own Material: without one, every Text in
        // the booklet inherits WidgetsApp's yellow-underlined debug style
        // (seen in the simulator before this was fixed).
        expect(
          DefaultTextStyle.of(tester.element(find.text('PASSPORT'))).style.decoration,
          isNot(TextDecoration.underline),
        );

        // Backdrop (200) + cover open (450), then the stamper's run: the
        // page has turned and the rubber stamp is out, over its ink pad
        // or on its way, but nothing is on the page yet.
        await _pumpFor(tester, 1050);
        expect(_stamper, findsOneWidget);
        expect(_stampOpacity(tester, 'v-new'), 0);
        expect(haptics, isEmpty);

        // Still in the air just before contact (at 80% of the 1400ms run,
        // ~1770ms in): no impression, no haptic.
        await _pumpFor(tester, 650);
        expect(_stampOpacity(tester, 'v-new'), 0);
        expect(haptics, isEmpty);

        // Contact: the impression lands with the one haptic, and its ink
        // settles at a stamp's usual 0.9.
        await _pumpFor(tester, 700);
        expect(_stampOpacity(tester, 'v-new'), closeTo(0.9, 0.001));
        expect(haptics, ['HapticFeedbackType.mediumImpact']);

        // Hold, close, fade out — then it is gone.
        await _pumpFor(tester, 1000);
        await tester.pumpAndSettle();
        await done;

        expect(_ceremony, findsNothing);
        expect(_homeKey.currentState, same(homeState));
        expect(find.text('where I was'), findsOneWidget);
        expect(haptics, hasLength(1));
        expect(StampCeremony.celebratedIds, {'v-new'});
      },
    );

    testWidgets('a confirmed event attendance opens the ceremony', (tester) async {
      final context = await _pumpHome(tester);
      final attendance = _attendance('att-1');
      final loader = _Loader(() async => _passport(attendances: [attendance]));

      celebrateNewStamp(context, EarnedStamp.attendance(attendance), load: loader.call);
      await tester.pump();
      await tester.pump();

      expect(_ceremony, findsOneWidget);
      await _pumpFor(tester, 3200);
      await tester.pumpAndSettle();
      expect(_ceremony, findsNothing);
    });

    testWidgets(
      'no saved row (a dismissed sheet, or a save that failed) shows '
      'nothing and never loads the passport',
      (tester) async {
        final context = await _pumpHome(tester);
        final loader = _Loader(() async => _passport(visits: [_visit('v-1')]));

        await celebrateNewStamp(context, null, load: loader.call);
        await tester.pumpAndSettle();

        expect(loader.calls, 0);
        expect(_ceremony, findsNothing);
      },
    );

    testWidgets(
      'an id that is not a confirmed stamp — an Interested/Going intent '
      'never reaches visits or event_confirmed_attendance — shows nothing',
      (tester) async {
        final context = await _pumpHome(tester);
        // The member's confirmed history holds only an older visit; the
        // id below is not a confirmed row, so it has no stamp anywhere.
        final loader = _Loader(() async => _passport(visits: [_visit('v-old')]));

        await celebrateNewStamp(
          context,
          EarnedStamp.attendance(_attendance('going-intent-id')),
          load: loader.call,
        );
        await tester.pumpAndSettle();

        expect(_ceremony, findsNothing);
        expect(StampCeremony.celebratedIds, isEmpty);
      },
    );

    testWidgets(
      'a back-dated visit outside the 5-year booklet has no page, so no '
      'ceremony',
      (tester) async {
        final context = await _pumpHome(tester);
        final old = _visit('v-ancient', on: DateTime(_year - 10, 5, 1));
        final loader = _Loader(() async => _passport(visits: [_visit('v-1'), old]));

        await celebrateNewStamp(context, EarnedStamp.visit(old), load: loader.call);
        await tester.pumpAndSettle();

        expect(_ceremony, findsNothing);
      },
    );

    testWidgets('a passport that fails to load shows nothing and never throws', (
      tester,
    ) async {
      final context = await _pumpHome(tester);
      final loader = _Loader(() async => throw Exception('offline'));

      await celebrateNewStamp(context, EarnedStamp.visit(_visit('v-1')), load: loader.call);
      await tester.pumpAndSettle();

      expect(loader.calls, 1);
      expect(_ceremony, findsNothing);
    });

    testWidgets(
      'fires once per stamp: a second call for the same row — a double '
      'tap, or confirmAttendance returning the existing row — shows nothing',
      (tester) async {
        final context = await _pumpHome(tester);
        final visit = _visit('v-1');
        final loader = _Loader(() async => _passport(visits: [visit]));

        // Two racing calls for the same stamp.
        celebrateNewStamp(context, EarnedStamp.visit(visit), load: loader.call);
        celebrateNewStamp(context, EarnedStamp.visit(visit), load: loader.call);
        await tester.pump();
        await tester.pump();
        expect(_ceremony, findsOneWidget);
        await _pumpFor(tester, 3200);
        await tester.pumpAndSettle();
        expect(_ceremony, findsNothing);

        // And once more, later.
        await celebrateNewStamp(context, EarnedStamp.visit(visit), load: loader.call);
        await tester.pumpAndSettle();

        expect(_ceremony, findsNothing);
        expect(loader.calls, 1);
      },
    );
  });

  group('StampCeremonyOverlay', () {
    testWidgets('a tap anywhere skips straight back to the screen underneath', (
      tester,
    ) async {
      final context = await _pumpHome(tester);
      final visit = _visit('v-1');
      final done = celebrateNewStamp(
        context,
        EarnedStamp.visit(visit),
        load: () async => _passport(visits: [visit]),
      );
      await tester.pump();
      await tester.pump();
      await _pumpFor(tester, 400);

      await tester.tap(_ceremony);
      // The skip fade is 150ms; one frame more lets the route pop.
      await _pumpFor(tester, 250);
      await tester.pump();
      await done;

      expect(_ceremony, findsNothing);
      expect(find.text('where I was'), findsOneWidget);
      // Skipped before the press, so no haptic either.
      expect(haptics, isEmpty);
    });

    testWidgets(
      'reduced motion: no cover or flip, the booklet is already open on the '
      "stamp's page, and the stamp simply fades in",
      (tester) async {
        final context = await _pumpHome(tester, reduceMotion: true);
        final visit = _visit('v-1');
        celebrateNewStamp(
          context,
          EarnedStamp.visit(visit),
          load: () async => _passport(visits: [visit]),
        );
        await tester.pump();
        await tester.pump();

        expect(_ceremony, findsOneWidget);
        expect(find.byType(PassportFlipBook), findsNothing);
        expect(find.byType(PassportCoverFace), findsNothing);
        expect(find.byType(PassportOpenBookFrame), findsOneWidget);
        expect(_stamper, findsNothing);

        // After the backdrop (200), the stamp is on the page, unpressed.
        await _pumpFor(tester, 200);
        expect(_stampOpacity(tester, 'v-1'), 0);

        // Halfway through the 400ms fade: partly inked, no scale or
        // rotation from the ceremony (the only Transform above the
        // stamp's painter is its own resting rotation).
        await _pumpFor(tester, 200);
        final mid = _stampOpacity(tester, 'v-1');
        expect(mid, greaterThan(0.2));
        expect(mid, lessThan(0.9));
        final stamp = find.byWidgetPredicate(
          (w) => w is PassportStampWidget && w.item.id == 'v-1',
        );
        final scales = tester
            .widgetList<Transform>(find.descendant(of: stamp, matching: find.byType(Transform)))
            .where((t) => t.transform.getMaxScaleOnAxis() != 1.0);
        expect(scales, isEmpty);

        await _pumpFor(tester, 250);
        expect(_stampOpacity(tester, 'v-1'), closeTo(0.9, 0.001));

        await _pumpFor(tester, 1300);
        await tester.pumpAndSettle();
        expect(_ceremony, findsNothing);
      },
    );
  });

  group('StamperPath', () {
    const path = StamperPath(pad: Offset(300, 700), target: Offset(150, 250));

    test('starts hovering over the ink pad, uninked', () {
      final p = path.at(0.05);
      expect(p.ground, const Offset(300, 700));
      expect(p.height, greaterThan(0));
      expect(p.inked, 0);
    });

    test('touches the pad on the dip and comes away inked', () {
      expect(path.at(0.26).height, closeTo(0, 0.001));
      expect(path.at(0.3).inked, 1);
      expect(path.at(0.3).ground, const Offset(300, 700));
    });

    test('is in the air until contact, then touching exactly on the stamp', () {
      expect(path.at(StamperPath.contact - 0.02).height, greaterThan(0));
      final p = path.at(StamperPath.contact);
      expect(p.height, 0);
      expect(p.ground, const Offset(150, 250));
    });

    test('lifts away and fades out by the end', () {
      final p = path.at(1);
      expect(p.height, greaterThan(0));
      expect(p.opacity, 0);
    });
  });
}
