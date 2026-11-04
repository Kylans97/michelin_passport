// Four things the lookbook's screenshots showed up (2026-11-04): the status
// bar on green app bars, the Explore card rails, and Hottest Places' photo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/venue_detail_hero.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_cards.dart';
import 'package:michelin_passport/features/explore/widgets/explore_discovery_sections.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/ranking_entry.dart';
import 'package:michelin_passport/models/restaurant.dart';

const _longName = 'A Restaurant With A Name Long Enough To Need Two Lines';

Restaurant _restaurant() => Restaurant.fromJson({
  'id': 'r1',
  'name': _longName,
  'city_name': 'Amsterdam',
  'country_code': 'NL',
  'michelin_stars': 2,
});

Hotel _hotel() => Hotel.fromJson({
  'id': 'h1',
  'name': _longName,
  'city_name': 'Amsterdam',
  'country_code': 'NL',
  'michelin_keys': 2,
});

Widget _at(double scale, Widget child) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SizedBox(width: 390, child: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  for (final scale in [1.0, 1.3, 1.6, 2.0]) {
    testWidgets('restaurant and hotel rails fit a two-line name at ${scale}x', (
      tester,
    ) async {
      await tester.pumpWidget(
        _at(
          scale,
          Column(
            children: [
              WorthTheJourneySection(
                restaurants: [_restaurant()],
                onTapRestaurant: (_) {},
              ),
              // Its Selection line is taller than a row of stars.
              MantelierLatestSection(
                restaurants: [
                  Restaurant.fromJson({
                    'id': 'r2',
                    'name': _longName,
                    'city_name': 'Amsterdam',
                    'country_code': 'NL',
                  }),
                ],
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

  testWidgets('at normal text size a card has no empty band', (tester) async {
    await tester.pumpWidget(
      _at(
        1,
        WorthTheJourneySection(
          restaurants: [_restaurant()],
          onTapRestaurant: (_) {},
        ),
      ),
    );
    final height = tester
        .getSize(find.byType(ExploreDiscoveryRestaurantCard))
        .height;
    expect(height, lessThan(280));
  });

  testWidgets('a venue hero keeps the status bar light over its photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              VenueDetailHero(
                title: 'A Venue',
                isWishlisted: false,
                wishlistSaving: false,
                onTapWishlist: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.systemOverlayStyle, SystemUiOverlayStyle.light);
  });

  test('a community ranking entry reads its card photo', () {
    final entry = CommunityRankingEntry.fromJson({
      'restaurant_id': 'r1',
      'name': 'A Venue',
      'card_photo_url': 'https://example.test/p.jpg',
      'card_focus_x': 0.2,
    });
    expect(entry.imageUrl, 'https://example.test/p.jpg');
    expect(entry.imageFraming.focusX, 0.2);
  });
}
