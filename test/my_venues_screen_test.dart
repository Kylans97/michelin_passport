// Covers MyVenuesScreen via its own DI seam (repository), mirroring the
// exact fake-repository-over-a-dummy-SupabaseClient convention
// claim_venue_flow_test.dart already established for this app's claims
// feature — MyVenuesScreen itself never touches Supabase.instance.client
// when a fake is injected (Dart's `??` short-circuits before the getter
// is ever read), so no Supabase.initialize() is needed here either.
//
// Navigation is verified structurally only (a NavigatorObserver proves
// exactly one push happens per tap, for each of the three venue types,
// without throwing) rather than by letting the pushed route actually
// build: tapping a row now opens VenueManagementScreen (not each type's
// public detail screen directly — see my_venues_screen.dart's own doc
// comment for that change), which itself constructs a repository
// against Supabase.instance.client in its own initState when no
// aboutRepo is injected — same "throws with no Supabase session
// initialized" limitation passport_cards_test.dart already documents for
// this exact situation. NavigatorObserver.didPush fires synchronously,
// before the pushed widget is ever built, so this is safe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/venue_manager_repository.dart';
import 'package:michelin_passport/features/profile/my_venues_screen.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/restaurant.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeVenueManagerRepository extends VenueManagerRepository {
  _FakeVenueManagerRepository(this._result) : super(_dummyClient());
  _FakeVenueManagerRepository.error() : _result = null, super(_dummyClient());

  final List<ManagedVenue>? _result;

  @override
  Future<List<ManagedVenue>> loadMyManagedVenues() async {
    if (_result == null) throw Exception('load failed');
    return _result;
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

Restaurant _restaurant({String id = 'r1', String name = 'Flore Amsterdam', String city = 'Amsterdam'}) =>
    Restaurant.fromJson({'id': id, 'name': name, 'city_name': city});

Hotel _hotel({String id = 'h1', String name = 'Hôtel de la Paix', String city = 'Geneva'}) =>
    Hotel.fromJson({'id': id, 'name': name, 'city_name': city});

PrivateChef _chef({String id = 'c1', String name = 'Chef Amara', String? city = 'Lisbon'}) =>
    PrivateChef.fromJson({'id': id, 'display_name': name, 'home_city': city});

Future<void> _pump(
  WidgetTester tester,
  VenueManagerRepository repository, {
  NavigatorObserver? observer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [?observer],
      home: MyVenuesScreen(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MyVenuesScreen — loading/error/empty', () {
    testWidgets('shows a loading spinner before the future resolves', (
      tester,
    ) async {
      final repo = _FakeVenueManagerRepository([_managedRestaurant()]);
      await tester.pumpWidget(MaterialApp(home: MyVenuesScreen(repository: repo)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a calm error message on failure, never a raw '
        'exception, with a way to retry', (tester) async {
      await _pump(tester, _FakeVenueManagerRepository.error());
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('an empty list is handled gracefully — not reachable from '
        'the UI (Profile hides the entry point), but must not crash if '
        'access is revoked while this screen is already open', (tester) async {
      await _pump(tester, _FakeVenueManagerRepository(const []));
      expect(find.textContaining("don't manage any venues"), findsOneWidget);
    });
  });

  group('MyVenuesScreen — populated states', () {
    testWidgets('one venue shows its name, city, and type', (tester) async {
      await _pump(tester, _FakeVenueManagerRepository([_managedRestaurant()]));
      expect(find.text('Flore Amsterdam'), findsOneWidget);
      expect(find.text('Amsterdam · Restaurant'), findsOneWidget);
    });

    testWidgets('several venues of the same type all render', (tester) async {
      await _pump(
        tester,
        _FakeVenueManagerRepository([
          ManagedRestaurant(_restaurant(id: 'r1', name: 'Flore Amsterdam')),
          ManagedRestaurant(_restaurant(id: 'r2', name: 'Aan de Poel', city: 'Amstelveen')),
        ]),
      );
      expect(find.text('Flore Amsterdam'), findsOneWidget);
      expect(find.text('Aan de Poel'), findsOneWidget);
      expect(find.text('Amstelveen · Restaurant'), findsOneWidget);
    });

    testWidgets('mixed types (restaurant, hotel, private chef) all render '
        'with their own type label', (tester) async {
      await _pump(
        tester,
        _FakeVenueManagerRepository([
          ManagedRestaurant(_restaurant()),
          ManagedHotel(_hotel()),
          ManagedPrivateChef(_chef()),
        ]),
      );
      expect(find.text('Amsterdam · Restaurant'), findsOneWidget);
      expect(find.text('Geneva · Hotel'), findsOneWidget);
      expect(find.text('Lisbon · Private chef'), findsOneWidget);
    });

    testWidgets('a private chef with no home city set still renders, '
        'falling back to just the type label', (tester) async {
      await _pump(
        tester,
        _FakeVenueManagerRepository([ManagedPrivateChef(_chef(city: null))]),
      );
      expect(find.text('Chef Amara'), findsOneWidget);
      expect(find.text('Private chef'), findsOneWidget);
    });
  });

  group('MyVenuesScreen — tapping a row navigates', () {
    testWidgets('tapping a restaurant row pushes exactly one route, '
        'without throwing', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await _pump(
        tester,
        _FakeVenueManagerRepository([ManagedRestaurant(_restaurant())]),
        observer: observer,
      );
      observer.pushed.clear(); // drop MaterialApp's own initial-route push
      await tester.tap(find.text('Flore Amsterdam'));
      expect(observer.pushed.length, 1);
    });

    testWidgets('tapping a hotel row pushes exactly one route, without '
        'throwing', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await _pump(
        tester,
        _FakeVenueManagerRepository([ManagedHotel(_hotel())]),
        observer: observer,
      );
      observer.pushed.clear();
      await tester.tap(find.text('Hôtel de la Paix'));
      expect(observer.pushed.length, 1);
    });

    testWidgets('tapping a private chef row pushes exactly one route, '
        'without throwing', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await _pump(
        tester,
        _FakeVenueManagerRepository([ManagedPrivateChef(_chef())]),
        observer: observer,
      );
      observer.pushed.clear();
      await tester.tap(find.text('Chef Amara'));
      expect(observer.pushed.length, 1);
    });
  });
}

ManagedRestaurant _managedRestaurant() => ManagedRestaurant(_restaurant());
