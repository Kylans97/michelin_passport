// Trains and ships (20261101500000_add_journeys.sql): the model's parsing
// and labels, the collection's order and filter, the confirmed-travel
// insert, and how a confirmed travel becomes a Passport stamp. Pure logic
// plus one card render; the screens that need a live Supabase client are
// covered by the simulator run, not here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/data/repositories/journey_repository.dart';
import 'package:michelin_passport/features/journeys/widgets/journey_card.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_award.dart';
import 'package:michelin_passport/features/passport/models/passport_stamp_item.dart';
import 'package:michelin_passport/features/passport/passport_booklet_data.dart';
import 'package:michelin_passport/features/passport/passport_filter_type.dart';
import 'package:michelin_passport/features/passport/passport_stamp_source.dart';
import 'package:michelin_passport/models/journey.dart';

Map<String, dynamic> _row({
  String id = 'j1',
  String code = 'train_002',
  String kind = 'train',
  String? shipType,
  String name = 'Belmond Andean Explorer',
  String? country = 'PE',
  String? countryName = 'Peru',
  String? regions = 'Peruvian Andes',
}) => {
  'id': id,
  'journey_code': code,
  'slug': 'belmond-andean-explorer',
  'kind': kind,
  'ship_type': shipType,
  'name': name,
  'status': 'operating',
  'first_departure_on': null,
  'summary': 'Sleeper train across the Peruvian highlands.',
  'cabins_text': '35 sleeper cabins',
  'guest_capacity': null,
  'dining_text': 'Two dining cars.',
  'official_url': 'https://www.belmond.com/',
  'primary_country_code': country,
  'regions_text': regions,
  'country_name': countryName,
  'flag_emoji': '🇵🇪',
  'operator_code': 'op_001',
  'operator_name': 'Belmond',
  'operator_website_url': 'https://www.belmond.com/',
  'route_count': 1,
  'route_country_codes': ['PE'],
};

JourneyTravelEntry _entry({
  String travelId = 't1',
  DateTime? departed,
  JourneyRoute? route,
  Journey? journey,
}) => JourneyTravelEntry(
  travel: JourneyTravel(
    id: travelId,
    journeyId: 'j1',
    departedOn: departed ?? DateTime(2026, 6, 1),
  ),
  journey: journey ?? Journey.fromMap(_row()),
  route: route,
);

const _route = JourneyRoute(
  id: 'r1',
  routeCode: 'train_002_r01',
  name: 'Peruvian Highlands',
  fromPlace: 'Cusco',
  toPlace: 'Arequipa',
  fromCountryCode: 'PE',
  nights: 2,
);

void main() {
  group('Journey.fromMap', () {
    test('parses a journeys_full row', () {
      final j = Journey.fromMap(_row());
      expect(j.kind, JourneyKind.train);
      expect(j.journeyCode, 'train_002');
      expect(j.operatorName, 'Belmond');
      expect(j.routeCountryCodes, ['PE']);
      expect(j.status, JourneyStatus.operating);
    });

    test('regions win over the single country for the place line', () {
      expect(Journey.fromMap(_row()).whereLine, 'Peruvian Andes');
      expect(Journey.fromMap(_row(regions: null)).whereLine, 'Peru');
      expect(
        Journey.fromMap(
          _row(regions: null, country: null, countryName: null),
        ).whereLine,
        isNull,
      );
    });

    test('kind label names the kind of ship', () {
      expect(Journey.fromMap(_row()).kindLabel, 'Train');
      expect(
        Journey.fromMap(_row(kind: 'ship', shipType: 'river')).kindLabel,
        'River ship',
      );
      expect(
        Journey.fromMap(_row(kind: 'ship', shipType: null)).kindLabel,
        'Ship',
      );
    });
  });

  group('JourneyRoute labels', () {
    test('a stated night count', () {
      expect(_route.lengthLabel, '2 nights');
      expect(_route.endpoints, 'Cusco → Arequipa');
    });

    test('a round trip says where it starts', () {
      const r = JourneyRoute(
        id: 'r',
        routeCode: 'train_005_r01',
        name: 'Cornwall',
        fromPlace: 'London',
        toPlace: 'London',
        nights: 1,
      );
      expect(r.endpoints, 'From London');
      expect(r.lengthLabel, '1 night');
    });

    test('days stay days, never turned into nights', () {
      const r = JourneyRoute(
        id: 'r',
        routeCode: 'train_007_r01',
        name: 'Paris – Istanbul',
        fromPlace: 'Paris',
        toPlace: 'Istanbul',
        durationText: '8 days',
      );
      expect(r.lengthLabel, '8 days');
    });

    test('no stated length gives no label', () {
      const r = JourneyRoute(
        id: 'r',
        routeCode: 'train_006_r01',
        name: 'Magic Istanbul',
        fromPlace: 'Rome',
        toPlace: 'Istanbul',
      );
      expect(r.lengthLabel, isNull);
    });
  });

  test('collection order: trains first, then ships, each by name', () {
    final sorted = sortJourneysForCollection([
      Journey.fromMap(
        _row(id: 'a', kind: 'ship', code: 'ship_004', name: 'Aqua Nera'),
      ),
      Journey.fromMap(_row(id: 'b', name: 'Venice Simplon-Orient-Express')),
      Journey.fromMap(_row(id: 'c', name: 'Belmond Andean Explorer')),
    ]);
    expect(sorted.map((j) => j.id), ['c', 'b', 'a']);
    expect(journeysOfKind(sorted, JourneyKind.ship).map((j) => j.id), ['a']);
    expect(journeysOfKind(sorted, null), hasLength(3));
  });

  test('confirmed-travel insert carries only what the member gave', () {
    expect(
      buildJourneyTravelInsert(
        userId: 'u1',
        journeyId: 'j1',
        departedOn: DateTime(2026, 3, 4),
      ),
      {
        'user_id': 'u1',
        'journey_id': 'j1',
        'departed_on': '2026-03-04',
        'visibility': 'private',
        'source': 'manual',
      },
    );
    final withRoute = buildJourneyTravelInsert(
      userId: 'u1',
      journeyId: 'j1',
      routeId: 'r1',
      departedOn: DateTime(2026, 3, 4),
      arrivedOn: DateTime(2026, 3, 6),
      visibility: JourneyTravelVisibility.friends,
    );
    expect(withRoute['route_id'], 'r1');
    expect(withRoute['arrived_on'], '2026-03-06');
    expect(withRoute['visibility'], 'friends');
  });

  group('Passport', () {
    test('a confirmed travel becomes one stamp, dated by departure', () {
      final items = buildJourneyStampItems([_entry(route: _route)]);
      expect(items, hasLength(1));
      final item = items.single as JourneyStampItem;
      expect(item.id, 't1');
      expect(item.venueName, 'Belmond Andean Explorer');
      expect(item.cityName, 'Cusco');
      expect(item.countryCode, 'PE');
      expect(item.date, DateTime(2026, 6, 1));
    });

    test('without a route, no place is guessed', () {
      final ship = Journey.fromMap(
        _row(kind: 'ship', code: 'ship_009', country: null, countryName: null),
      );
      final item =
          buildJourneyStampItems([_entry(journey: ship)]).single
              as JourneyStampItem;
      expect(item.cityName, '');
      expect(item.countryCode, '');
    });

    test('the award row is the kind, never stars or Keys', () {
      final item = buildJourneyStampItems([_entry()]).single;
      final award = stampAwardFor(item);
      expect(award, isA<JourneyKindAward>());
      expect((award as JourneyKindAward).label, 'TRAIN');
    });

    test('year filter uses the departure year', () {
      final entries = [
        _entry(travelId: 'a', departed: DateTime(2025, 12, 30)),
        _entry(travelId: 'b', departed: DateTime(2026, 1, 2)),
      ];
      expect(buildJourneyStampItems(entries, year: 2026).map((i) => i.id), [
        'b',
      ]);
    });

    test('journey stamps join the booklet with everything else', () {
      final volumes = buildPassportVolumes(
        entries: const [],
        eventEntries: const [],
        journeyEntries: [_entry(departed: DateTime(DateTime.now().year, 1, 1))],
      );
      expect(volumes, hasLength(1));
      expect(volumes.single.items.single, isA<JourneyStampItem>());
      expect(volumes.single.countryCodes, ['PE']);
      expect(volumes.single.stars, 0);
    });

    test('Passport has a Journeys filter', () {
      expect(PassportFilterType.journeys.label, 'Journeys');
    });
  });

  testWidgets('the card has no Selection line and nothing in gold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyCard(journey: Journey.fromMap(_row()), onTap: () {}),
        ),
      ),
    );
    expect(find.text('Belmond Andean Explorer'), findsOneWidget);
    expect(find.text('TRAIN · BELMOND'), findsOneWidget);
    expect(find.text('MANTELIER SELECTION'), findsNothing);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.style?.color, isNot(AppColors.gold));
    }
  });
}
