// PASSPORT — RANKING UI REDESIGN V1: covers PersonalRankingCard/
// HotelRankingCard's own responsibility — wiring real Restaurant/Hotel/
// PersonalRankingEntry data into RankingEditorialCard correctly (rank,
// name, city+flag, Stars/Keys, score, visit/stay-count singular vs
// plural). Mirrors passport_cards_test.dart's own fixture pattern and its
// documented limitation: tapping through to RestaurantDetailScreen/
// HotelDetailScreen isn't exercised here since both construct Supabase-
// backed repositories eagerly with no session in this sandbox — presence
// of the tap affordance is verified structurally instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/core/widgets/star_row.dart';
import 'package:michelin_passport/features/rankings/widgets/hotel_ranking_card.dart';
import 'package:michelin_passport/features/rankings/widgets/personal_ranking_card.dart';
import 'package:michelin_passport/features/rankings/widgets/ranking_editorial_card.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/restaurant.dart';

Restaurant _restaurant({
  String name = 'ABAC',
  int? michelinStars = 2,
  String cityName = 'Barcelona',
  String countryName = 'Spain',
  String flagEmoji = '🇪🇸',
}) => Restaurant(
  id: 'r1',
  restaurantCode: 'r1',
  name: name,
  michelinStars: michelinStars,
  inclusionReason: 'michelin_star',
  cityName: cityName,
  countryCode: 'ES',
  countryName: countryName,
  flagEmoji: flagEmoji,
  address: '1 Carrer de Test',
);

Hotel _hotel({
  String name = 'Test Hotel',
  int? michelinKeys = 2,
  String cityName = 'Paris',
  String countryName = 'France',
  String flagEmoji = '🇫🇷',
}) => Hotel(
  id: 'h1',
  hotelCode: 'h1',
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

PersonalRankingEntry _entry({
  required PassportVenue venue,
  double averageScore = 10.0,
  int ratedVisitCount = 1,
}) => PersonalRankingEntry(
  venue: venue,
  averageScore: averageScore,
  ratedVisitCount: ratedVisitCount,
  mostRecentRelevantVisit: DateTime(2026, 1, 1),
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PersonalRankingCard', () {
    testWidgets('renders the real rank, name, city+flag, stars, score and '
        'visit count from its data — never mock-up values', (tester) async {
      final restaurant = _restaurant();
      final entry = _entry(
        venue: RestaurantVenue(restaurant),
        averageScore: 10.0,
        ratedVisitCount: 1,
      );
      await tester.pumpWidget(
        _wrap(
          PersonalRankingCard(
            restaurant: restaurant,
            entry: entry,
            rank: 1,
            onReturn: () {},
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('#1'), findsNothing);
      expect(find.text('ABAC'), findsOneWidget);
      expect(find.text('Barcelona 🇪🇸'), findsOneWidget);
      expect(find.text('10.0'), findsOneWidget);
      expect(find.text('· 1 visit'), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);
      // No "Last visit" date anywhere — removed in Passport UI Polish V2
      // for Passport's own cards and never brought back here.
      expect(find.textContaining('Last visit'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a two-line restaurant name is allowed (maxLines 2), not '
        'ellipsized at the first line', (tester) async {
      final restaurant = _restaurant(name: '8 1/2 Otto e Mezzo – Bombana');
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 340,
            child: PersonalRankingCard(
              restaurant: restaurant,
              entry: _entry(venue: RestaurantVenue(restaurant)),
              rank: 3,
              onReturn: () {},
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.text('8 1/2 Otto e Mezzo – Bombana'),
      );
      expect(text.maxLines, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pluralises "visits" when more than one contributed, and '
        'omits StarRow entirely when the restaurant holds no star', (
      tester,
    ) async {
      final restaurant = _restaurant(michelinStars: null);
      final entry = _entry(
        venue: RestaurantVenue(restaurant),
        ratedVisitCount: 3,
      );
      await tester.pumpWidget(
        _wrap(
          PersonalRankingCard(
            restaurant: restaurant,
            entry: entry,
            rank: 5,
            onReturn: () {},
          ),
        ),
      );
      expect(find.text('· 3 visits'), findsOneWidget);
      expect(find.byType(StarRow), findsNothing);
    });

    testWidgets('renders as a RankingEditorialCard with a tap affordance', (
      tester,
    ) async {
      final restaurant = _restaurant();
      await tester.pumpWidget(
        _wrap(
          PersonalRankingCard(
            restaurant: restaurant,
            entry: _entry(venue: RestaurantVenue(restaurant)),
            rank: 1,
            onReturn: () {},
          ),
        ),
      );
      expect(find.byType(RankingEditorialCard), findsOneWidget);
      expect(find.byType(InkWell), findsWidgets);
    });
  });

  group('HotelRankingCard', () {
    testWidgets('renders the real rank, name, city+flag, keys, score and '
        'stay count — Keys not Stars', (tester) async {
      final hotel = _hotel();
      final entry = _entry(
        venue: HotelVenue(hotel),
        averageScore: 9.0,
        ratedVisitCount: 1,
      );
      await tester.pumpWidget(
        _wrap(
          HotelRankingCard(hotel: hotel, entry: entry, rank: 2, onReturn: () {}),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('#2'), findsNothing);
      expect(find.text('Test Hotel'), findsOneWidget);
      expect(find.text('Paris 🇫🇷'), findsOneWidget);
      expect(find.text('9.0'), findsOneWidget);
      expect(find.text('· 1 stay'), findsOneWidget);
      expect(find.byType(KeyRow), findsOneWidget);
      // Hotels never show restaurant Michelin stars — the recognition
      // slot is Keys-only for a hotel, never fabricated Star recognition.
      expect(find.byType(StarRow), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pluralises "stays" when more than one contributed', (
      tester,
    ) async {
      final hotel = _hotel();
      final entry = _entry(venue: HotelVenue(hotel), ratedVisitCount: 4);
      await tester.pumpWidget(
        _wrap(
          HotelRankingCard(hotel: hotel, entry: entry, rank: 1, onReturn: () {}),
        ),
      );
      expect(find.text('· 4 stays'), findsOneWidget);
    });

    testWidgets('omits KeyRow entirely when the hotel holds no Key', (
      tester,
    ) async {
      final hotel = _hotel(michelinKeys: null);
      final entry = _entry(venue: HotelVenue(hotel));
      await tester.pumpWidget(
        _wrap(
          HotelRankingCard(hotel: hotel, entry: entry, rank: 1, onReturn: () {}),
        ),
      );
      expect(find.byType(KeyRow), findsNothing);
    });
  });

  group('Restaurant vs Hotel rating typography parity', () {
    testWidgets('identical rating typography on both card types — same '
        'font size and weight, both smaller than their own name', (
      tester,
    ) async {
      final restaurant = _restaurant();
      await tester.pumpWidget(
        _wrap(
          PersonalRankingCard(
            restaurant: restaurant,
            entry: _entry(venue: RestaurantVenue(restaurant), averageScore: 8.5),
            rank: 1,
            onReturn: () {},
          ),
        ),
      );
      final restaurantScoreStyle = tester.widget<Text>(find.text('8.5')).style;
      final restaurantNameSize = tester
          .widget<Text>(find.text('ABAC'))
          .style
          ?.fontSize;

      final hotel = _hotel();
      await tester.pumpWidget(
        _wrap(
          HotelRankingCard(
            hotel: hotel,
            entry: _entry(venue: HotelVenue(hotel), averageScore: 8.5),
            rank: 1,
            onReturn: () {},
          ),
        ),
      );
      final hotelScoreStyle = tester.widget<Text>(find.text('8.5')).style;
      final hotelNameSize = tester
          .widget<Text>(find.text('Test Hotel'))
          .style
          ?.fontSize;

      expect(restaurantScoreStyle?.fontSize, hotelScoreStyle?.fontSize);
      expect(restaurantScoreStyle?.fontWeight, hotelScoreStyle?.fontWeight);
      expect(restaurantScoreStyle?.fontFamily, hotelScoreStyle?.fontFamily);
      expect(restaurantScoreStyle?.fontSize, lessThan(restaurantNameSize!));
      expect(hotelScoreStyle?.fontSize, lessThan(hotelNameSize!));
    });
  });
}
