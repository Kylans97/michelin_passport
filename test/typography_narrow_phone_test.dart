// The 2026-11-19 type change (Spectral + Hanken Grotesk, replacing
// Cormorant Garamond + Inter) at the narrowest phone the app supports:
// iOS 15 still runs on 320pt-wide iPhones. Every name below is a real
// production name, picked as the longest of its kind in the catalogue on
// 2026-11-18, so the two-line clamps and one-line ellipses meet the worst
// text they will actually get. Rendered with the real bundled fonts (see
// flutter_test_config.dart) at normal, enlarged and the largest common
// text size; tester.takeException() is the assertion, since a RenderFlex
// overflow surfaces there and nowhere else.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/events/widgets/event_card.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_sections.dart';
import 'package:michelin_passport/features/explore/widgets/hotel_tile.dart';
import 'package:michelin_passport/features/explore/widgets/restaurant_tile.dart';
import 'package:michelin_passport/models/event.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/restaurant.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

const _longestEvent =
    "Mezzaluna at lebua (Two Michelin Stars) featuring L'Osier Tokyo "
    '(Three Michelin Stars) – Collaboration Dinner 2026';
const _longestRestaurant =
    'Genießerei am Markt - Steiermark(t)dinner by Alexander Posch';
const _longestHotel =
    'Casa de Sierra Nevada, A Belmond Hotel, San Miguel de Allende';

Event _event() => Event(
  id: 'e1',
  name: _longestEvent,
  startAt: DateTime.utc(2026, 12, 10, 11),
  endAt: DateTime.utc(2026, 12, 10, 15),
  timezone: 'Asia/Bangkok',
  countryCode: 'TH',
  city: 'Bangkok',
  eventType: EventType.dinner,
  admissionType: EventAdmissionType.free,
  createdAt: DateTime.utc(2026, 1, 1),
);

Restaurant _restaurant() => Restaurant.fromJson({
  'id': 'r1',
  'restaurant_code': 'r1',
  'name': _longestRestaurant,
  'city_name': 'Graz',
  'country_code': 'AT',
  'country_name': 'Austria',
  'michelin_stars': 1,
  'worlds_50_best_rank': 87,
});

Hotel _hotel() => Hotel.fromJson({
  'id': 'h1',
  'hotel_code': 'h1',
  'name': _longestHotel,
  'city_name': 'San Miguel de Allende',
  'country_code': 'MX',
  'country_name': 'Mexico',
  'michelin_keys': 2,
});

Widget _phone(double scale, Widget child) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(320, 568),
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: SizedBox(width: 320, child: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  for (final scale in [1.0, 1.35, 2.0]) {
    testWidgets('event card at 320pt, ${scale}x text', (tester) async {
      await tester.pumpWidget(
        _phone(scale, EventCard(event: _event(), onTap: () {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('restaurant and hotel tiles at 320pt, ${scale}x text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _phone(
          scale,
          Column(
            children: [
              RestaurantTile(
                restaurant: _restaurant(),
                showWorlds50BestRank: true,
              ),
              HotelTile(hotel: _hotel()),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Explore rails at 320pt, ${scale}x text', (tester) async {
      await tester.pumpWidget(
        _phone(
          scale,
          Column(
            children: [
              WhatsOnSection(
                featuredEvent: _event(),
                onTapEvent: (_) {},
                onViewAll: () {},
              ),
              WorthTheJourneySection(
                restaurants: [_restaurant()],
                onTapRestaurant: (_) {},
              ),
              StayALittleLongerSection(hotels: [_hotel()], onTapHotel: (_) {}),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
