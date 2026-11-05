// Overall as the average of the scores filled in, and Atmosphere as a
// restaurant-only score (20261101340000_add_atmosphere_and_computed_overall).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/core/widgets/venue_score_strip.dart';
import 'package:michelin_passport/models/ranking_dimension.dart';
import 'package:michelin_passport/models/visit.dart';

void main() {
  group('computeOverall', () {
    test('nothing filled in is no overall, never a zero', () {
      expect(computeOverall([]), isNull);
      expect(computeOverall([null, null]), isNull);
    });

    test('only food filled in makes food the overall', () {
      expect(computeOverall([8, null, null, null, null]), 8.0);
    });

    test('a score left empty does not count against the others', () {
      expect(computeOverall([9, 8, null, null, 7]), 8.0);
    });

    test('rounds to two decimals, the same as the database', () {
      expect(computeOverall([9, 8, 8]), 8.33);
      expect(computeOverall([9, 9, 8]), 8.67);
    });
  });

  test('an overall always shows one decimal', () {
    expect(formatOverall(8), '8.0');
    expect(formatOverall(8.33), '8.3');
    expect(formatOverall(10), '10.0');
  });

  test('Visit reads a decimal overall and the atmosphere score', () {
    final visit = Visit.fromJson({
      'id': 'v',
      'user_id': 'u',
      'entity_type': 'restaurant',
      'entity_id': 'r',
      'visited_on': '2026-11-04',
      'rating': 8.33,
      'atmosphere_rating': 9,
    });
    expect(visit.rating, 8.33);
    expect(visit.atmosphereRating, 9);
    expect(RankingDimension.overall.valueFor(visit), 8.33);
    expect(RankingDimension.atmosphere.valueFor(visit), 9);
  });

  test('Atmosphere ranks restaurants, not hotels', () {
    expect(RankingDimension.atmosphere.label, 'Atmosphere');
    expect(RankingDimension.atmosphere.validForRestaurant, isTrue);
    expect(RankingDimension.atmosphere.validForHotel, isFalse);
  });

  group('VenueOverallScore', () {
    Future<void> pump(
      WidgetTester tester, {
      double? overall,
      List<ScoreDimension> scores = const [],
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VenueOverallScore(overall: overall, scores: scores),
        ),
      ),
    );

    const scores = [
      ScoreDimension(label: 'Food', value: 7),
      ScoreDimension(label: 'Service', value: 9),
      ScoreDimension(label: 'Wine', value: null),
      ScoreDimension(label: 'Atmosphere', value: 9),
    ];

    testWidgets('shows only the overall until it is tapped', (tester) async {
      await pump(tester, overall: 8.33, scores: scores);
      expect(find.text('8.3'), findsOneWidget);
      expect(find.text('Overall · 3 scores'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
    });

    testWidgets('opens highest first, leaves blanks out, and closes again', (
      tester,
    ) async {
      await pump(tester, overall: 8.33, scores: scores);
      await tester.tap(find.text('8.3'));
      await tester.pumpAndSettle();
      expect(find.text('Wine'), findsNothing);
      final service = tester.getTopLeft(find.text('Service')).dy;
      final atmosphere = tester.getTopLeft(find.text('Atmosphere')).dy;
      final food = tester.getTopLeft(find.text('Food')).dy;
      expect(service, lessThan(atmosphere));
      expect(atmosphere, lessThan(food));
      await tester.tap(find.text('8.3'));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsNothing);
    });

    testWidgets('an overall with nothing behind it does not open', (
      tester,
    ) async {
      await pump(
        tester,
        overall: 7,
        scores: const [ScoreDimension(label: 'Food', value: null)],
      );
      expect(find.text('7.0'), findsOneWidget);
      expect(find.text('Overall'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('no overall says so, never a zero', (tester) async {
      await pump(tester);
      expect(find.text('No scores given'), findsOneWidget);
    });
  });
}
