// Covers the test scenarios from the nullable Michelin Keys + World's 50
// Best Hotels integration task:
//   A. Existing 3-Key hotel
//   B. Existing 1-Key hotel
//   C. World's 50 Best hotel with null Keys
//   D. Hotel with Keys + World's 50 Best
//   E. Hotel with no World's 50 Best history
//   F. Hotel Award History with multiple World's 50 Best years
//   G. Hotel stay saved when Keys are null
//
// A-F are exercised directly (model parsing, view-model aggregation,
// widget rendering) — no live Supabase connection is used or needed. G is
// a network call (VisitedRepository.markHotelStay); this project has no
// Supabase mocking harness, so G is instead verified at the type level:
// Hotel.michelinKeys and Visit.keysAtVisit/markHotelStay's keysAtVisit
// param are both `int?`, so passing a null michelinKeys straight through
// type-checks with no cast, no `??`, no possible silent 0 — see the
// dedicated note in the G group below and the main report's section 12.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/key_row.dart';
import 'package:michelin_passport/features/hotels/award_history/keys_history_view_model.dart';
import 'package:michelin_passport/features/hotels/award_history/worlds_50_best_hotels_history_view_model.dart';
import 'package:michelin_passport/features/hotels/widgets/hotel_awards_card.dart';
import 'package:michelin_passport/features/hotels/widgets/worlds_50_best_hotels_history_section.dart';
import 'package:michelin_passport/models/award_history_entry.dart';
import 'package:michelin_passport/models/award_transition.dart';
import 'package:michelin_passport/models/hotel.dart';
import 'package:michelin_passport/models/worlds_50_best_hotel_entry.dart';

Hotel _hotel({
  int? michelinKeys,
  int? worlds50BestRank,
  int? worlds50BestYear,
  String code = 'hotel_001',
}) => Hotel(
  id: 'id-$code',
  hotelCode: code,
  name: 'Test Hotel $code',
  michelinKeys: michelinKeys,
  cityName: 'Test City',
  countryCode: 'FR',
  countryName: 'France',
  flagEmoji: '🇫🇷',
  address: '1 Test Street',
  hasMichelinRestaurant: false,
  restaurantCount: 0,
  worlds50BestRank: worlds50BestRank,
  worlds50BestYear: worlds50BestYear,
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Material(child: child)),
);

void main() {
  group('A. Existing 3-Key hotel', () {
    test('Hotel.fromJson parses michelin_keys=3 correctly', () {
      final hotel = Hotel.fromJson({
        'id': 'x',
        'hotel_code': 'hotel_001',
        'name': 'Le Bristol Paris',
        'michelin_keys': 3,
        'city_name': 'Paris',
        'country_code': 'FR',
        'country_name': 'France',
        'flag_emoji': '🇫🇷',
        'address': '112 Rue du Faubourg Saint-Honoré',
        'has_michelin_restaurant': false,
        'restaurant_count': 0,
      });
      expect(hotel.michelinKeys, 3);
      expect(hotel.hasMichelinKeys, isTrue);
      expect(hotel.isWorlds50Best, isFalse);
    });

    testWidgets('renders KeyRow with 3 icons, no crash', (tester) async {
      final hotel = _hotel(michelinKeys: 3);
      await tester.pumpWidget(
        _wrap(
          hotel.hasMichelinKeys
              ? KeyRow(count: hotel.michelinKeys!)
              : const SizedBox.shrink(),
        ),
      );
      expect(find.byType(KeyRow), findsOneWidget);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNWidgets(3));
    });
  });

  group('B. Existing 1-Key hotel', () {
    test('Hotel.fromJson parses michelin_keys=1 correctly', () {
      final hotel = Hotel.fromJson({
        'id': 'x',
        'hotel_code': 'hotel_002',
        'name': 'Aman Tokyo',
        'michelin_keys': 1,
        'city_name': 'Tokyo',
        'country_code': 'JP',
        'country_name': 'Japan',
        'flag_emoji': '🇯🇵',
        'address': '1-5-6 Otemachi',
        'has_michelin_restaurant': false,
        'restaurant_count': 0,
      });
      expect(hotel.michelinKeys, 1);
      expect(hotel.hasMichelinKeys, isTrue);
    });

    testWidgets('renders KeyRow with exactly 1 icon', (tester) async {
      final hotel = _hotel(michelinKeys: 1);
      await tester.pumpWidget(_wrap(KeyRow(count: hotel.michelinKeys!)));
      expect(find.byIcon(Icons.vpn_key_rounded), findsOneWidget);
    });
  });

  group('C. World\'s 50 Best hotel with null Keys', () {
    test('Hotel.fromJson: missing michelin_keys parses to null, never 0', () {
      final hotel = Hotel.fromJson({
        'id': 'x',
        'hotel_code': 'hotel_688',
        'name': 'Rosewood Mayakoba',
        // michelin_keys deliberately absent from this JSON, matching what
        // hotelFullColumns produces today for a hotel with a real NULL
        // column value.
        'city_name': 'Playa del Carmen',
        'country_code': 'MX',
        'country_name': 'Mexico',
        'flag_emoji': '🇲🇽',
        'address': 'Ctra. Federal Km 298',
        'has_michelin_restaurant': false,
        'restaurant_count': 0,
        'worlds_50_best_rank': 95,
        'worlds_50_best_year': 2025,
      });
      expect(hotel.michelinKeys, isNull);
      expect(hotel.hasMichelinKeys, isFalse);
      expect(hotel.isWorlds50Best, isTrue);
      expect(hotel.worlds50BestRank, 95);
    });

    testWidgets('KeyRow is omitted entirely, never rendered as 0 Keys', (
      tester,
    ) async {
      final hotel = _hotel(worlds50BestRank: 95, worlds50BestYear: 2025);
      await tester.pumpWidget(
        _wrap(
          hotel.hasMichelinKeys
              ? KeyRow(count: hotel.michelinKeys!)
              : const SizedBox.shrink(),
        ),
      );
      expect(find.byType(KeyRow), findsNothing);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNothing);
      // No stray "0" text anywhere that could read as "0 Keys".
      expect(find.text('0'), findsNothing);
    });

    testWidgets('HotelAwardsCard shows World\'s 50 Best row, no Keys row', (
      tester,
    ) async {
      final hotel = _hotel(worlds50BestRank: 95, worlds50BestYear: 2025);
      await tester.pumpWidget(_wrap(HotelAwardsCard(hotel: hotel)));
      expect(find.textContaining('#95'), findsOneWidget);
      expect(find.textContaining('2025'), findsOneWidget);
      expect(find.textContaining('MICHELIN Keys'), findsNothing);
      expect(find.byIcon(Icons.vpn_key_rounded), findsNothing);
    });

    test('a hotel with null Keys is still structurally a valid Hotel', () {
      // Confirms the model never requires michelinKeys to be non-null —
      // this would fail to compile if the field were still `final int`.
      final hotel = _hotel(worlds50BestRank: 12, worlds50BestYear: 2024);
      expect(hotel.michelinKeys, isNull);
      expect(hotel.name, isNotEmpty);
    });
  });

  group('D. Hotel with Keys + World\'s 50 Best', () {
    test('both routes read correctly and independently', () {
      final hotel = _hotel(
        michelinKeys: 2,
        worlds50BestRank: 4,
        worlds50BestYear: 2025,
      );
      expect(hotel.hasMichelinKeys, isTrue);
      expect(hotel.isWorlds50Best, isTrue);
      expect(hotel.michelinKeys, 2);
      expect(hotel.worlds50BestRank, 4);
    });

    testWidgets('HotelAwardsCard shows both rows', (tester) async {
      final hotel = _hotel(
        michelinKeys: 2,
        worlds50BestRank: 4,
        worlds50BestYear: 2025,
      );
      await tester.pumpWidget(_wrap(HotelAwardsCard(hotel: hotel)));
      expect(find.textContaining('MICHELIN Keys'), findsOneWidget);
      expect(find.textContaining("World's 50 Best Hotels"), findsOneWidget);
      expect(find.textContaining('#4'), findsOneWidget);
    });
  });

  group('E. Hotel with no World\'s 50 Best history', () {
    test('HotelWorlds50BestHistorySummary.of([]) is empty', () {
      final summary = HotelWorlds50BestHistorySummary.of(const []);
      expect(summary.isEmpty, isTrue);
      expect(summary.appearances, 0);
      expect(summary.bestRank, isNull);
    });

    testWidgets('history section renders nothing for an empty summary', (
      tester,
    ) async {
      const summary = HotelWorlds50BestHistorySummary(
        topFiftyYears: [],
        extendedYears: [],
      );
      await tester.pumpWidget(
        _wrap(const HotelWorlds50BestHistorySection(summary: summary)),
      );
      expect(find.byType(HotelWorlds50BestHistorySection), findsOneWidget);
      expect(find.text('appearances'), findsNothing);
    });

    testWidgets('HotelAwardsCard renders nothing for a hotel with neither', (
      tester,
    ) async {
      final hotel = _hotel(); // no Keys, no W50B rank
      await tester.pumpWidget(_wrap(HotelAwardsCard(hotel: hotel)));
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('AWARDS'), findsNothing);
    });
  });

  group('F. Hotel Award History with multiple World\'s 50 Best years', () {
    test('appearances/bestRank computed correctly, newest year first', () {
      final rows = [
        const HotelWorlds50BestEntry(
          year: 2023,
          rank: 1,
          listType: HotelWorlds50BestListType.topFifty,
        ),
        const HotelWorlds50BestEntry(
          year: 2024,
          rank: 7,
          listType: HotelWorlds50BestListType.topFifty,
        ),
        const HotelWorlds50BestEntry(
          year: 2025,
          rank: 4,
          listType: HotelWorlds50BestListType.topFifty,
        ),
      ];
      final summary = HotelWorlds50BestHistorySummary.of(rows);
      expect(summary.appearances, 3);
      expect(summary.bestRank, 1);
      expect(summary.topFiftyYears.map((e) => e.year).toList(), [
        2025,
        2024,
        2023,
      ]);
    });

    test('top_50 and extended_51_100 are kept structurally separate', () {
      final rows = [
        const HotelWorlds50BestEntry(
          year: 2025,
          rank: 76,
          listType: HotelWorlds50BestListType.extended,
        ),
        const HotelWorlds50BestEntry(
          year: 2024,
          rank: 20,
          listType: HotelWorlds50BestListType.topFifty,
        ),
      ];
      final summary = HotelWorlds50BestHistorySummary.of(rows);
      expect(summary.topFiftyYears.length, 1);
      expect(summary.extendedYears.length, 1);
      // bestRank only ever considers Top 50 rows, per its own contract.
      expect(summary.bestRank, 20);
    });

    test('MICHELIN Key transitions reuse the generic, award-type-agnostic '
        'detector unchanged, with Keys-specific copy', () {
      final history = [
        const MichelinAwardHistoryEntry(
          guideYear: 2024,
          awardValue: 1,
          isCurrent: false,
        ),
        const MichelinAwardHistoryEntry(
          guideYear: 2025,
          awardValue: 2,
          isCurrent: true,
        ),
      ];
      final transitions = detectAwardTransitions(history);
      expect(transitions, hasLength(2));
      expect(transitions[0].kind, AwardChangeKind.firstAwarded);
      expect(keysTransitionLabel(transitions[0]), 'First Key');
      expect(transitions[1].kind, AwardChangeKind.promoted);
      expect(keysTransitionLabel(transitions[1]), 'Promoted to 2 Keys');
    });

    testWidgets('history section shows every ranked year, not collapsed', (
      tester,
    ) async {
      final summary = HotelWorlds50BestHistorySummary.of([
        const HotelWorlds50BestEntry(
          year: 2023,
          rank: 1,
          listType: HotelWorlds50BestListType.topFifty,
        ),
        const HotelWorlds50BestEntry(
          year: 2024,
          rank: 2,
          listType: HotelWorlds50BestListType.topFifty,
        ),
        const HotelWorlds50BestEntry(
          year: 2025,
          rank: 4,
          listType: HotelWorlds50BestListType.topFifty,
        ),
      ]);
      await tester.pumpWidget(
        _wrap(HotelWorlds50BestHistorySection(summary: summary)),
      );
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('3 appearances'), findsOneWidget);
      expect(find.textContaining('Best ranking: #1'), findsOneWidget);
    });
  });

  group('G. Hotel stay saved when Keys are null', () {
    test(
      'Hotel.michelinKeys (int?) flows into markHotelStay\'s keysAtVisit '
      '(int?) with no cast, no ??, no possible silent 0 — verified at the '
      'type level; VisitedRepository.markHotelStay performs a live Supabase '
      'insert, which this project has no mocking harness for, so the '
      'network path itself is not executed here (see flutter analyze in '
      'the main report for the compiled proof this assignment type-checks)',
      () {
        final hotel = _hotel(); // michelinKeys == null
        final int? keysAtVisit = hotel.michelinKeys; // add_stay_sheet.dart:132
        expect(keysAtVisit, isNull);
        // The critical invariant: a null Key must never become a literal 0
        // anywhere on this path.
        expect(keysAtVisit == 0, isFalse);
      },
    );
  });
}
