// Covers the owner-preview refactor: RestaurantDetailScreen/
// HotelDetailScreen/PrivateChefDetailScreen rendering the REAL screen
// (not a replica) from injected content, and the venue-level loads
// (award history, hosted events, linked hotel/restaurants, chef
// history/education) that must keep loading in preview mode rather than
// being skipped — only personal state (visits/stays/wishlisted/
// following) is preview-gated. Also covers: every mutating control stays
// visible but inert in preview mode, and the empty-content case renders
// the same placeholder/fallback a visitor would see.
//
// This is the first test file in this project to pump one of these three
// Detail screens directly, which needed a real (if unreachable-for-writes)
// Supabase client: each screen's late final repo fields construct against
// Supabase.instance.client eagerly, even for the venue-level loads that
// deliberately keep running in preview mode. Supabase.initialize() with
// the app's own public anon key/URL (from .env — the same credentials the
// app itself ships with; see CLAUDE.md's own "the anon key is public"
// note) makes that access not throw; the actual network calls it triggers
// then hit this project's own established flutter_test limitation (every
// HTTP request 400s in this sandbox), which every one of these loads
// already tolerates via its existing try/catch, leaving that section
// hidden rather than crashing the test. "A test supplies what it needs
// and tolerates whatever it does not" — the content overrides are what
// it needs; the venue-level sections silently failing to load is what it
// tolerates.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:michelin_passport/core/widgets/venue_about_section.dart';
import 'package:michelin_passport/features/hotels/hotel_detail_screen.dart';
import 'package:michelin_passport/features/private_chefs/private_chef_detail_screen.dart';
import 'package:michelin_passport/features/restaurants/restaurant_detail_screen.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/private_chef.dart';
import 'package:michelin_passport/models/private_chef_photo.dart';
import 'package:michelin_passport/models/published_venue_photo.dart';
import 'package:michelin_passport/models/restaurant.dart';

const _restaurant = Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: 'Parkheuvel',
  michelinStars: 2,
  inclusionReason: 'michelin_star',
  cityName: 'Rotterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: 'Some address',
);

const _hotel = Hotel(
  id: 'h1',
  hotelCode: 'h1',
  name: 'Aman Venice',
  michelinKeys: 3,
  cityName: 'Venice',
  countryCode: 'IT',
  countryName: 'Italy',
  flagEmoji: '🇮🇹',
  address: 'Some address',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

const _chef = PrivateChef(id: 'c1', slug: 'chef-c1', displayName: 'Chef Name');

const _chefWithBiography = PrivateChef(
  id: 'c1',
  slug: 'chef-c1',
  displayName: 'Chef Name',
  biography: "The chef's catalogue biography, filled in by Mantelier.",
);

const _chefPhotos = [
  PrivateChefPhoto(
    id: 'p1',
    privateChefId: 'c1',
    imageUrl: 'https://example.com/c1/0.jpg',
  ),
];

/// Taps a control after scrolling it into view — the same lesson learned
/// while fixing venue_management_screen_test.dart: added content can push
/// a target below the fixed 800x600 test viewport. `ensureVisible` covers
/// most controls here (the AppBar's Wishlist/Follow icons, and "Plan
/// visit"/"Plan stay", are all already on-screen at rest and don't even
/// need it to move anything). "Add your first visit"/"Add your first
/// stay" sit lower on the page, inside the `CustomScrollView`'s cache
/// extent — built, but below the actual 800x600 window — which both
/// `ensureVisible` and `scrollUntilVisible` treat as already "visible"
/// without ever dragging; [forceScroll] does an unconditional drag first
/// for exactly those two. A false hit here would make the guard
/// assertions that follow vacuous.
Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool forceScroll = false,
}) async {
  if (forceScroll) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder, warnIfMissed: true);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await dotenv_pkg.dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv_pkg.dotenv.env['SUPABASE_URL']!,
      // ignore: deprecated_member_use
      anonKey: dotenv_pkg.dotenv.env['SUPABASE_ANON_KEY']!,
    );
  });

  group('renders the real screen with injected preview content', () {
    testWidgets(
      'RestaurantDetailScreen — proves the injectable-content refactor, '
      'not a replica screen',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RestaurantDetailScreen(
              restaurant: _restaurant,
              isPreview: true,
              aboutTextOverride: 'A proposed new description of the venue.',
              photosOverride: [PublishedVenuePhoto(id: 'r1-photo-0', imageUrl: 'https://example.com/r1/0.jpg', displayOrder: 0)],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Parkheuvel'), findsWidgets);
        expect(
          find.text('A proposed new description of the venue.'),
          findsOneWidget,
        );
        expect(find.byType(VenueAboutSection), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('HotelDetailScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelDetailScreen(
            hotel: _hotel,
            isPreview: true,
            aboutTextOverride: 'A proposed new description of the hotel.',
            photosOverride: [PublishedVenuePhoto(id: 'h1-photo-0', imageUrl: 'https://example.com/h1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aman Venice'), findsWidgets);
      expect(
        find.text('A proposed new description of the hotel.'),
        findsOneWidget,
      );
      expect(find.byType(VenueAboutSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrivateChefDetailScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChefDetailScreen(
            chefId: 'c1',
            chefOverride: _chef,
            isPreview: true,
            aboutTextOverride: 'A proposed new bio.',
            photosOverride: _chefPhotos,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chef Name'), findsWidgets);
      expect(find.text('A proposed new bio.'), findsOneWidget);
      expect(find.byType(VenueAboutSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      "PrivateChefDetailScreen — a pending about submission shows in "
      "place of the chef's catalogue biography, not alongside it",
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PrivateChefDetailScreen(
              chefId: 'c1',
              chefOverride: _chefWithBiography,
              isPreview: true,
              aboutTextOverride: "The chef's own proposed words.",
              photosOverride: _chefPhotos,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("The chef's own proposed words."), findsOneWidget);
        expect(
          find.text("The chef's catalogue biography, filled in by Mantelier."),
          findsNothing,
        );
        expect(find.byType(VenueAboutSection), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('empty case — no photos, no about text', () {
    testWidgets(
      'RestaurantDetailScreen falls back to the normal placeholder, '
      'exactly as a visitor would see',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RestaurantDetailScreen(
              restaurant: _restaurant,
              isPreview: true,
              aboutTextOverride: null,
              photosOverride: [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VenueAboutSection), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PrivateChefDetailScreen falls back to the normal placeholder, and '
      'hides the report-photo action along with the gallery it belongs to',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PrivateChefDetailScreen(
              chefId: 'c1',
              chefOverride: _chef,
              isPreview: true,
              aboutTextOverride: null,
              photosOverride: [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VenueAboutSection), findsNothing);
        expect(find.byIcon(Icons.flag_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('inert controls — visible but do nothing in preview mode', () {
    testWidgets('Restaurant: Wishlist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantDetailScreen(
            restaurant: _restaurant,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'r1-photo-0', imageUrl: 'https://example.com/r1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byIcon(Icons.favorite_border_rounded));

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Restaurant: Follow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantDetailScreen(
            restaurant: _restaurant,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'r1-photo-0', imageUrl: 'https://example.com/r1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byIcon(Icons.person_add_alt_1_outlined));

      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Restaurant: Add visit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantDetailScreen(
            restaurant: _restaurant,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'r1-photo-0', imageUrl: 'https://example.com/r1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(
        tester,
        find.text('Add your first visit'),
        forceScroll: true,
      );

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Restaurant: Plan visit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RestaurantDetailScreen(
            restaurant: _restaurant,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'r1-photo-0', imageUrl: 'https://example.com/r1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Plan visit'));

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hotel: Wishlist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelDetailScreen(
            hotel: _hotel,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'h1-photo-0', imageUrl: 'https://example.com/h1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byIcon(Icons.favorite_border_rounded));

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hotel: Follow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelDetailScreen(
            hotel: _hotel,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'h1-photo-0', imageUrl: 'https://example.com/h1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byIcon(Icons.person_add_alt_1_outlined));

      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hotel: Add stay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelDetailScreen(
            hotel: _hotel,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'h1-photo-0', imageUrl: 'https://example.com/h1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Add your first stay'), forceScroll: true);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hotel: Plan stay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelDetailScreen(
            hotel: _hotel,
            isPreview: true,
            aboutTextOverride: 'About.',
            photosOverride: [PublishedVenuePhoto(id: 'h1-photo-0', imageUrl: 'https://example.com/h1/0.jpg', displayOrder: 0)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Plan stay'));

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrivateChef: Follow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChefDetailScreen(
            chefId: 'c1',
            chefOverride: _chef,
            isPreview: true,
            aboutTextOverride: 'Bio.',
            photosOverride: _chefPhotos,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byIcon(Icons.person_add_alt_1_outlined));

      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PrivateChef: Report photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChefDetailScreen(
            chefId: 'c1',
            chefOverride: _chef,
            isPreview: true,
            aboutTextOverride: 'Bio.',
            photosOverride: _chefPhotos,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, find.byIcon(Icons.flag_outlined));

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
