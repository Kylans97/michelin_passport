// Covers buildSharedGuideEntries / sortSharedGuideEntries: the shared
// guides (regional 50 Best, Guía Repsol) list in their own order and
// measure, and a restaurant missing from restaurants_full is left out,
// never shown as a placeholder.

import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/guide_award_repository.dart';
import 'package:michelin_passport/models/guide_award.dart';

Map<String, dynamic> _award(
  String restaurantId, {
  String measure = 'rank',
  int? rank,
  int? tier,
}) => {
  'guide_code': 'g',
  'guide_name': 'Guide',
  'measure': measure,
  'score_max': null,
  'edition_year': 2026,
  'list_name': 'main',
  'rank': rank,
  'score': null,
  'tier': tier,
  'distinction_label': null,
  'restaurant_id': restaurantId,
};

Map<String, dynamic> _restaurant(String id, String name) => {
  'id': id,
  'restaurant_code': id,
  'name': name,
  'city_name': 'City',
  'country_name': 'Country',
  'country_code': 'ES',
};

void main() {
  test('a ranked guide lists by rank, lowest first', () {
    final entries = buildSharedGuideEntries(
      awardRows: [
        _award('a', rank: 12),
        _award('b', rank: 1),
        _award('c', rank: 5),
      ],
      tierLabels: null,
      restaurantRows: [
        _restaurant('a', 'Alpha'),
        _restaurant('b', 'Bravo'),
        _restaurant('c', 'Charlie'),
      ],
    );
    expect([for (final e in entries) e.award.rank], [1, 5, 12]);
  });

  test('a tier guide lists highest tier first, then by name, with labels', () {
    final entries = buildSharedGuideEntries(
      awardRows: [
        _award('a', measure: 'tier', tier: 2),
        _award('b', measure: 'tier', tier: 3),
        _award('c', measure: 'tier', tier: 3),
      ],
      tierLabels: {'2': '2 Soles', '3': '3 Soles'},
      restaurantRows: [
        _restaurant('a', 'Alpha'),
        _restaurant('b', 'Zulu'),
        _restaurant('c', 'Bravo'),
      ],
    );
    expect(
      [for (final e in entries) e.restaurant.name],
      ['Bravo', 'Zulu', 'Alpha'],
    );
    expect(formatGuideAwardValue(entries.first.award), '3 Soles');
  });

  test('a restaurant not in the resolved rows is left out', () {
    final entries = buildSharedGuideEntries(
      awardRows: [_award('a', rank: 1), _award('missing', rank: 2)],
      tierLabels: null,
      restaurantRows: [_restaurant('a', 'Alpha')],
    );
    expect(entries.length, 1);
    expect(entries.single.restaurant.id, 'a');
  });
}
