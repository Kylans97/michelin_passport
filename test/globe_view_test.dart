// Covers My Map's 3D globe (lib/features/map/globe/):
// - the bundled Natural Earth outline asset decodes, and every country code
//   the app stores is present in it (so the visited-country tint can match);
// - projection, fitting and clustering maths;
// - painting the full outlines from many viewpoints (over the poles, the
//   antimeridian, each country straddling the horizon) without throwing;
// - GlobeView: a pin tap flies to the pin and then hands it over, a merged
//   marker that zooming can't separate hands over all its pins.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/map/globe/globe_camera.dart';
import 'package:michelin_passport/features/map/globe/globe_outlines.dart';
import 'package:michelin_passport/features/map/globe/globe_painter.dart';
import 'package:michelin_passport/features/map/globe/globe_view.dart';
import 'package:michelin_passport/features/map/models/map_pin.dart';
import 'package:michelin_passport/features/map/widgets/venue_pin.dart';
import 'package:michelin_passport/features/passport/passport_view_model.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';

GlobeOutlines _outlinesFromDisk() {
  final bytes = File(globeOutlinesAsset).readAsBytesSync();
  return GlobeOutlines.decode(ByteData.sublistView(bytes));
}

RestaurantMapPin _pin(String id, double lat, double lon) {
  final restaurant = Restaurant(
    id: id,
    restaurantCode: id,
    name: 'Restaurant $id',
    michelinStars: 1,
    inclusionReason: 'michelin_star',
    cityName: 'Amsterdam',
    countryCode: 'NL',
    countryName: 'Netherlands',
    flagEmoji: '🇳🇱',
    address: '1 Test Street',
  );
  return RestaurantMapPin(
    stats: PassportVenueStats.from(RestaurantVenue(restaurant), [
      Visit(
        id: 'v$id',
        userId: 'u1',
        entityType: 'restaurant',
        entityId: id,
        visitedOn: DateTime(2026, 5, 1),
        starsAtVisit: 1,
      ),
    ]),
    latitude: lat,
    longitude: lon,
  );
}

/// Runs a flight to its end. Pumped in steps, not as one long frame: the
/// hand-over after a flight happens a frame after the last animation tick.
/// (pumpAndSettle can't be used: a resume timer is always pending.)
Future<void> flyAndSettle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('GlobeOutlines', () {
    test('decodes every Natural Earth country, with the codes the app '
        'stores', () {
      final outlines = _outlinesFromDisk();
      expect(outlines.countries, hasLength(242));
      final codes = {for (final c in outlines.countries) c.code};
      // A sample of production `countries.country_code` values, including
      // the two Natural Earth marks -99 in ISO_A2 (France, Norway) — the
      // build script falls back from ISO_A2_EH, so these must be present.
      for (final code in ['NL', 'BE', 'FR', 'NO', 'GB', 'US', 'CN', 'HK']) {
        expect(codes, contains(code));
      }
      for (final country in outlines.countries) {
        for (final ring in country.rings) {
          for (var i = 0; i < ring.length; i += 3) {
            final len =
                ring[i] * ring[i] +
                ring[i + 1] * ring[i + 1] +
                ring[i + 2] * ring[i + 2];
            expect(len, closeTo(1, 1e-4));
          }
        }
      }
    });

    test('rejects anything that is not a GLB1 asset', () {
      expect(
        () => GlobeOutlines.decode(ByteData.sublistView(Uint8List(8))),
        throwsFormatException,
      );
    });
  });

  group('GlobeCamera', () {
    test('wraps longitude and clamps latitude and zoom', () {
      final c = const GlobeCamera(
        latitude: 0,
        longitude: 0,
      ).copyWith(latitude: 95, longitude: 190, zoom: 100);
      expect(c.latitude, GlobeCamera.maxLatitude);
      expect(c.longitude, closeTo(-170, 1e-9));
      expect(c.zoom, GlobeCamera.maxZoom);
    });

    test('lerps the short way round the antimeridian', () {
      const from = GlobeCamera(latitude: 0, longitude: 170);
      const to = GlobeCamera(latitude: 0, longitude: -170);
      expect(from.lerpTo(to, 0.5).longitude.abs(), closeTo(180, 1e-9));
    });
  });

  group('GlobeProjection', () {
    const size = Size(400, 600);

    test('the camera point is at the centre, its antipode behind', () {
      final p = GlobeProjection(
        const GlobeCamera(latitude: 52.37, longitude: 4.9),
        size,
      );
      final (centre, z) = p.project(52.37, 4.9);
      expect(centre.dx, closeTo(200, 1e-6));
      expect(centre.dy, closeTo(300, 1e-6));
      expect(z, closeTo(1, 1e-9));
      expect(p.project(-52.37, -175.1).$2, closeTo(-1, 1e-9));
    });

    test('north is up and east is right', () {
      final p = GlobeProjection(
        const GlobeCamera(latitude: 0, longitude: 0),
        size,
      );
      expect(p.project(10, 0).$1.dy, lessThan(300));
      expect(p.project(0, 10).$1.dx, greaterThan(200));
    });
  });

  group('fitGlobeCamera', () {
    const fallback = GlobeCamera(latitude: 10, longitude: 20, zoom: 3);

    test('no points: the whole globe, where it already was', () {
      final fit = fitGlobeCamera([], fallback: fallback);
      expect(fit.latitude, 10);
      expect(fit.longitude, 20);
      expect(fit.zoom, GlobeCamera.minZoom);
    });

    test('nearby points: centred between them, zoomed in', () {
      final fit = fitGlobeCamera([
        (52.37, 4.90), // Amsterdam
        (48.86, 2.35), // Paris
      ], fallback: fallback);
      expect(fit.latitude, inInclusiveRange(48.86, 52.37));
      expect(fit.longitude, inInclusiveRange(2.35, 4.90));
      expect(fit.zoom, greaterThan(2));
      expect(fit.zoom, lessThanOrEqualTo(6));
    });

    test('points round the world: the whole globe', () {
      final fit = fitGlobeCamera([
        (52.37, 4.90),
        (35.68, 139.69), // Tokyo
        (-33.87, 151.21), // Sydney
        (40.71, -74.0), // New York
      ], fallback: fallback);
      expect(fit.zoom, GlobeCamera.minZoom);
    });

    test('a single point gets the single-point zoom', () {
      expect(fitGlobeCamera([(1, 2)], fallback: fallback).zoom, 6);
    });
  });

  group('clusterOnGlobe', () {
    const size = Size(400, 600);
    // Amsterdam, Utrecht (~35 km away), and a point on the far side.
    final points = [(52.37, 4.90), (52.09, 5.12), (-52.37, -175.1)];

    List<GlobeCluster<(double, double)>> clusters(double zoom) =>
        clusterOnGlobe(
          points,
          projection: GlobeProjection(
            GlobeCamera(latitude: 52.37, longitude: 4.9, zoom: zoom),
            size,
          ),
          latitude: (p) => p.$1,
          longitude: (p) => p.$2,
        );

    test('merges neighbours when zoomed out, leaves out the far side', () {
      final c = clusters(1);
      expect(c, hasLength(1));
      expect(c.single.members, hasLength(2));
      expect(c.single.opacity, 1);
    });

    test('separates them once zoomed in far enough', () {
      expect(clusters(GlobeCamera.maxZoom), hasLength(2));
    });
  });

  test('paints the full outlines from any viewpoint without throwing', () {
    final outlines = _outlinesFromDisk();
    final camera = ValueNotifier(const GlobeCamera(latitude: 0, longitude: 0));
    final painter = GlobePainter(
      camera: camera,
      outlines: outlines,
      visitedCountryCodes: const {'NL', 'FR', 'AQ', 'RU'},
    );
    for (final lat in [-80.0, -45.0, 0.0, 45.0, 80.0]) {
      for (var lon = -180.0; lon < 180; lon += 45) {
        for (final zoom in [1.0, 6.0, GlobeCamera.maxZoom]) {
          camera.value = GlobeCamera(latitude: lat, longitude: lon, zoom: zoom);
          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), const Size(390, 600));
          recorder.endRecording().dispose();
        }
      }
    }
    camera.dispose();
  });

  group('GlobeView', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<MapPin> pins,
      required ValueChanged<MapPin> onPinTap,
      ValueChanged<List<MapPin>>? onClusterTap,
      GlobeController? controller,
    }) async {
      final c = controller ?? GlobeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobeView(
              controller: c,
              pins: pins,
              visitedCountryCodes: const {'NL'},
              onPinTap: onPinTap,
              onClusterTap: onClusterTap ?? (_) {},
              autoRotate: false,
              outlines: Future.value(_outlinesFromDisk()),
            ),
          ),
        ),
      );
      await tester.pump();
      c.showWholeGlobeAround([for (final p in pins) (p.latitude, p.longitude)]);
      await tester.pump();
    }

    testWidgets('a pin tap flies to the pin, then hands it over', (
      tester,
    ) async {
      final controller = GlobeController();
      final pin = _pin('r1', 52.37, 4.9);
      MapPin? tapped;
      await pump(
        tester,
        pins: [pin],
        onPinTap: (p) => tapped = p,
        controller: controller,
      );
      await tester.tap(find.byType(VenuePin));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped, isNull, reason: 'hands over only once the flight ends');
      await flyAndSettle(tester);
      expect(tapped, same(pin));
      expect(controller.camera!.latitude, closeTo(52.37, 1e-6));
      expect(controller.camera!.longitude, closeTo(4.9, 1e-6));
      expect(controller.camera!.zoom, greaterThanOrEqualTo(4));
    });

    testWidgets('places at one address stay merged and list together', (
      tester,
    ) async {
      final pins = [_pin('r1', 52.37, 4.9), _pin('r2', 52.37, 4.9)];
      List<MapPin>? listed;
      await pump(
        tester,
        pins: pins,
        onPinTap: (_) {},
        onClusterTap: (p) => listed = p,
      );
      expect(find.byType(VenuePin), findsNothing);
      expect(find.byType(GlobeClusterPin), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byType(GlobeClusterPin));
      await flyAndSettle(tester);
      expect(listed, pins);
    });

    testWidgets('a merged marker that zooming separates flies in instead', (
      tester,
    ) async {
      final controller = GlobeController();
      final pins = [_pin('r1', 52.37, 4.90), _pin('r2', 52.0, 4.4)];
      List<MapPin>? listed;
      await pump(
        tester,
        pins: pins,
        onPinTap: (_) {},
        onClusterTap: (p) => listed = p,
        controller: controller,
      );
      await tester.tap(find.byType(GlobeClusterPin));
      await flyAndSettle(tester);
      expect(listed, isNull);
      expect(find.byType(VenuePin), findsNWidgets(2));
    });

    testWidgets('pinching out zooms in', (tester) async {
      final controller = GlobeController();
      await pump(
        tester,
        pins: const [],
        onPinTap: (_) {},
        controller: controller,
      );
      final centre = tester.getCenter(find.byType(GlobeView));
      final a = await tester.startGesture(centre - const Offset(20, 0));
      final b = await tester.startGesture(
        centre + const Offset(20, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        await a.moveTo(centre - Offset(20.0 + i * 20, 0));
        await b.moveTo(centre + Offset(20.0 + i * 20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump();
      expect(controller.camera!.zoom, greaterThan(3));
    });

    testWidgets('dragging spins the globe', (tester) async {
      final controller = GlobeController();
      await pump(
        tester,
        pins: const [],
        onPinTap: (_) {},
        controller: controller,
      );
      final before = controller.camera!.longitude;
      await tester.drag(find.byType(GlobeView), const Offset(-120, 0));
      await flyAndSettle(tester);
      expect(
        wrapLongitude(controller.camera!.longitude - before),
        greaterThan(0),
        reason: 'dragging left turns the globe east',
      );
    });
  });
}
