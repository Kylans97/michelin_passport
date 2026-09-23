import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/utils/venue_lifecycle.dart';
import 'package:michelin_passport/core/widgets/venue_lifecycle_banner.dart';
import 'package:michelin_passport/features/explore/widgets/hotel_tile.dart';
import 'package:michelin_passport/features/explore/widgets/restaurant_tile.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({String status = 'open', bool isExpired = false}) =>
    Restaurant(
      id: 'r1',
      restaurantCode: 'rest_0001',
      name: 'Test Restaurant',
      michelinStars: 1,
      inclusionReason: 'michelin_star',
      cityName: 'Testville',
      countryCode: 'NL',
      countryName: 'Netherlands',
      flagEmoji: '🇳🇱',
      address: '1 Test Street',
      isExpired: isExpired,
      status: status,
    );

Hotel _hotel({String status = 'open', bool isExpired = false}) => Hotel(
  id: 'h1',
  hotelCode: 'hotel_001',
  name: 'Test Hotel',
  michelinKeys: 1,
  cityName: 'Testville',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  isExpired: isExpired,
  status: status,
);

void main() {
  group('RestaurantTile lifecycle line', () {
    testWidgets('open restaurant shows no lifecycle line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RestaurantTile(restaurant: _restaurant())),
        ),
      );
      expect(find.text('Permanently closed'), findsNothing);
      expect(find.text('Temporarily closed'), findsNothing);
      expect(find.text('Pop-up ended'), findsNothing);
    });

    testWidgets('permanently closed restaurant shows the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestaurantTile(
              restaurant: _restaurant(status: 'permanently_closed'),
            ),
          ),
        ),
      );
      expect(find.text('Permanently closed'), findsOneWidget);
    });

    testWidgets('temporarily closed restaurant shows the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestaurantTile(
              restaurant: _restaurant(status: 'temporarily_closed'),
            ),
          ),
        ),
      );
      expect(find.text('Temporarily closed'), findsOneWidget);
    });

    testWidgets('expired pop-up restaurant shows the label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestaurantTile(restaurant: _restaurant(isExpired: true)),
          ),
        ),
      );
      expect(find.text('Pop-up ended'), findsOneWidget);
    });
  });

  group('HotelTile lifecycle line', () {
    testWidgets('open hotel shows no lifecycle line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HotelTile(hotel: _hotel()))),
      );
      expect(find.text('Permanently closed'), findsNothing);
    });

    testWidgets('permanently closed hotel shows the label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HotelTile(hotel: _hotel(status: 'permanently_closed')),
          ),
        ),
      );
      expect(find.text('Permanently closed'), findsOneWidget);
    });
  });

  group('VenueLifecycleBanner', () {
    testWidgets('normal renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VenueLifecycleBanner(state: VenueLifecycleState.normal),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Permanently closed'), findsNothing);
    });

    testWidgets('temporarily closed shows statusNote text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VenueLifecycleBanner(
              state: VenueLifecycleState.temporarilyClosed,
              statusNote: 'Closed for renovations until spring.',
            ),
          ),
        ),
      );
      expect(find.text('Temporarily closed'), findsOneWidget);
      expect(find.text('Closed for renovations until spring.'), findsOneWidget);
    });

    testWidgets(
      'temporarily closed with no statusNote falls back to generic copy',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: VenueLifecycleBanner(
                state: VenueLifecycleState.temporarilyClosed,
              ),
            ),
          ),
        );
        expect(
          find.text(
            'This venue is temporarily closed. Check back later for an update.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('permanently closed ignores statusNote', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VenueLifecycleBanner(
              state: VenueLifecycleState.permanentlyClosed,
              statusNote: 'This text must not appear.',
            ),
          ),
        ),
      );
      expect(find.text('Permanently closed'), findsOneWidget);
      expect(find.text('This venue is no longer operating.'), findsOneWidget);
      expect(find.text('This text must not appear.'), findsNothing);
    });

    testWidgets('popup ended shows the informational line', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VenueLifecycleBanner(state: VenueLifecycleState.popupEnded),
          ),
        ),
      );
      expect(find.text('This pop-up has ended'), findsOneWidget);
    });
  });
}
