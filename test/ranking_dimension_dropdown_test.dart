// Covers the UI Consistency pass on My Rankings' dimension selector:
// - RankingDimension/RankingVenueType — the canonical restaurant/hotel
//   dimension lists, including the Room/Experience hotel-dimension fix.
// - RankingDimensionDropdown — the new dropdown replacing DimensionFilterBar.
// - buildPersonalRankings — confirms changing dimension (including the new
//   hotel-only Room/Experience dimensions) still recomputes correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/constants/app_colors.dart';
import 'package:michelin_passport/features/rankings/rankings_view_model.dart';
import 'package:michelin_passport/features/rankings/widgets/ranking_dimension_dropdown.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/passport_venue.dart';
import 'package:michelin_passport/models/ranking_dimension.dart';
import 'package:michelin_passport/models/ranking_venue_type.dart';
import 'package:michelin_passport/models/venue_entry.dart';
import 'package:michelin_passport/models/visit.dart';

Hotel _hotel({String id = 'h1', String name = 'Test Hotel'}) => Hotel(
  id: id,
  hotelCode: id,
  name: name,
  michelinKeys: null,
  cityName: 'Amsterdam',
  countryCode: 'NL',
  countryName: 'Netherlands',
  flagEmoji: '🇳🇱',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
);

Visit _stay({
  required String id,
  int? roomRating,
  int? experienceRating,
  int? serviceRating,
  int? valueRating,
  int? overall,
  DateTime? visitedOn,
}) => Visit(
  id: id,
  userId: 'u1',
  entityType: 'hotel',
  entityId: 'h1',
  visitedOn: visitedOn ?? DateTime(2025, 6, 1),
  rating: overall,
  serviceRating: serviceRating,
  valueRating: valueRating,
  roomRating: roomRating,
  experienceRating: experienceRating,
);

// Color Hierarchy Correction pass: wrapped on the deep-green canvas
// Ranking actually renders against today (was AppColors.background — a
// light canvas that stopped matching reality once Ranking moved onto the
// persistent Passport shell's deep-green environment).
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(backgroundColor: AppColors.deepGreen, body: child),
);

void main() {
  group('RankingDimension / RankingVenueType — canonical dimension lists', () {
    test(
      'restaurant dimensions are exactly Overall/Food/Service/Wine/Value',
      () {
        expect(RankingVenueType.restaurant.validDimensions, [
          RankingDimension.overall,
          RankingDimension.food,
          RankingDimension.service,
          RankingDimension.wine,
          RankingDimension.value,
        ]);
      },
    );

    test('hotel dimensions are exactly Overall/Service/Value/Room/Experience '
        '(the current model — not the old reduced 3-dimension set)', () {
      expect(RankingVenueType.hotel.validDimensions, [
        RankingDimension.overall,
        RankingDimension.service,
        RankingDimension.value,
        RankingDimension.room,
        RankingDimension.experience,
      ]);
    });

    test('Room/Experience read visit.roomRating/experienceRating', () {
      final visit = _stay(id: 'v1', roomRating: 8, experienceRating: 9);
      expect(RankingDimension.room.valueFor(visit), 8);
      expect(RankingDimension.experience.valueFor(visit), 9);
    });

    test('Room/Experience are never valid for restaurants; Food/Wine are '
        'never valid for hotels', () {
      expect(RankingDimension.room.validForRestaurant, isFalse);
      expect(RankingDimension.experience.validForRestaurant, isFalse);
      expect(RankingDimension.food.validForHotel, isFalse);
      expect(RankingDimension.wine.validForHotel, isFalse);
    });
  });

  group('RankingDimensionDropdown', () {
    testWidgets('renders the currently selected dimension label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RankingDimensionDropdown(
            dimensions: RankingVenueType.restaurant.validDimensions,
            selected: RankingDimension.overall,
            onSelect: (_) {},
          ),
        ),
      );
      expect(find.text('Overall'), findsOneWidget);
    });

    testWidgets('tapping opens a sheet listing every passed dimension', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RankingDimensionDropdown(
            dimensions: RankingVenueType.hotel.validDimensions,
            selected: RankingDimension.overall,
            onSelect: (_) {},
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      // The complete current hotel dimension set must all be selectable —
      // this is the concrete regression check for the Room/Experience gap.
      expect(find.text('Overall'), findsWidgets);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Value'), findsOneWidget);
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Experience'), findsOneWidget);
    });

    testWidgets('selecting a dimension in the sheet fires onSelect and '
        'closes the sheet', (tester) async {
      RankingDimension? picked;
      await tester.pumpWidget(
        _wrap(
          RankingDimensionDropdown(
            dimensions: RankingVenueType.hotel.validDimensions,
            selected: RankingDimension.overall,
            onSelect: (d) => picked = d,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Room'));
      await tester.pumpAndSettle();
      expect(picked, RankingDimension.room);
    });

    testWidgets('the trigger uses on-dark tokens — transparent fill, '
        'subtle dark-canvas border, ivory label — matching '
        "YearFilterControl's own CsSurface.dark trigger now that Ranking "
        'sits on the deep-green canvas', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RankingDimensionDropdown(
            dimensions: RankingVenueType.restaurant.validDimensions,
            selected: RankingDimension.overall,
            onSelect: (_) {},
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect(decoration.border?.top.color, AppColors.subtleBorderDark);
      final label = tester.widget<Text>(find.text('Overall'));
      expect(label.style?.color, AppColors.textOnDark);
    });

    testWidgets('gold audit: no gold color anywhere in the trigger or sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RankingDimensionDropdown(
            dimensions: RankingVenueType.hotel.validDimensions,
            selected: RankingDimension.room,
            onSelect: (_) {},
          ),
        ),
      );
      var texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      texts = tester.widgetList<Text>(find.byType(Text));
      for (final text in texts) {
        expect(text.style?.color, isNot(AppColors.gold));
      }
    });

    testWidgets('320px width — no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpWidget(
        _wrap(
          RankingDimensionDropdown(
            dimensions: RankingVenueType.hotel.validDimensions,
            selected: RankingDimension.experience,
            onSelect: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('1.6x text scale — no overflow, sheet still opens cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: RankingDimensionDropdown(
                dimensions: RankingVenueType.hotel.validDimensions,
                selected: RankingDimension.experience,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('buildPersonalRankings — dimension changes recompute correctly '
      '(including the new hotel Room/Experience dimensions)', () {
    test('switching from Overall to Room changes the ranking order', () {
      final hotelA = HotelVenue(_hotel(id: 'h1', name: 'Hotel A'));
      final hotelB = HotelVenue(_hotel(id: 'h2', name: 'Hotel B'));
      final entries = [
        VenueEntry(
          venue: hotelA,
          visits: [_stay(id: 'v1', overall: 9, roomRating: 4)],
        ),
        VenueEntry(
          venue: hotelB,
          visits: [_stay(id: 'v2', overall: 5, roomRating: 10)],
        ),
      ];

      final byOverall = buildPersonalRankings(
        entries,
        venueType: RankingVenueType.hotel,
        dimension: RankingDimension.overall,
      );
      expect(byOverall.first.venue.name, 'Hotel A');

      final byRoom = buildPersonalRankings(
        entries,
        venueType: RankingVenueType.hotel,
        dimension: RankingDimension.room,
      );
      expect(byRoom.first.venue.name, 'Hotel B');
    });

    test('a hotel stay with no Experience rating is excluded from the '
        'Experience ranking, never counted as 0', () {
      final hotel = HotelVenue(_hotel());
      final entries = [
        VenueEntry(
          venue: hotel,
          visits: [_stay(id: 'v1', overall: 8)],
        ),
      ];
      final byExperience = buildPersonalRankings(
        entries,
        venueType: RankingVenueType.hotel,
        dimension: RankingDimension.experience,
      );
      expect(byExperience, isEmpty);
    });

    test('year filter still works alongside a hotel-only dimension', () {
      final hotel = HotelVenue(_hotel());
      final entries = [
        VenueEntry(
          venue: hotel,
          visits: [
            _stay(
              id: 'v1',
              experienceRating: 6,
              visitedOn: DateTime(2024, 3, 1),
            ),
            _stay(
              id: 'v2',
              experienceRating: 10,
              visitedOn: DateTime(2025, 3, 1),
            ),
          ],
        ),
      ];
      final result2025 = buildPersonalRankings(
        entries,
        venueType: RankingVenueType.hotel,
        dimension: RankingDimension.experience,
        year: 2025,
      );
      expect(result2025.single.averageScore, 10);

      final allTime = buildPersonalRankings(
        entries,
        venueType: RankingVenueType.hotel,
        dimension: RankingDimension.experience,
      );
      expect(allTime.single.averageScore, 8); // (6 + 10) / 2
    });
  });
}
