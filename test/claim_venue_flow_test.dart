// Exercises the venue-claim flow end to end (ClaimVenueScreen ->
// ClaimVenueDetailsScreen -> confirmation) via the DI seams both screens
// expose, mirroring this app's established convention of injecting fake
// repositories rather than hitting live Supabase in a widget test.
//
// Every fake repository below still has to extend a real repository class
// (RestaurantRepository/HotelRepository/PrivateChefRepository/
// VenueClaimRepository), since the DI seam's declared type is the concrete
// repository, not an interface — and each of those classes' constructor
// requires a SupabaseClient. A bare `SupabaseClient(url, key)` constructor
// call (NOT Supabase.initialize(), which adds Flutter-specific session
// persistence requiring platform channels) never makes a network call or
// touches a platform channel at construction time, so it's a safe
// placeholder here — every method that would actually use it is overridden
// below and never calls super.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/data/repositories/hotel_repository.dart';
import 'package:michelin_passport/data/repositories/private_chef_repository.dart';
import 'package:michelin_passport/data/repositories/restaurant_repository.dart';
import 'package:michelin_passport/data/repositories/venue_claim_repository.dart';
import 'package:michelin_passport/features/claims/claim_venue_details_screen.dart';
import 'package:michelin_passport/features/claims/claim_venue_screen.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:michelin_passport/models/venue_claim.dart';

SupabaseClient _dummyClient() => SupabaseClient(
  'https://test.supabase.co',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeRestaurantRepository extends RestaurantRepository {
  _FakeRestaurantRepository() : super(_dummyClient());

  @override
  Future<List<Restaurant>> search(
    String query, {
    int? stars,
    bool starsOnly = false,
    bool worlds50BestOnly = false,
    bool hallOfFameOnly = false,
    String? countryCode,
  }) async {
    if (!query.toLowerCase().contains('flore')) return [];
    return [
      Restaurant.fromJson({'id': 'r1', 'name': 'Flore Amsterdam', 'city_name': 'Amsterdam'}),
    ];
  }
}

class _FakeHotelRepository extends HotelRepository {
  _FakeHotelRepository() : super(_dummyClient());

  @override
  Future<List<Hotel>> search(
    String query, {
    int? keys,
    bool keysOnly = false,
    bool worlds50BestOnly = false,
    String? countryCode,
  }) async => [];
}

class _FakePrivateChefRepository extends PrivateChefRepository {
  _FakePrivateChefRepository() : super(_dummyClient());

  @override
  Future<List<PrivateChef>> search(String query) async => [];
}

typedef _SubmitCall =
    ({
      VenueClaimVenueType venueType,
      String venueId,
      VenueClaimRole role,
      String businessEmail,
      String phone,
      String? notes,
    });

class _FakeVenueClaimRepository extends VenueClaimRepository {
  _FakeVenueClaimRepository({this.onSubmit, this.throwing}) : super(_dummyClient());

  final void Function(_SubmitCall call)? onSubmit;
  final Object? throwing;

  @override
  Future<void> submitClaim({
    required VenueClaimVenueType venueType,
    required String venueId,
    required VenueClaimRole role,
    required String businessEmail,
    required String phone,
    String? notes,
  }) async {
    if (throwing != null) throw throwing!;
    onSubmit?.call((
      venueType: venueType,
      venueId: venueId,
      role: role,
      businessEmail: businessEmail,
      phone: phone,
      notes: notes,
    ));
  }
}

ClaimVenueDetailsScreen _details(VenueClaimRepository claimRepo) => ClaimVenueDetailsScreen(
  venueType: VenueClaimVenueType.restaurant,
  venueId: 'r1',
  venueName: 'Flore Amsterdam',
  venueCity: 'Amsterdam',
  claimRepo: claimRepo,
);

Future<void> _pumpClaimScreen(
  WidgetTester tester, {
  required RestaurantRepository restaurantRepo,
  required HotelRepository hotelRepo,
  required PrivateChefRepository privateChefRepo,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ClaimVenueScreen(
        restaurantRepo: restaurantRepo,
        hotelRepo: hotelRepo,
        privateChefRepo: privateChefRepo,
      ),
    ),
  );
}

void main() {
  group('ClaimVenueScreen', () {
    testWidgets('renders all three venue-type choices', (tester) async {
      await _pumpClaimScreen(
        tester,
        restaurantRepo: _FakeRestaurantRepository(),
        hotelRepo: _FakeHotelRepository(),
        privateChefRepo: _FakePrivateChefRepository(),
      );
      expect(find.text('Restaurant'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Private chef'), findsOneWidget);
    });

    testWidgets('typing a matching query shows the result, tapping it '
        'pushes ClaimVenueDetailsScreen with the venue name and city', (
      tester,
    ) async {
      await _pumpClaimScreen(
        tester,
        restaurantRepo: _FakeRestaurantRepository(),
        hotelRepo: _FakeHotelRepository(),
        privateChefRepo: _FakePrivateChefRepository(),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Flore');
      // The search is debounced by 300ms.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text('Flore Amsterdam'), findsOneWidget);
      expect(find.text('Amsterdam'), findsOneWidget);

      await tester.tap(find.text('Flore Amsterdam'));
      await tester.pumpAndSettle();
      // ClaimVenueDetailsScreen shows the venue name as its own heading.
      expect(find.text('Flore Amsterdam'), findsOneWidget);
      expect(find.text('Amsterdam'), findsOneWidget);
      expect(find.text('WHAT HAPPENS NEXT'), findsOneWidget);
    });

    testWidgets('a query with no matches shows "Report it as missing", '
        'which opens the existing missing-listing sheet', (tester) async {
      await _pumpClaimScreen(
        tester,
        restaurantRepo: _FakeRestaurantRepository(),
        hotelRepo: _FakeHotelRepository(),
        privateChefRepo: _FakePrivateChefRepository(),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Nonexistent Place');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text("We couldn't find that."), findsOneWidget);
      expect(find.text('Report it as missing'), findsOneWidget);

      await tester.tap(find.text('Report it as missing'));
      await tester.pumpAndSettle();
      // The missing-listing sheet's own type row + the search query carried
      // over as its pre-filled name (findsWidgets, not findsOneWidget — the
      // claim screen's own search field behind the sheet still shows the
      // same typed text).
      expect(find.text('Nonexistent Place'), findsWidgets);
      expect(find.text('Send report'), findsOneWidget);
    });
  });

  group('ClaimVenueDetailsScreen (pumped directly with a fixed venue, '
      'as ClaimVenueScreen would push it)', () {
    testWidgets('submitting with no role selected shows an error and '
        'never calls the repository', (tester) async {
      var calls = 0;
      final claimRepo = _FakeVenueClaimRepository(onSubmit: (_) => calls++);
      await tester.pumpWidget(MaterialApp(home: _details(claimRepo)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pump();
      expect(find.text('Choose your role'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a fully valid submission calls the repository with the '
        'chosen role/email/phone/notes, then shows the confirmation', (
      tester,
    ) async {
      _SubmitCall? received;
      final claimRepo = _FakeVenueClaimRepository(onSubmit: (call) => received = call);
      await tester.pumpWidget(MaterialApp(home: _details(claimRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Owner'));
      await tester.enterText(find.byType(TextFormField).at(0), 'owner@flore.example');
      await tester.enterText(find.byType(TextFormField).at(1), '+31 6 1234 5678');
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(received?.venueType, VenueClaimVenueType.restaurant);
      expect(received?.venueId, 'r1');
      expect(received?.role, VenueClaimRole.owner);
      expect(received?.businessEmail, 'owner@flore.example');
      expect(received?.phone, '+31 6 1234 5678');

      expect(find.text('Request sent'), findsOneWidget);
      expect(find.textContaining('Flore Amsterdam'), findsOneWidget);
    });

    testWidgets('a duplicate-claim StateError from the repository shows '
        'its message inline rather than the generic fallback', (tester) async {
      final claimRepo = _FakeVenueClaimRepository(
        throwing: StateError('You already have a claim in progress for this venue.'),
      );
      await tester.pumpWidget(MaterialApp(home: _details(claimRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Owner'));
      await tester.enterText(find.byType(TextFormField).at(0), 'owner@flore.example');
      await tester.enterText(find.byType(TextFormField).at(1), '+31 6 1234 5678');
      await tester.ensureVisible(find.text('Submit request'));
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      expect(
        find.text('You already have a claim in progress for this venue.'),
        findsOneWidget,
      );
      expect(find.text('Request sent'), findsNothing);
    });
  });
}
