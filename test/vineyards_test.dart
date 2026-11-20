// Vineyards (20261101550000): the estate model, the producer suggestion,
// a wine's link to its estate, the Cellar's grouping, and the wine sheet's
// "pick an estate or keep it as written". Estate names here are made up.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/data/repositories/vineyard_repository.dart';
import 'package:michelin_passport/data/repositories/visit_wine_repository.dart';
import 'package:michelin_passport/features/passport/models/cellar.dart';
import 'package:michelin_passport/features/visits/widgets/visit_wines.dart';
import 'package:michelin_passport/models/vineyard.dart';
import 'package:michelin_passport/models/visit_wine.dart';

const _lavaux = Vineyard(
  id: 'v1',
  vineyardCode: 'vine_0001',
  name: 'Domaine Lavaux-Mercier',
  countryCode: 'FR',
  countryName: 'France',
  region: 'Burgundy',
  city: 'Gevrey-Chambertin',
  worlds50BestYear: 2025,
  worlds50BestRank: 3,
);
const _chateau = Vineyard(
  id: 'v2',
  vineyardCode: 'vine_0002',
  name: 'Château Exemple',
  countryCode: 'FR',
  countryName: 'France',
  region: 'Bordeaux',
  worlds50BestYear: 2025,
  worlds50BestRank: 1,
);
const _quinta = Vineyard(
  id: 'v3',
  vineyardCode: 'vine_0003',
  name: 'Quinta do Exemplo',
  countryCode: 'PT',
  countryName: 'Portugal',
);

CellarWine _cw(String id, {Vineyard? vineyard, String? producer}) => CellarWine(
  visitId: 'visit-$id',
  wine: VisitWine(
    id: id,
    producer: producer ?? vineyard?.name,
    vineyardId: vineyard?.id,
    vineyard: vineyard,
  ),
);

void main() {
  group('Vineyard', () {
    test('reads a vineyards_full row', () {
      final v = Vineyard.fromMap({
        'id': 'x',
        'vineyard_code': 'vine_0007',
        'name': 'Quinta do Exemplo',
        'country_code': 'PT',
        'country_name': 'Portugal',
        'region': 'Douro Valley',
        'city': 'Pinhão',
        'latitude': 41.19,
        'longitude': -7.54,
        'status': 'open',
        'worlds_50_best_year': 2025,
        'worlds_50_best_rank': 7,
      });
      expect(v.regionLine, 'Douro Valley, Portugal');
      expect(v.placeLine, 'Pinhão, Douro Valley');
      expect(v.rankLabel, "No. 7 · World's 50 Best Vineyards 2025");
      expect(v.latitude, 41.19);
    });

    test('an estate off the list has no rank, never a zero', () {
      expect(_quinta.worlds50BestRank, isNull);
      expect(_quinta.rankLabel, isNull);
      expect(_quinta.regionLine, 'Portugal');
    });

    test('the collection is in rank order, unranked after, by name', () {
      final sorted = sortVineyardsForCollection([_quinta, _lavaux, _chateau]);
      expect(sorted.map((v) => v.id), ['v2', 'v1', 'v3']);
    });
  });

  group('matchingVineyards', () {
    const all = [_lavaux, _chateau, _quinta];

    test('a single letter proposes nothing', () {
      expect(matchingVineyards(all, 'l'), isEmpty);
      expect(matchingVineyards(all, ''), isEmpty);
    });

    test('accents and case do not matter', () {
      expect(matchingVineyards(all, 'chateau').single.id, 'v2');
      expect(matchingVineyards(all, 'LAVAUX').single.id, 'v1');
    });

    test('a word start ranks before a match inside a word', () {
      final list = matchingVineyards(all, 'ex');
      expect(list.map((v) => v.id), ['v2', 'v3']);
      expect(matchingVineyards(all, 'mercier').single.id, 'v1');
    });
  });

  group('VisitWine and its estate', () {
    test('an unlinked wine never sends vineyard_id, so it saves on a '
        'database without the column', () {
      const w = VisitWine(producer: 'Lavaux');
      expect(w.toRow().containsKey('vineyard_id'), isFalse);
    });

    test('a linked wine sends its estate; a cleared link sends null', () {
      const linked = VisitWine(producer: 'X', vineyardId: 'v1');
      expect(linked.toRow()['vineyard_id'], 'v1');
      const cleared = VisitWine(producer: 'X');
      expect(
        cleared.toRow(withVineyard: true),
        containsPair('vineyard_id', null),
      );
    });

    test('reads the estate embed with its country', () {
      final w = VisitWine.fromJson({
        'id': 'w',
        'producer': 'Domaine Lavaux-Mercier',
        'non_vintage': false,
        'vineyard_id': 'v1',
        'vineyards': {
          'id': 'v1',
          'vineyard_code': 'vine_0001',
          'name': 'Domaine Lavaux-Mercier',
          'region': 'Burgundy',
          'city': 'Gevrey-Chambertin',
          'country_code': 'FR',
          'countries': {'name': 'France'},
        },
      });
      expect(w.vineyard?.countryName, 'France');
      expect(w.vineyard?.region, 'Burgundy');
    });

    test('a row from before the migration reads as unlinked', () {
      final w = VisitWine.fromJson({
        'id': 'w',
        'producer': 'Lavaux',
        'non_vintage': false,
      });
      expect(w.vineyardId, isNull);
      expect(w.vineyard, isNull);
    });
  });

  group('buildCellar', () {
    test('groups by region and estate, keeps unlinked wines apart', () {
      final cellar = buildCellar([
        _cw('1', vineyard: _lavaux),
        _cw('2', producer: 'Lavaux'), // typed, kept as written
        _cw('3', vineyard: _chateau),
        _cw('4', vineyard: _lavaux),
        _cw('5', vineyard: _quinta),
      ]);
      expect(cellar.wineCount, 5);
      expect(cellar.estateCount, 3);
      expect(cellar.regionCount, 3);
      expect(cellar.regions.first.label, 'Burgundy');
      expect(cellar.regions.first.estates.single.wines.map((w) => w.wine.id), [
        '1',
        '4',
      ]);
      // An estate with no region is grouped under its country.
      expect(cellar.regions.map((r) => r.label), contains('Portugal'));
      // The typed "Lavaux" is never matched to the estate by name.
      expect(cellar.unlinked.single.wine.producer, 'Lavaux');
    });

    test('nothing logged is an empty cellar', () {
      expect(buildCellar(const []).isEmpty, isTrue);
    });
  });

  group('WineSheet with estates', () {
    Future<List<VisitWine>> pumpSheet(
      WidgetTester tester, {
      VisitWine? initial,
    }) async {
      final saved = <VisitWine>[];
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WineSheet(
              initial: initial,
              vineyards: Future.value(const [_lavaux, _chateau, _quinta]),
              onSave: (w) async {
                saved.add(w);
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return saved;
    }

    Finder producerField() => find.byType(TextField).first;

    testWidgets('typing a producer proposes the estate and offers to keep '
        'it as written', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(producerField(), 'Lavaux');
      await tester.pump();
      expect(find.text('Domaine Lavaux-Mercier'), findsOneWidget);
      expect(find.text('Keep “Lavaux” as written'), findsOneWidget);
    });

    testWidgets('picking the estate links the wine', (tester) async {
      final saved = await pumpSheet(tester);
      await tester.enterText(producerField(), 'Lavaux');
      await tester.pump();
      await tester.tap(find.text('Domaine Lavaux-Mercier'));
      await tester.pump();
      expect(find.textContaining('Linked to the estate'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved.single.vineyardId, 'v1');
      expect(saved.single.producer, 'Domaine Lavaux-Mercier');
    });

    testWidgets('keeping it as written saves the text with no estate', (
      tester,
    ) async {
      final saved = await pumpSheet(tester);
      await tester.enterText(producerField(), 'Lavaux');
      await tester.pump();
      await tester.tap(find.text('Keep “Lavaux” as written'));
      await tester.pump();
      expect(find.text('Domaine Lavaux-Mercier'), findsNothing);
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved.single.producer, 'Lavaux');
      expect(saved.single.vineyardId, isNull);
    });

    testWidgets('editing the producer away from the estate unlinks it', (
      tester,
    ) async {
      final saved = await pumpSheet(tester);
      await tester.enterText(producerField(), 'Lavaux');
      await tester.pump();
      await tester.tap(find.text('Domaine Lavaux-Mercier'));
      await tester.pump();
      await tester.enterText(producerField(), 'Domaine Lavaux');
      await tester.pump();
      expect(find.textContaining('Linked to the estate'), findsNothing);
      await tester.tap(find.text('Keep “Domaine Lavaux” as written'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(saved.single.vineyardId, isNull);
    });

    testWidgets('an existing unlinked wine is not pressed into an estate', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        initial: const VisitWine(id: 'w', producer: 'Lavaux'),
      );
      expect(find.text('Domaine Lavaux-Mercier'), findsNothing);
    });
  });
}
