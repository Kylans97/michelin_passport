// Friends in the Cellar (product owner, 2026-11-24): a friend's Cellar is
// a tab on their profile, read only; "Share my Cellar with friends" is one
// switch for the whole Cellar (20261101730000); Taste became Palate, with
// the friend's favourites and the cuisines they return to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:michelin_passport/data/repositories/visit_wine_repository.dart';
import 'package:michelin_passport/features/friends/friend_profile_screen.dart';
import 'package:michelin_passport/features/friends/friends_together_data.dart';
import 'package:michelin_passport/features/passport/widgets/cellar_body.dart';
import 'package:michelin_passport/features/profile/privacy_settings_screen.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/visit.dart';
import 'package:michelin_passport/models/visit_wine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers from memory; never touches the network.
class _FakeWines extends VisitWineRepository {
  _FakeWines({required this.visible, this.wines = const []})
    : super(Supabase.instance.client);

  final bool visible;
  final List<CellarWine> wines;
  final loadedFor = <String>[];

  @override
  Future<bool> canSeeCellar(String ownerId) async => visible;

  @override
  Future<List<CellarWine>> loadCellar(String userId) async {
    loadedFor.add(userId);
    return wines;
  }
}

const _wines = [
  CellarWine(
    wine: VisitWine(
      id: 'w1',
      producer: 'Quinta do Crasto',
      wineName: 'Vinha Maria Teresa',
      vintage: 2019,
      verdict: WineVerdict.again,
      tastingNote: 'Dark cherry, still young.',
    ),
    visitId: 'v1',
    date: null,
  ),
  CellarWine(
    wine: VisitWine(
      id: 'w2',
      producer: 'Egly Ouriet',
      wineName: 'Brut Tradition',
      nonVintage: true,
      setting: WineSetting.home,
    ),
  ),
];

Restaurant _restaurant(String id, String? cuisine) => Restaurant(
  id: id,
  restaurantCode: id,
  name: 'Restaurant $id',
  michelinStars: 1,
  inclusionReason: 'michelin_star',
  cityName: 'Antwerp',
  countryCode: 'BE',
  countryName: 'Belgium',
  flagEmoji: '',
  address: '1 Test Street',
  cuisineNames: cuisine,
);

FriendVenueVisit _fv(Restaurant r, String visitId) => FriendVenueVisit(
  RestaurantVenue(r),
  Visit(
    id: visitId,
    userId: 'anna',
    entityType: 'restaurant',
    entityId: r.id,
    visitedOn: DateTime(2026, 10, 12),
  ),
);

Widget _friendCellar(_FakeWines repo) => MaterialApp(
  home: Scaffold(
    body: CellarBody(
      repository: repo,
      ownerId: 'anna',
      ownerFirstName: 'Anna',
      visitPlaceById: const {'v1': 'De Librije'},
    ),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient(
        (request) async => http.Response('{}', 200, request: request),
      ),
    );
  });

  group("A friend's Cellar tab", () {
    testWidgets('shows their wines read only, with where they were drunk', (
      tester,
    ) async {
      final repo = _FakeWines(visible: true, wines: _wines);
      await tester.pumpWidget(_friendCellar(repo));
      await tester.pumpAndSettle();

      expect(repo.loadedFor, ['anna']);
      expect(find.text('Vinha Maria Teresa'), findsOneWidget);
      expect(find.text('Dark cherry, still young.'), findsOneWidget);
      expect(find.text('At De Librije'), findsOneWidget);
      expect(find.text('Brut Tradition'), findsOneWidget);
      // The same filter as your own Cellar.
      expect(find.text('All wines'), findsOneWidget);
      // Read only: no adding, and a wine opens nothing.
      expect(find.text('Add a wine'), findsNothing);
      await tester.tap(find.text('Vinha Maria Teresa'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      // Your own Cellar's lines stay out of a friend's.
      expect(find.textContaining('Your own notes'), findsNothing);
      expect(find.textContaining('Friends can see your Cellar'), findsNothing);
    });

    testWidgets('a private Cellar shows only that, and loads no wines', (
      tester,
    ) async {
      final repo = _FakeWines(visible: false, wines: _wines);
      await tester.pumpWidget(_friendCellar(repo));
      await tester.pumpAndSettle();

      expect(find.text("Anna's Cellar is private."), findsOneWidget);
      expect(
        find.text('The wines on visits they share still show on those visits.'),
        findsOneWidget,
      );
      expect(repo.loadedFor, isEmpty);
      expect(find.text('Vinha Maria Teresa'), findsNothing);
    });

    testWidgets('an empty Cellar says so, without Add a wine', (tester) async {
      await tester.pumpWidget(_friendCellar(_FakeWines(visible: true)));
      await tester.pumpAndSettle();

      expect(find.text("Anna hasn't shared any wines yet."), findsOneWidget);
      expect(find.text('Add a wine'), findsNothing);
    });
  });

  group('Share my Cellar with friends', () {
    Widget wrap({
      required Future<bool?> Function() load,
      Future<void> Function(bool)? set,
    }) => MaterialApp(
      home: PrivacySettingsScreen(
        loadDiscoverable: () async => true,
        setDiscoverable: (_) async {},
        loadCellarShared: load,
        setCellarShared: set ?? (_) async {},
      ),
    );

    testWidgets('shows the switch with its value and saves a change', (
      tester,
    ) async {
      bool? saved;
      await tester.pumpWidget(
        wrap(load: () async => true, set: (v) async => saved = v),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share my Cellar with friends'), findsOneWidget);
      expect(find.text('Wines on a visit follow that visit.'), findsOneWidget);
      final cellarSwitch = find.byType(Switch).last;
      expect(tester.widget<Switch>(cellarSwitch).value, isTrue);

      await tester.tap(cellarSwitch);
      await tester.pumpAndSettle();
      expect(saved, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);
    });

    testWidgets('stays out before the migration (null)', (tester) async {
      await tester.pumpWidget(wrap(load: () async => null));
      await tester.pumpAndSettle();

      expect(find.text('Share my Cellar with friends'), findsNothing);
      expect(find.text('Allow members to find me'), findsOneWidget);
    });

    testWidgets('a failed save keeps the old value and says so', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(load: () async => true, set: (_) async => throw Exception()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch).last).value, isTrue);
      expect(find.text('Could not update. Please try again.'), findsOneWidget);
    });
  });

  group('Palate', () {
    test('topCuisines: once per restaurant, at least two places', () {
      final visits = [
        _fv(_restaurant('a', 'Creative, Modern Cuisine'), 'v1'),
        _fv(_restaurant('a', 'Creative, Modern Cuisine'), 'v2'),
        _fv(_restaurant('b', 'Creative'), 'v3'),
        _fv(_restaurant('c', 'Japanese, Sushi'), 'v4'),
        _fv(_restaurant('d', 'Japanese'), 'v5'),
        _fv(_restaurant('e', 'Nordic'), 'v6'),
        _fv(_restaurant('f', null), 'v7'),
      ];
      // Nordic has one place only; two visits to "a" count once.
      expect(topCuisines(visits), ['Creative', 'Japanese']);
    });

    test('listInSentence', () {
      expect(listInSentence(const []), '');
      expect(listInSentence(const ['Nordic']), 'Nordic');
      expect(listInSentence(const ['Nordic', 'Creative']), 'Nordic and Creative');
      expect(
        listInSentence(const ['Nordic', 'Creative', 'Japanese']),
        'Nordic, Creative and Japanese',
      );
    });
  });
}
