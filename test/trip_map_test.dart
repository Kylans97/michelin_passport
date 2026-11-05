import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:michelin_passport/data/repositories/map_repository.dart';
import 'package:michelin_passport/features/trips/trip_map/trip_map_items.dart';
import 'package:michelin_passport/features/trips/trip_map/trip_map_screen.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/planned_trip.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/trip_destination.dart';

Restaurant _restaurant(String id, String name, {int? stars}) =>
    Restaurant.fromJson({
      'id': id,
      'name': name,
      'city_name': 'Tokyo',
      'country_code': 'JP',
      'michelin_stars': stars,
    });

Hotel _hotel(String id, String name) => Hotel.fromJson({
  'id': id,
  'name': name,
  'city_name': 'Kyoto',
  'country_code': 'JP',
  'michelin_keys': 2,
});

const _tokyo = TripDestination(
  countryCode: 'JP',
  cityId: 'c-tokyo',
  cityName: 'Tokyo',
);
const _kyoto = TripDestination(
  countryCode: 'JP',
  cityId: 'c-kyoto',
  cityName: 'Kyoto',
);

PlannedTrip _trip(List<TripDestination> legs) => PlannedTrip(
  id: 't1',
  userId: 'u1',
  title: 'Japan, spring',
  startDate: DateTime(2027, 3, 12),
  endDate: DateTime(2027, 3, 19),
  countryCode: 'JP',
  createdAt: DateTime(2026, 11, 1),
  destinations: legs,
);

void main() {
  group('clusterTripMapItems', () {
    // A flat projection: one degree is 100 px, so a 56 px cell holds
    // points under 0.56 degrees apart.
    Offset project(LatLng p) => Offset(p.longitude * 100, p.latitude * 100);

    TripMapVenueItem venue(
      String id,
      double lat,
      double lng, {
      bool planned = false,
    }) => TripMapVenueItem(
      RestaurantVenue(_restaurant(id, id)),
      LatLng(lat, lng),
      planned: planned,
    );

    test('nearby venues share a cluster, distant ones do not', () {
      final clusters = clusterTripMapItems([
        venue('a', 0.1, 0.1),
        venue('b', 0.2, 0.2),
        venue('c', 5, 5),
      ], project);
      final sizes = clusters.map((c) => c.items.length).toList()..sort();
      expect(sizes, [1, 2]);
    });

    test('a planned venue keeps its own marker even right next to others', () {
      final clusters = clusterTripMapItems([
        venue('a', 0.1, 0.1),
        venue('b', 0.2, 0.2),
        venue('p', 0.15, 0.15, planned: true),
      ], project);
      expect(clusters, hasLength(2));
      final planned = clusters.singleWhere((c) => c.items.length == 1);
      expect((planned.items.single as TripMapVenueItem).planned, isTrue);
    });

    test('a cluster sits at the average of its members', () {
      final cluster = TripMapCluster([venue('a', 1, 1), venue('b', 3, 5)]);
      expect(cluster.center, const LatLng(2, 3));
    });
  });

  group('pickTripMapLabels', () {
    // One degree of latitude/longitude is one hundred pixels here.
    Offset project(LatLng p) => Offset(p.longitude * 100, -p.latitude * 100);
    TripMapVenueItem venue(
      String id,
      double lat,
      double lng, {
      bool planned = false,
    }) => TripMapVenueItem(
      RestaurantVenue(_restaurant(id, id)),
      LatLng(lat, lng),
      planned: planned,
    );
    Map<String, TripMapLabelSide> pick(
      List<TripMapItem> items, {
      double zoom = 15,
      List<Offset> obstacles = const [],
      String? selectedKey,
    }) => pickTripMapLabels(
      items,
      zoom: zoom,
      project: project,
      labelWidth: (_) => 60,
      obstacles: obstacles,
      selectedKey: selectedKey,
    );

    test('zoomed out, no names; a planned place shows its name first', () {
      final items = [venue('a', 0, 0), venue('b', 2, 0, planned: true)];
      expect(pick(items, zoom: 11), isEmpty);
      expect(pick(items, zoom: 12).keys, ['r:b']);
      expect(pick(items, zoom: 14).keys.toSet(), {'r:a', 'r:b'});
    });

    test('the selected place shows its name at any zoom', () {
      final items = [venue('a', 0, 0), venue('b', 2, 0)];
      expect(pick(items, zoom: 6, selectedKey: 'r:a').keys, ['r:a']);
    });

    test('a name goes left when another pin stands on its right', () {
      final labels = pick([venue('a', 0, 0), venue('b', 0, 0.5)]);
      expect(labels['r:a'], TripMapLabelSide.left);
      expect(labels['r:b'], TripMapLabelSide.right);
    });

    test('a name with no room on either side stays hidden', () {
      final labels = pick([
        venue('left', 0, -0.5),
        venue('middle', 0, 0),
        venue('right', 0, 0.5),
      ]);
      expect(labels.containsKey('r:middle'), isFalse);
      expect(labels['r:left'], TripMapLabelSide.left);
      expect(labels['r:right'], TripMapLabelSide.right);
    });

    test('names never overlap: a planned place picks first, the next moves', () {
      final labels = pick([
        venue('rest', 0.1, 0),
        venue('planned', 0, 0, planned: true),
      ]);
      expect(labels['r:planned'], TripMapLabelSide.right);
      expect(labels['r:rest'], TripMapLabelSide.left);
    });

    test('a numbered cluster blocks a name like a pin does', () {
      final labels = pick(
        [venue('a', 0, 0)],
        obstacles: [const Offset(50, 0), const Offset(-50, 0)],
      );
      expect(labels, isEmpty);
    });
  });

  group('TripMapScreen', () {
    late List<TripDestination> loadedLegs;
    late List<String> added;

    setUp(() {
      loadedLegs = [];
      added = [];
    });

    Future<void> pump(
      WidgetTester tester, {
      required List<TripDestination> legs,
      String? mapTilerKey = 'test-key',
      Map<String, List<MappedVenue>> venuesByCity = const {},
      Set<String> plannedKeys = const {},
      bool failAdd = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripMapScreen(
            trip: _trip(legs),
            events: const <Event>[],
            plannedKeys: plannedKeys,
            legLabel: (leg) => leg.cityName ?? leg.countryCode,
            loadVenues: (leg) async {
              loadedLegs.add(leg);
              return venuesByCity[leg.cityId] ?? [];
            },
            addToTrip: (venue, leg) async {
              if (failAdd) return false;
              added.add('${venue.name}@${leg.cityName}');
              return true;
            },
            openVenue: (_) {},
            openEvent: (_) {},
            mapTilerKey: mapTilerKey,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    final tokyoVenues = [
      MappedVenue(
        RestaurantVenue(_restaurant('r1', 'Restaurant One', stars: 2)),
        35.67,
        139.76,
      ),
      MappedVenue(
        RestaurantVenue(_restaurant('r2', 'Restaurant Two')),
        35.70,
        139.70,
      ),
    ];

    testWidgets(
      'a marker opens its card, and Add to trip plans it for that leg',
      (tester) async {
        await pump(
          tester,
          legs: [_tokyo],
          venuesByCity: {'c-tokyo': tokyoVenues},
        );
        expect(loadedLegs, [_tokyo]);

        await tester.tap(find.bySemanticsLabel('Restaurant One'));
        await tester.pump();
        expect(find.text('Add to trip'), findsOneWidget);
        expect(find.text('View venue'), findsOneWidget);

        await tester.tap(find.text('Add to trip'));
        await tester.pump();
        await tester.pump();
        expect(added, ['Restaurant One@Tokyo']);
        expect(find.text('On your trip'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Restaurant One, on your trip'),
          findsOneWidget,
        );
      },
    );

    testWidgets('something already planned shows as on your trip', (
      tester,
    ) async {
      await pump(
        tester,
        legs: [_tokyo],
        venuesByCity: {'c-tokyo': tokyoVenues},
        plannedKeys: {'r:r2'},
      );
      await tester.tap(find.bySemanticsLabel('Restaurant Two, on your trip'));
      await tester.pump();
      expect(find.text('On your trip'), findsOneWidget);
      expect(find.text('Add to trip'), findsNothing);
    });

    testWidgets('a failed add says so and leaves the venue unplanned', (
      tester,
    ) async {
      await pump(
        tester,
        legs: [_tokyo],
        venuesByCity: {'c-tokyo': tokyoVenues},
        failAdd: true,
      );
      await tester.tap(find.bySemanticsLabel('Restaurant One'));
      await tester.pump();
      await tester.tap(find.text('Add to trip'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Could not add that to your trip. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Add to trip'), findsOneWidget);
    });

    testWidgets('a trip with two destinations switches leg from the chips', (
      tester,
    ) async {
      await pump(
        tester,
        legs: [_tokyo, _kyoto],
        venuesByCity: {
          'c-tokyo': tokyoVenues,
          'c-kyoto': [
            MappedVenue(HotelVenue(_hotel('h1', 'Hotel One')), 35.01, 135.77),
          ],
        },
      );
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Kyoto'), findsOneWidget);

      await tester.tap(find.text('Kyoto'));
      await tester.pump();
      await tester.pump();
      expect(loadedLegs, [_tokyo, _kyoto]);
      await tester.pump();
      expect(find.bySemanticsLabel('Hotel One'), findsOneWidget);
      expect(find.bySemanticsLabel('Restaurant One'), findsNothing);
    });

    testWidgets('a place with nothing in Mantelier says so', (tester) async {
      await pump(tester, legs: [_kyoto]);
      expect(find.text('No Mantelier places in Kyoto yet.'), findsOneWidget);
    });

    testWidgets('without a map key it shows a message, not a broken map', (
      tester,
    ) async {
      await pump(
        tester,
        legs: [_tokyo],
        mapTilerKey: null,
        venuesByCity: {'c-tokyo': tokyoVenues},
      );
      expect(find.text("The map can't be shown right now."), findsOneWidget);
    });
  });
}
