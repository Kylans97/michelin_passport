import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/guide_award.dart';

void main() {
  group('GuideAward', () {
    test('reads a guide_awards row with its embedded guide', () {
      final award = GuideAward.fromJson({
        'guide_code': 'asia_50_best',
        'edition_year': 2026,
        'list_name': 'top_50',
        'rank': 1,
        'score': null,
        'tier': null,
        'distinction_label': null,
        'guides': {
          'name': "Asia's 50 Best Restaurants",
          'measure': 'rank',
          'score_max': null,
        },
      });
      expect(award.guideName, "Asia's 50 Best Restaurants");
      expect(award.measure, GuideMeasure.rank);
      expect(award.editionYear, 2026);
      expect(formatGuideAwardValue(award), '#1');
    });

    test('formats a score without a trailing .0, and keeps halves', () {
      GuideAward scored(double s) => GuideAward(
        guideCode: 'la_liste',
        guideName: 'La Liste',
        measure: GuideMeasure.score,
        editionYear: 2027,
        listName: 'main',
        score: s,
      );
      expect(formatGuideAwardValue(scored(98)), '98');
      expect(formatGuideAwardValue(scored(98.5)), '98.5');
    });

    test('names a tier the way the guide does', () {
      final award = GuideAward.fromJson({
        'guide_code': 'guia_repsol',
        'edition_year': 2026,
        'list_name': 'soles',
        'tier': 3,
        'guides': {
          'name': 'Guía Repsol',
          'measure': 'tier',
          'tier_labels': {'1': '1 Sol', '2': '2 Soles', '3': '3 Soles'},
        },
      });
      expect(formatGuideAwardValue(award), '3 Soles');
    });

    test('shows nothing it does not hold', () {
      const award = GuideAward(
        guideCode: 'asia_50_best',
        guideName: "Asia's 50 Best Restaurants",
        measure: GuideMeasure.rank,
        editionYear: 2026,
        listName: 'top_50',
      );
      expect(formatGuideAwardValue(award), isNull);
    });
  });

  test('GuideCoverage reads complete and partial', () {
    final c = GuideCoverage.fromJson({
      'guide_code': 'asia_50_best',
      'edition_year': 2026,
      'coverage': 'partial',
      'note': 'Three more are still being checked.',
    });
    expect(c.isComplete, isFalse);
    expect(c.note, 'Three more are still being checked.');
  });
}
