import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/venue_contact_repository.dart';
import 'package:michelin_passport/features/profile/venue_contact_screen.dart';
import 'package:michelin_passport/models/managed_venue.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRepo extends VenueContactRepository {
  _FakeRepo(this.current)
    : super(
        SupabaseClient(
          'https://example.invalid',
          'anon',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  VenueContact current;
  final saved = <(String, String, String)>[];

  @override
  Future<VenueContact> load({
    required String venueType,
    required String venueId,
  }) async => current;

  @override
  Future<void> save({
    required String venueType,
    required String venueId,
    required String website,
    required String phone,
  }) async => saved.add((venueType, website, phone));
}

void main() {
  group('venueWebsiteProblem and venuePhoneProblem', () {
    test('take full addresses and ordinary numbers, and empty to clear', () {
      for (final ok in [
        '',
        'https://www.flore.example',
        'http://flore.example/en?x=1',
      ]) {
        expect(venueWebsiteProblem(ok), isNull, reason: ok);
      }
      for (final ok in [
        '',
        '+31 20 123 4567',
        '(020) 123-4567',
        '020.123.45.67',
      ]) {
        expect(venuePhoneProblem(ok), isNull, reason: ok);
      }
    });

    test('refuse what the database would refuse', () {
      for (final bad in [
        'www.flore.example',
        'flore',
        'javascript:alert(1)',
        'https://flore',
      ]) {
        expect(venueWebsiteProblem(bad), isNotNull, reason: bad);
      }
      for (final bad in ['12345', 'call me', '+31 20 123 4567 ext 9']) {
        expect(venuePhoneProblem(bad), isNotNull, reason: bad);
      }
    });
  });

  group('VenueContactScreen', () {
    Future<_FakeRepo> pump(
      WidgetTester tester,
      ManagedVenue venue,
      VenueContact current,
    ) async {
      final repo = _FakeRepo(current);
      await tester.pumpWidget(
        MaterialApp(
          home: VenueContactScreen(venue: venue, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    final restaurant = ManagedRestaurant(
      Restaurant.fromJson({'id': 'r1', 'name': 'Flore'}),
    );

    testWidgets('starts from what the page shows and saves both at once', (
      tester,
    ) async {
      final repo = await pump(
        tester,
        restaurant,
        const VenueContact(
          website: 'https://old.example',
          phone: '+31 20 000 0000',
        ),
      );
      expect(find.text('https://old.example'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://www.new.example',
      );
      await tester.enterText(find.byType(TextField).at(1), '+31 20 123 4567');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved, [
        ('restaurant', 'https://www.new.example', '+31 20 123 4567'),
      ]);
      expect(find.text('Saved. Your page shows it now.'), findsOneWidget);
    });

    testWidgets('a malformed website is pointed out and nothing is sent', (
      tester,
    ) async {
      final repo = await pump(tester, restaurant, const VenueContact());
      await tester.enterText(find.byType(TextField).at(0), 'www.new.example');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(find.textContaining('Enter the full address'), findsOneWidget);
    });

    testWidgets('a private chef has a website only', (tester) async {
      await pump(
        tester,
        ManagedPrivateChef(
          PrivateChef.fromJson({'id': 'c1', 'display_name': 'Chef'}),
        ),
        const VenueContact(),
      );
      expect(find.text('WEBSITE'), findsOneWidget);
      expect(find.text('PHONE'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    test('the landing summary', () {
      expect(
        VenueContactScreen.summary(const VenueContact(), hasPhone: true),
        'Not on your page yet',
      );
      expect(
        VenueContactScreen.summary(
          const VenueContact(website: 'https://x.example', phone: '1234567'),
          hasPhone: true,
        ),
        'Website and phone on your page',
      );
      expect(
        VenueContactScreen.summary(
          const VenueContact(phone: '1234567'),
          hasPhone: true,
        ),
        'Phone on your page',
      );
    });
  });
}
