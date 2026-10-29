// Covers the event location picker's move from OpenStreetMap's own tile
// servers to MapTiler: tiles come from api.maptiler.com with the configured
// key, the required credit stays visible, and with no key the screen shows
// no map at all rather than falling back to tile.openstreetmap.org.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:michelin_passport/core/maps/maptiler_config.dart';
import 'package:michelin_passport/features/profile/pick_event_location_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  test('the tile URL is MapTiler, never OpenStreetMap', () {
    final url = MapTilerConfig.urlTemplate('k123');
    expect(url, startsWith('https://api.maptiler.com/maps/'));
    expect(url, contains('key=k123'));
    expect(url, contains('{r}'));
    expect(url, isNot(contains('openstreetmap')));
  });

  test('no .env loaded: no key', () {
    expect(MapTilerConfig.key, isNull);
  });

  testWidgets('with a key: MapTiler tiles and the required credit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PickEventLocationScreen(mapTilerKey: 'k123')),
    );
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, MapTilerConfig.urlTemplate('k123'));
    expect(find.text('© MapTiler'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without a key: no map, and no way to pick', (tester) async {
    await tester.pumpWidget(_wrap(const PickEventLocationScreen()));
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text("The map can't be shown right now."), findsOneWidget);
    expect(find.text('Tap the map where the event is held.'), findsOneWidget);
  });

  testWidgets('tapping the map drops the pin and returns it', (tester) async {
    LatLng? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await Navigator.of(context).push<LatLng>(
                MaterialPageRoute(
                  builder: (_) =>
                      const PickEventLocationScreen(mapTilerKey: 'k123'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FlutterMap));
    // flutter_map waits out the double-tap window before reporting a tap.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tap again to move the pin.'), findsOneWidget);
    await tester.tap(find.text('Use this location'));
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
  });
}
