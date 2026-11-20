// The journey page visuals: cabins read from the operator's text, the
// figures row, which routes can be drawn, the globe's framing and route
// path. Inputs are the cabins texts and stops actually in production on
// 2026-11-20, so a parsing change that would misread a real journey fails
// here.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/journeys/journey_visuals.dart';
import 'package:michelin_passport/features/journeys/widgets/journey_cabins.dart';
import 'package:michelin_passport/features/journeys/widgets/journey_route_globe.dart';
import 'package:michelin_passport/features/map/globe/globe_camera.dart';
import 'package:michelin_passport/features/map/globe/globe_outlines.dart';
import 'package:michelin_passport/models/journey.dart';

Journey _journey({
  int? guests,
  String? country,
  List<String> routeCountries = const [],
}) => Journey(
  id: 'j',
  journeyCode: 'train_002',
  slug: 'j',
  kind: JourneyKind.train,
  name: 'J',
  operatorCode: 'op_001',
  operatorName: 'Belmond',
  guestCapacity: guests,
  primaryCountryCode: country,
  routeCountryCodes: routeCountries,
);

JourneyRoute _route(String id, {int? nights}) => JourneyRoute(
  id: id,
  routeCode: 'train_002_r01',
  name: 'Route',
  fromPlace: 'Cusco',
  toPlace: 'Arequipa',
  nights: nights,
);

JourneyRouteStop _stop(
  String route,
  int order,
  String place, [
  double? lat,
  double? lon,
  String cc = 'PE',
]) => JourneyRouteStop(
  routeId: route,
  stopOrder: order,
  place: place,
  countryCode: cc,
  latitude: lat,
  longitude: lon,
);

void main() {
  group('parseCabins', () {
    test('a leading count is one group', () {
      final c = parseCabins('35 sleeper cabins: twin and bunk-bed cabins')!;
      expect(c.total, 35);
      expect(c.groups.single.name, isNull);
      expect(c.suitesOnly, isFalse);
    });

    test('suites only reads as suites; cabins and suites does not', () {
      expect(parseCabins('95 suites')!.suitesOnly, isTrue);
      expect(parseCabins('149 suites')!.total, 149);
      final mixed = parseCabins('123 cabins and suites')!;
      expect(mixed.total, 123);
      expect(mixed.suitesOnly, isFalse);
    });

    test('every bracketed part becomes a named group', () {
      final c = parseCabins(
        "Historic Cabins (32), Suites (16), Grand Suites (6), "
        "L'Observatoire Suite (1)",
      )!;
      expect(c.groups.map((g) => g.name), [
        'Historic Cabins',
        'Suites',
        'Grand Suites',
        "L'Observatoire Suite",
      ]);
      expect(c.total, 55);
      expect(c.suitesOnly, isFalse);
      expect(
        parseCabins(
          'Grand Suites (3), Twin Suites (4), Double Suites (11)',
        )!.suitesOnly,
        isTrue,
      );
    });

    test('text without counts draws nothing', () {
      expect(
        parseCabins('Double and twin cabins, suites and a Grand Suite'),
        isNull,
      );
      expect(parseCabins('Superior Deluxe and Deluxe cabins'), isNull);
      expect(
        parseCabins(
          'Deluxe Cabins, Junior Suites, Suites and the Presidential Suite',
        ),
        isNull,
      );
      expect(parseCabins(null), isNull);
      expect(parseCabins('  '), isNull);
    });

    test('a list where only some parts are counted draws nothing', () {
      expect(parseCabins('Suites (16), Deluxe cabins'), isNull);
    });
  });

  group('journeyFigures', () {
    test('one route: its nights, cabins, guests', () {
      final f = journeyFigures(
        journey: _journey(guests: 40),
        routes: [_route('r', nights: 2)],
        cabins: parseCabins('20 suites'),
        countryCount: 1,
      );
      expect(f.map((x) => '${x.value} ${x.label}'), [
        '2 Nights',
        '20 Suites',
        '40 Guests',
      ]);
    });

    test('several routes show the count, never a night total', () {
      final f = journeyFigures(
        journey: _journey(),
        routes: [_route('a', nights: 1), _route('b', nights: 5)],
        cabins: parseCabins('Suites (16), Grand Suites (6)'),
        countryCount: 5,
      );
      expect(f.map((x) => x.label), ['Routes', 'Suites', 'Countries']);
    });

    test('a single figure is not shown alone', () {
      expect(
        journeyFigures(
          journey: _journey(),
          routes: [_route('r')],
          cabins: null,
          countryCount: 1,
        ),
        isEmpty,
      );
    });

    test('a day journey has no nights figure', () {
      final f = journeyFigures(
        journey: _journey(guests: 10),
        routes: [_route('r', nights: 0)],
        cabins: parseCabins('5 cabins'),
        countryCount: 1,
      );
      expect(f.map((x) => x.label), ['Cabins', 'Guests']);
    });
  });

  test('journeyCountryCodes joins the journey, its routes and its stops', () {
    expect(
      journeyCountryCodes(
        _journey(country: 'PE', routeCountries: ['PE', 'BO']),
        [_stop('r', 1, 'Brașov', 45.6, 25.6, 'RO')],
      ),
      {'PE', 'BO', 'RO'},
    );
  });

  group('drawableRouteStops', () {
    test('orders stops and keeps routes of two or more', () {
      final d = drawableRouteStops([
        _stop('a', 2, 'Arequipa', -16.4, -71.5),
        _stop('a', 1, 'Cusco', -13.5, -72.0),
        _stop('b', 1, 'Alone', 1, 1),
      ]);
      expect(d.keys, ['a']);
      expect(d['a']!.map((s) => s.place), ['Cusco', 'Arequipa']);
    });

    test('a route with a stop missing coordinates is left out whole', () {
      final d = drawableRouteStops([
        _stop('a', 1, 'Cusco', -13.5, -72.0),
        _stop('a', 2, 'Somewhere'),
        _stop('a', 3, 'Arequipa', -16.4, -71.5),
      ]);
      expect(d, isEmpty);
    });

    test('fromMap reads a journey_route_stops row', () {
      final s = JourneyRouteStop.fromMap({
        'route_id': 'r',
        'stop_order': 2,
        'place': 'Puno',
        'country_code': 'PE',
        'latitude': -15.836,
        'longitude': -70.026,
      });
      expect(s.hasCoordinates, isTrue);
      expect(s.stopOrder, 2);
    });
  });

  group('globe', () {
    late GlobeOutlines outlines;
    setUpAll(() {
      final bytes = File('assets/globe/countries.bin').readAsBytesSync();
      outlines = GlobeOutlines.decode(ByteData.sublistView(bytes));
    });

    test('a country framed on its mainland, not its overseas parts', () {
      final france = fitCountriesCamera(outlines, {'FR'})!;
      expect(france.latitude, closeTo(46.5, 3));
      expect(france.longitude, closeTo(2.5, 3));
      expect(france.zoom, greaterThan(3));
    });

    test('an archipelago framed whole, Sumatra to Papua', () {
      final indonesia = fitCountriesCamera(outlines, {'ID'})!;
      // Indonesia runs about 95 to 141 E; the middle, not Borneo's 114.
      expect(indonesia.longitude, closeTo(118, 5));
    });

    test('no outline for the codes gives no camera', () {
      expect(fitCountriesCamera(outlines, {'XX'}), isNull);
    });

    test('the route path follows every stop on the visible side', () {
      final stops = [
        _stop('a', 1, 'Cusco', -13.525, -71.971),
        _stop('a', 2, 'Puno', -15.836, -70.026),
        _stop('a', 3, 'Arequipa', -16.410, -71.541),
      ];
      final projection = GlobeProjection(
        fitGlobeCamera([
          for (final s in stops) (s.latitude!, s.longitude!),
        ], fallback: const GlobeCamera(latitude: 0, longitude: 0)),
        const Size(350, 260),
      );
      final bounds = JourneyRoutePainter.routePath(
        stops,
        projection,
      ).getBounds();
      expect(bounds.isEmpty, isFalse);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(350));
    });
  });

  testWidgets('one mark per cabin, grouped by name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyCabins(
            layout: parseCabins(
              'Presidential Suites (2), State Cabins (20), Pullman Cabins (10)',
            )!,
            kind: JourneyKind.train,
          ),
        ),
      ),
    );
    expect(find.text('State Cabins'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Wrap), matching: find.byType(Container)),
      findsNWidgets(32),
    );
  });
}
