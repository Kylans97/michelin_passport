// Widget tests for Explore's Discovery-mode sections and cards
// (lib/features/explore/widgets/explore_discovery_sections.dart,
// explore_discovery_cards.dart). Pumped directly with real model fixtures —
// no Supabase involved, same reasoning as passport_cards_test.dart: Explore
// Screen itself can't be widget-tested (constructs RestaurantRepository/
// HotelRepository/EventsRepository against Supabase.instance.client
// unconditionally).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_cards.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_sections.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String id = 'r1',
  String name = 'Test Restaurant',
  int? michelinStars,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
}) => Restaurant(
  id: id,
  restaurantCode: id,
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: cityName,
  countryCode: 'FR',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
);

Hotel _hotel({
  String id = 'h1',
  String name = 'Test Hotel',
  int? michelinKeys,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: michelinKeys,
  cityName: cityName,
  countryCode: 'FR',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Rue de Test',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Event _event({
  String id = 'e1',
  String name = "'t Preuvenemint",
  DateTime? startAt,
  String? city,
  bool freeEntry = true,
}) => Event(
  id: id,
  name: name,
  // Re-tagged as UTC + paired with an explicit 'UTC' timezone so date
  // rendering is deterministic regardless of the test machine's own
  // zone — see events_test.dart's _event() for the full rationale.
  startAt: _utc(startAt ?? DateTime(2026, 8, 27)),
  endAt: _utc(startAt ?? DateTime(2026, 8, 30)),
  timezone: 'UTC',
  countryCode: 'NL',
  city: city ?? 'Maastricht',
  eventType: EventType.festival,
  status: EventStatus.upcoming,
  admissionType: freeEntry ? EventAdmissionType.free : EventAdmissionType.paid,
  createdAt: DateTime(2026, 1, 1),
);

DateTime _utc(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.deepGreen,
    body: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  ),
);

void main() {
  group('WhatsOnSection', () {
    testWidgets('renders the featured event with name, date and city', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          WhatsOnSection(
            featuredEvent: _event(),
            onTapEvent: (_) => tapped = true,
            onViewAll: () {},
          ),
        ),
      );
      expect(find.text("'t Preuvenemint"), findsOneWidget);
      expect(find.textContaining('Maastricht'), findsOneWidget);
      expect(find.text('View all events'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(ExploreFeaturedEventCard));
      expect(tapped, isTrue);
    });

    testWidgets('renders nothing when there is no featured event', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WhatsOnSection(
            featuredEvent: null,
            onTapEvent: (_) {},
            onViewAll: () {},
          ),
        ),
      );
      expect(find.byType(WhatsOnSection), findsOneWidget);
      expect(find.text('View all events'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows FREE ENTRY when applicable', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WhatsOnSection(
            featuredEvent: _event(freeEntry: true),
            onTapEvent: (_) {},
            onViewAll: () {},
          ),
        ),
      );
      expect(find.text('FREE ENTRY'), findsOneWidget);
    });

    testWidgets('long event name and city at 320px — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WhatsOnSection(
            featuredEvent: _event(
              name: 'The Extraordinarily Long Culinary Festival Name',
              city: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
            ),
            onTapEvent: (_) {},
            onViewAll: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: WhatsOnSection(
                    featuredEvent: _event(),
                    onTapEvent: (_) {},
                    onViewAll: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('WorthTheJourneySection', () {
    testWidgets('renders a horizontal row of restaurant cards', (tester) async {
      var tappedName = '';
      await tester.pumpWidget(
        _wrap(
          WorthTheJourneySection(
            restaurants: [
              _restaurant(id: 'r1', name: 'DiverXO', michelinStars: 3),
              _restaurant(id: 'r2', name: 'Disfrutar', michelinStars: 2),
            ],
            onTapRestaurant: (r) => tappedName = r.name,
          ),
        ),
      );
      expect(find.text('DiverXO'), findsOneWidget);
      expect(find.text('Disfrutar'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('DiverXO'));
      expect(tappedName, 'DiverXO');
    });

    testWidgets('renders nothing when the list is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WorthTheJourneySection(
            restaurants: const [],
            onTapRestaurant: (_) {},
          ),
        ),
      );
      expect(find.text('WORTH THE JOURNEY'), findsNothing);
    });

    testWidgets('long restaurant name/city/country at 320px — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          WorthTheJourneySection(
            restaurants: [
              _restaurant(
                name: 'The Extraordinarily Long Restaurant Name Establishment',
                michelinStars: 3,
                cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
                countryName:
                    'United Kingdom of Great Britain and Northern Ireland',
                flagEmoji: '🇬🇧',
              ),
            ],
            onTapRestaurant: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: WorthTheJourneySection(
                    restaurants: [_restaurant(michelinStars: 2)],
                    onTapRestaurant: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('StayALittleLongerSection', () {
    testWidgets('renders a horizontal row of hotel cards', (tester) async {
      var tappedName = '';
      await tester.pumpWidget(
        _wrap(
          StayALittleLongerSection(
            hotels: [
              _hotel(id: 'h1', name: 'Aman Venice', michelinKeys: 3),
              _hotel(id: 'h2', name: 'The Ritz Paris', michelinKeys: 2),
            ],
            onTapHotel: (h) => tappedName = h.name,
          ),
        ),
      );
      expect(find.text('Aman Venice'), findsOneWidget);
      expect(find.text('The Ritz Paris'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Aman Venice'));
      expect(tappedName, 'Aman Venice');
    });

    testWidgets('renders nothing when the list is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(StayALittleLongerSection(hotels: const [], onTapHotel: (_) {})),
      );
      expect(find.text('STAY A LITTLE LONGER'), findsNothing);
    });

    testWidgets('long hotel name/city/country at 320px — no overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          StayALittleLongerSection(
            hotels: [
              _hotel(
                name: 'The Extraordinarily Long Grand Hotel Establishment',
                michelinKeys: 3,
                cityName: 'Llanfairpwllgwyngyllgogerychwyrndrobwll',
                countryName:
                    'United Kingdom of Great Britain and Northern Ireland',
                flagEmoji: '🇬🇧',
              ),
            ],
            onTapHotel: (_) {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('increased text scale — no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.deepGreen,
              body: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: StayALittleLongerSection(
                    hotels: [_hotel(michelinKeys: 2)],
                    onTapHotel: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
