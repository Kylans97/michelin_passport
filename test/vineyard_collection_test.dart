// The Wine Estates collection, one section per list (product owner,
// 2026-11-25): the 50 Best in rank order, then each classification in class
// order. Estate names here are made up.
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/models/vineyard.dart';
import 'package:michelin_passport/models/vineyard_recognition.dart';

Vineyard _v(String id, String name, {int? rank}) => Vineyard(
  id: id,
  vineyardCode: 'vine_$id',
  name: name,
  countryCode: 'FR',
  worlds50BestYear: rank == null ? null : 2026,
  worlds50BestRank: rank,
);

VineyardRecognition _r(String id, String scheme, String label, int order) =>
    VineyardRecognition(
      vineyardId: id,
      scheme: scheme,
      classLabel: label,
      classOrder: order,
      edition: 1855,
    );

void main() {
  final ranked = [
    _v('a', 'Domaine Alpha', rank: 7),
    _v('b', 'Château Beta', rank: 2),
  ];
  final c = _v('c', 'Château Gamma');
  final d = _v('d', 'Château Delta');
  final byId = {
    for (final v in [...ranked, c, d]) v.id: v,
  };

  test('the 50 Best alone is one section, in rank order, with the edition', () {
    final sections = buildEstateCollection(
      ranked: ranked,
      recognitions: const [],
      byId: byId,
    );
    expect(sections, hasLength(1));
    expect(sections.single.title, "The World's 50 Best Vineyards 2026");
    expect(sections.single.entries.map((e) => e.marker), ['2', '7']);
  });

  test(
    'classifications follow in the fixed list order, by class then name',
    () {
      final sections = buildEstateCollection(
        ranked: ranked,
        recognitions: [
          _r('c', 'saint_emilion', 'Grand Cru Classé', 2),
          _r('d', 'bordeaux_1855_medoc', 'Troisième Cru', 3),
          _r('c', 'bordeaux_1855_medoc', 'Troisième Cru', 3),
          _r('b', 'bordeaux_1855_medoc', 'Premier Cru', 1),
        ],
        byId: byId,
      );
      expect(sections.map((s) => s.title), [
        "The World's 50 Best Vineyards 2026",
        'Bordeaux 1855, Médoc',
        'Saint-Émilion',
      ]);
      final medoc = sections[1].entries;
      expect(medoc.map((e) => e.vineyard.name), [
        'Château Beta',
        'Château Delta',
        'Château Gamma',
      ]);
      expect(medoc.first.note, 'Premier Cru');
      expect(medoc.first.marker, '');
    },
  );

  test('an estate the app could not load, or an unknown list, is left out', () {
    final sections = buildEstateCollection(
      ranked: const [],
      recognitions: [
        _r('zzz', 'graves_1959', 'Cru Classé de Graves', 1),
        _r('c', 'some_future_list', 'Class', 1),
      ],
      byId: byId,
    );
    expect(sections, isEmpty);
  });
}
