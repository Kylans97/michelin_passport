// Events V2 Near Me Phase N2.3 — EventLocationControl
// (lib/features/events/widgets/event_location_control.dart) and the
// Events-specific Location sheet it opens
// (lib/features/events/widgets/event_location_sheet.dart). Pumps the REAL
// widgets — same established pattern as event_date_control_test.dart —
// with a hand-rolled fake CurrentLocationProvider (never geolocator/
// platform code, never a mocking package). EventsScreen itself is not
// pumped here (it eagerly constructs Supabase-backed repositories in
// initState, same limitation as every other screen in this app — see
// friend_profile_going_section_test.dart's own doc comment for the
// established precedent); EventLocationControl's own onChanged contract
// is EventsScreen's entire integration surface with this new UI, so
// proving it here proves the wiring.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/current_location_provider.dart';
import 'package:michelin_passport/features/events/location_settings_opener.dart';
import 'package:michelin_passport/features/events/widgets/event_location_control.dart';
import 'package:michelin_passport/models/event_location_context.dart';
import 'package:michelin_passport/models/event_near_me_location.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _nl = VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱');
const _fr = VenueCountry(name: 'France', code: 'FR', flag: '🇫🇷');
const _countries = [_nl, _fr];

class _FakeLocationProvider implements CurrentLocationProvider {
  int callCount = 0;
  final List<Completer<CurrentLocationResult>> _pending = [];

  @override
  Future<CurrentLocationResult> getCurrentLocation() {
    callCount++;
    final completer = Completer<CurrentLocationResult>();
    _pending.add(completer);
    return completer.future;
  }

  void completeLatest(CurrentLocationResult result) {
    _pending.last.complete(result);
  }
}

// This N2.3-scoped file never exercises a failure that shows a Settings
// action, so this fake only needs to satisfy the interface — see
// event_location_settings_test.dart (N2.4) for the fake that actually
// asserts call counts/results on these two methods.
class _FakeSettingsOpener implements LocationSettingsOpener {
  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

Future<void> _pumpAndOpen(
  WidgetTester tester, {
  required EventLocationContext location,
  required CurrentLocationProvider provider,
  List<VenueCountry> countries = _countries,
  ValueChanged<EventLocationContext>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EventLocationControl(
          location: location,
          countries: countries,
          locationProvider: provider,
          settingsOpener: _FakeSettingsOpener(),
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byType(EventLocationControl));
  await tester.pumpAndSettle();
}

void main() {
  group('Location surface', () {
    testWidgets('tapping the control opens the Events-specific Location UI — '
        'Near me visible, existing Country choices reachable', (tester) async {
      final provider = _FakeLocationProvider();
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.any,
        provider: provider,
      );

      // The closed trigger's own label also reads "Location" while
      // EventLocationContext.any is active, alongside the sheet's own
      // header — both are genuinely present, so this only proves the
      // sheet opened, not an exact count.
      expect(find.text('Location'), findsWidgets);
      expect(find.text('Near me'), findsOneWidget);
      expect(find.text('All locations'), findsOneWidget);
      expect(find.text('Netherlands'), findsOneWidget);
      expect(find.text('France'), findsOneWidget);
    });

    testWidgets('the closed control label reflects Near-me state', (
      tester,
    ) async {
      final provider = _FakeLocationProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventLocationControl(
              location: EventLocationContext.nearMe(
                EventNearMeLocation(
                  coordinate: GeoCoordinate(latitude: 52.1, longitude: 5.1),
                ),
              ),
              countries: _countries,
              locationProvider: provider,
              settingsOpener: _FakeSettingsOpener(),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Near me'), findsOneWidget);
    });
  });

  group('Explicit activation — location is never requested automatically', () {
    testWidgets('opening the sheet does not call CurrentLocationProvider', (
      tester,
    ) async {
      final provider = _FakeLocationProvider();
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.any,
        provider: provider,
      );
      expect(provider.callCount, 0);
    });

    testWidgets('tapping a Country does not call CurrentLocationProvider', (
      tester,
    ) async {
      final provider = _FakeLocationProvider();
      EventLocationContext? received;
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.any,
        provider: provider,
        onChanged: (v) => received = v,
      );
      await tester.tap(find.text('Netherlands'));
      await tester.pumpAndSettle();

      expect(provider.callCount, 0);
      expect(received, EventLocationContext.country(_nl));
    });

    testWidgets('tapping Near me calls CurrentLocationProvider exactly once', (
      tester,
    ) async {
      final provider = _FakeLocationProvider();
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.any,
        provider: provider,
      );
      await tester.tap(find.text('Near me'));
      await tester.pump();

      expect(provider.callCount, 1);
    });
  });

  group('Loading state', () {
    testWidgets(
      'Near me shows a loading indicator while the provider Future is '
      'unresolved',
      (tester) async {
        final provider = _FakeLocationProvider();
        await _pumpAndOpen(
          tester,
          location: EventLocationContext.any,
          provider: provider,
        );
        await tester.tap(find.text('Near me'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('duplicate concurrent Near-me taps are prevented', (
      tester,
    ) async {
      final provider = _FakeLocationProvider();
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.any,
        provider: provider,
      );
      await tester.tap(find.text('Near me'));
      await tester.pump();
      // Second tap while the first request is still unresolved — the
      // Near-me row's own onTap is null while resolving (see
      // event_location_sheet.dart's _NearMeTile), so this tap is a no-op.
      await tester.tap(find.text('Near me'), warnIfMissed: false);
      await tester.pump();

      expect(provider.callCount, 1);
    });
  });

  group('Success', () {
    testWidgets(
      'a successful resolution activates Near-me context with the fixed '
      'default radius, reports it via onChanged, and no stale Country '
      'state survives',
      (tester) async {
        final provider = _FakeLocationProvider();
        EventLocationContext? received;
        await _pumpAndOpen(
          tester,
          location: EventLocationContext.country(_nl),
          provider: provider,
          onChanged: (v) => received = v,
        );
        await tester.tap(find.text('Near me'));
        await tester.pump();

        final coordinate = GeoCoordinate(latitude: 52.37, longitude: 4.9);
        provider.completeLatest(CurrentLocationSuccess(coordinate));
        await tester.pumpAndSettle();

        expect(received, isNotNull);
        expect(received!.isNearMe, isTrue);
        expect(received!.isCountry, isFalse);
        expect(received!.country, isNull);
        expect(received!.nearMe!.coordinate, coordinate);
        expect(received!.nearMe!.radiusKm, defaultEventNearMeRadiusKm);
        // The sheet itself closes on success.
        expect(find.text('Location'), findsNothing);
      },
    );
  });

  group('Country <-> Near-me replacement and All-locations clearing', () {
    testWidgets('Near me active, selecting a Country replaces it cleanly', (
      tester,
    ) async {
      final provider = _FakeLocationProvider();
      EventLocationContext? received;
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.nearMe(
          EventNearMeLocation(
            coordinate: GeoCoordinate(latitude: 52.1, longitude: 5.1),
          ),
        ),
        provider: provider,
        onChanged: (v) => received = v,
      );
      await tester.tap(find.text('France'));
      await tester.pumpAndSettle();

      expect(received, EventLocationContext.country(_fr));
      expect(received!.isNearMe, isFalse);
      expect(provider.callCount, 0);
    });

    testWidgets('"All locations" produces the exact same cleared state the '
        'existing Country flow already produced', (tester) async {
      final provider = _FakeLocationProvider();
      EventLocationContext? received;
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.country(_nl),
        provider: provider,
        onChanged: (v) => received = v,
      );
      await tester.tap(find.text('All locations'));
      await tester.pumpAndSettle();

      expect(received, EventLocationContext.any);
      expect(received!.isAny, isTrue);
    });
  });

  group('Safe failure — general boundary (per-type copy tested in '
      'event_location_settings_test.dart, N2.4)', () {
    testWidgets('a failed resolution stops loading, leaves the previous valid '
        'location unchanged, and never half-activates Near me', (tester) async {
      final provider = _FakeLocationProvider();
      var onChangedCallCount = 0;
      await _pumpAndOpen(
        tester,
        location: EventLocationContext.country(_nl),
        provider: provider,
        onChanged: (_) => onChangedCallCount++,
      );
      await tester.tap(find.text('Near me'));
      await tester.pump();

      provider.completeLatest(
        const CurrentLocationFailure(CurrentLocationFailureType.unavailable),
      );
      await tester.pumpAndSettle();

      expect(onChangedCallCount, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text("We couldn't determine your current location."),
        findsOneWidget,
      );
      // The sheet stays open, offering another attempt.
      expect(find.text('Location'), findsOneWidget);

      await tester.tap(find.text('Near me'));
      await tester.pump();
      expect(provider.callCount, 2);
    });
  });
}
