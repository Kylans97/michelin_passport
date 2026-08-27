// Events V2 Near Me Phase N2.4 — per-CurrentLocationFailureType recovery
// UX inside the Events Location sheet
// (lib/features/events/widgets/event_location_sheet.dart), reached via the
// real EventLocationControl (event_location_control_test.dart's own N2.3
// surface/activation/loading/success/replacement coverage is unchanged and
// untouched here — this file is scoped to N2.4's own failure/recovery
// additions: distinct copy+action per failure type, Settings navigation,
// failure -> failure transition, and failure -> success recovery). Hand-
// rolled fakes only — no real geolocator/platform code, no mocking
// package, no real OS Settings ever opened.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/current_location_provider.dart';
import 'package:michelin_passport/features/events/location_settings_opener.dart';
import 'package:michelin_passport/features/events/widgets/event_location_control.dart';
import 'package:michelin_passport/models/event_location_context.dart';
import 'package:michelin_passport/models/geo_coordinate.dart';
import 'package:michelin_passport/models/venue_country.dart';

const _nl = VenueCountry(name: 'Netherlands', code: 'NL', flag: '🇳🇱');
const _countries = [_nl];

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

class _FakeSettingsOpener implements LocationSettingsOpener {
  int openAppSettingsCallCount = 0;
  int openLocationSettingsCallCount = 0;
  bool openAppSettingsResult = true;
  bool openLocationSettingsResult = true;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCallCount++;
    return openAppSettingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCallCount++;
    return openLocationSettingsResult;
  }
}

Future<void> _pumpOpenAndFail(
  WidgetTester tester, {
  required CurrentLocationFailureType type,
  required _FakeLocationProvider provider,
  required _FakeSettingsOpener settingsOpener,
  EventLocationContext location = EventLocationContext.any,
  ValueChanged<EventLocationContext>? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EventLocationControl(
          location: location,
          countries: _countries,
          locationProvider: provider,
          settingsOpener: settingsOpener,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
  await tester.tap(find.byType(EventLocationControl));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Near me'));
  await tester.pump();
  provider.completeLatest(CurrentLocationFailure(type));
  await tester.pumpAndSettle();
}

void main() {
  group('permissionDenied', () {
    testWidgets('correct message, Try again visible, no Settings action, retry '
        'invokes the provider once more, previous valid location unchanged '
        'until success, retry success activates Near me', (tester) async {
      final provider = _FakeLocationProvider();
      final settingsOpener = _FakeSettingsOpener();
      EventLocationContext? received;
      await _pumpOpenAndFail(
        tester,
        type: CurrentLocationFailureType.permissionDenied,
        provider: provider,
        settingsOpener: settingsOpener,
        location: EventLocationContext.country(_nl),
        onChanged: (v) => received = v,
      );

      expect(
        find.text('Location access is needed to show Events near you.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
      expect(find.text('Open Location Settings'), findsNothing);
      expect(received, isNull); // previous valid location untouched

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(provider.callCount, 2);
      expect(settingsOpener.openAppSettingsCallCount, 0);
      expect(settingsOpener.openLocationSettingsCallCount, 0);

      final coordinate = GeoCoordinate(latitude: 50.85, longitude: 5.69);
      provider.completeLatest(CurrentLocationSuccess(coordinate));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!.isNearMe, isTrue);
      expect(received!.isCountry, isFalse);
    });
  });

  group('permissionDeniedForever', () {
    testWidgets('correct message, Open Settings visible, calls the injected '
        'settings opener exactly once, and does not automatically re-call '
        'the location provider', (tester) async {
      final provider = _FakeLocationProvider();
      final settingsOpener = _FakeSettingsOpener();
      await _pumpOpenAndFail(
        tester,
        type: CurrentLocationFailureType.permissionDeniedForever,
        provider: provider,
        settingsOpener: settingsOpener,
      );

      expect(
        find.text(
          'Location access is turned off for Mantelier. Enable it '
          'in Settings to use Near me.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      final callsBeforeTap = provider.callCount;
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(settingsOpener.openAppSettingsCallCount, 1);
      expect(settingsOpener.openLocationSettingsCallCount, 0);
      expect(provider.callCount, callsBeforeTap);
    });
  });

  group('servicesDisabled', () {
    testWidgets('distinct message, Open Location Settings visible, calls the '
        'injected location-settings opener exactly once, no app-settings '
        'action shown in its place', (tester) async {
      final provider = _FakeLocationProvider();
      final settingsOpener = _FakeSettingsOpener();
      await _pumpOpenAndFail(
        tester,
        type: CurrentLocationFailureType.servicesDisabled,
        provider: provider,
        settingsOpener: settingsOpener,
      );

      expect(
        find.text(
          'Location Services are turned off. Turn them on to use Near me.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Location Settings'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
      expect(find.text('Try again'), findsNothing);

      await tester.tap(find.text('Open Location Settings'));
      await tester.pumpAndSettle();

      expect(settingsOpener.openLocationSettingsCallCount, 1);
      expect(settingsOpener.openAppSettingsCallCount, 0);
    });
  });

  group('unavailable', () {
    testWidgets(
      'generic message, Try again visible, retry invokes the provider '
      'exactly once, no settings action',
      (tester) async {
        final provider = _FakeLocationProvider();
        final settingsOpener = _FakeSettingsOpener();
        await _pumpOpenAndFail(
          tester,
          type: CurrentLocationFailureType.unavailable,
          provider: provider,
          settingsOpener: settingsOpener,
        );

        expect(
          find.text("We couldn't determine your current location."),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Open Settings'), findsNothing);
        expect(find.text('Open Location Settings'), findsNothing);

        expect(provider.callCount, 1);
        await tester.tap(find.text('Try again'));
        await tester.pump();
        expect(provider.callCount, 2);
      },
    );
  });

  group('failure -> different failure transition', () {
    testWidgets(
      'permissionDenied, retried, resolving to permissionDeniedForever — '
      'the UI changes from Try again copy/action to Open Settings '
      'copy/action; the sheet never locks into the first failure state',
      (tester) async {
        final provider = _FakeLocationProvider();
        final settingsOpener = _FakeSettingsOpener();
        await _pumpOpenAndFail(
          tester,
          type: CurrentLocationFailureType.permissionDenied,
          provider: provider,
          settingsOpener: settingsOpener,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Open Settings'), findsNothing);

        await tester.tap(find.text('Try again'));
        await tester.pump();
        provider.completeLatest(
          const CurrentLocationFailure(
            CurrentLocationFailureType.permissionDeniedForever,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Open Settings'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(
          find.text('Location access is needed to show Events near you.'),
          findsNothing,
        );
      },
    );
  });

  group('failure -> success recovery', () {
    testWidgets('failure, then a retry success, closes the sheet and activates '
        'Near-me context, replacing prior Country state only at that '
        'moment', (tester) async {
      final provider = _FakeLocationProvider();
      final settingsOpener = _FakeSettingsOpener();
      EventLocationContext? received;
      await _pumpOpenAndFail(
        tester,
        type: CurrentLocationFailureType.unavailable,
        provider: provider,
        settingsOpener: settingsOpener,
        location: EventLocationContext.country(_nl),
        onChanged: (v) => received = v,
      );
      expect(received, isNull);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      final coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35);
      provider.completeLatest(CurrentLocationSuccess(coordinate));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!.isNearMe, isTrue);
      expect(received!.country, isNull);
      expect(received!.nearMe!.coordinate, coordinate);
      expect(find.text('Location'), findsNothing); // sheet closed
    });
  });

  group('Settings-open failure handling', () {
    testWidgets(
      'openAppSettings returning false shows restrained feedback without '
      'crashing or changing the failure type',
      (tester) async {
        final provider = _FakeLocationProvider();
        final settingsOpener = _FakeSettingsOpener()
          ..openAppSettingsResult = false;
        await _pumpOpenAndFail(
          tester,
          type: CurrentLocationFailureType.permissionDeniedForever,
          provider: provider,
          settingsOpener: settingsOpener,
        );

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text("Couldn't open Settings."), findsOneWidget);
        // Still the same failure type/action — no new domain state.
        expect(find.text('Open Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'openLocationSettings returning false shows restrained feedback '
      'without crashing or changing the failure type',
      (tester) async {
        final provider = _FakeLocationProvider();
        final settingsOpener = _FakeSettingsOpener()
          ..openLocationSettingsResult = false;
        await _pumpOpenAndFail(
          tester,
          type: CurrentLocationFailureType.servicesDisabled,
          provider: provider,
          settingsOpener: settingsOpener,
        );

        await tester.tap(find.text('Open Location Settings'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text("Couldn't open Settings."), findsOneWidget);
        expect(find.text('Open Location Settings'), findsOneWidget);
      },
    );
  });

  group('Duplicate concurrent retry is prevented', () {
    testWidgets('tapping Try again twice before the first resolves only '
        'calls the provider once more', (tester) async {
      final provider = _FakeLocationProvider();
      final settingsOpener = _FakeSettingsOpener();
      await _pumpOpenAndFail(
        tester,
        type: CurrentLocationFailureType.unavailable,
        provider: provider,
        settingsOpener: settingsOpener,
      );
      expect(provider.callCount, 1);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(provider.callCount, 2);
      // The loading state replaces the failure copy/action entirely, so
      // there is no longer a "Try again" to double-tap here — this proves
      // the same _resolving guard from N2.3 still applies to a retry.
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
