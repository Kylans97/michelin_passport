// The globe's wine layer (20261101580000): search over what a wine list
// says, and the region sheet built from the atlas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/map/wine/wine_region_sheet.dart';
import 'package:michelin_passport/models/wine_atlas.dart';

const _burgundy = WineRegion(
  id: 'r1',
  code: 'wr_0001',
  name: 'Burgundy',
  aliases: ['Bourgogne'],
  countryCode: 'FR',
  countryName: 'France',
  latitude: 47.05,
  longitude: 4.85,
  summary: 'Pinot Noir for red, Chardonnay for white.',
  redBody: 2,
  redAcidity: 4,
  redTannin: 2,
  pairing: 'Duck, mushrooms.',
);

const _ribera = WineRegion(
  id: 'r2',
  code: 'wr_0007',
  name: 'Ribera del Duero',
  aliases: ['Ribera'],
  countryCode: 'ES',
  latitude: 41.65,
  longitude: -3.8,
  summary: 'Full, dark reds.',
);

const _pinot = Grape(
  id: 'g1',
  code: 'gr_0001',
  name: 'Pinot Noir',
  aliases: ['Spätburgunder'],
  colour: GrapeColour.red,
  summary: 'Pale but scented.',
  tastes: ['Red cherry', 'Raspberry'],
);

const _chardonnay = Grape(
  id: 'g2',
  code: 'gr_0002',
  name: 'Chardonnay',
  colour: GrapeColour.white,
  summary: 'The chameleon.',
);

WineAtlas _atlas() => WineAtlas(
  regions: const [_burgundy, _ribera],
  grapes: const [_pinot, _chardonnay],
  regionGrapes: const [
    RegionGrape(
      regionId: 'r1',
      grapeId: 'g2',
      localNote: 'steely to rich',
      order: 2,
    ),
    RegionGrape(
      regionId: 'r1',
      grapeId: 'g1',
      localNote: 'earthy, elegant',
      order: 1,
    ),
  ],
  appellations: const [
    WineAppellation(
      id: 'a1',
      name: 'Meursault',
      regionId: 'r1',
      colour: 'white',
      note: 'rich, nutty',
    ),
    WineAppellation(
      id: 'a2',
      name: 'Gevrey-Chambertin',
      aliases: ['Gevrey Chambertin'],
      regionId: 'r1',
      colour: 'red',
      note: 'firmer, darker',
    ),
  ],
);

void main() {
  group('WineAtlas.search', () {
    test('a name from the wine list finds its region', () {
      final hits = _atlas().search('Meursault');
      expect(hits.single, isA<AppellationHit>());
      expect((hits.single as AppellationHit).region.name, 'Burgundy');
    });

    test('a word inside a name matches, accents folded', () {
      final hits = _atlas().search('chambertin');
      expect(
        (hits.single as AppellationHit).appellation.name,
        'Gevrey-Chambertin',
      );
    });

    test('an alias finds the region and the grape', () {
      expect(
        (_atlas().search('bourgogne').single as RegionHit).region.name,
        'Burgundy',
      );
      expect(
        (_atlas().search('spatburgunder').single as GrapeHit).grape.name,
        'Pinot Noir',
      );
    });

    test('regions come before list names and grapes for the same match', () {
      final hits = _atlas().search('ribera');
      expect(hits.first, isA<RegionHit>());
    });

    test('one letter finds nothing', () {
      expect(_atlas().search('b'), isEmpty);
    });
  });

  test('a region lists its grapes in order, with what they become there', () {
    final grapes = _atlas().grapesOf(_burgundy);
    expect(grapes.map((g) => g.$1.name), ['Pinot Noir', 'Chardonnay']);
    expect(grapes.first.$2, 'earthy, elegant');
  });

  test('only top-level regions are drawn on the globe', () {
    final atlas = WineAtlas(
      regions: const [
        _burgundy,
        WineRegion(
          id: 'r3',
          code: 'wr_0012',
          name: 'Côte de Nuits',
          countryCode: 'FR',
          parentId: 'r1',
          latitude: 47.2,
          longitude: 4.95,
          summary: 'The northern half.',
        ),
      ],
      grapes: const [],
      regionGrapes: const [],
      appellations: const [],
    );
    expect(atlas.globeRegions.map((r) => r.name), ['Burgundy']);
  });

  test('taste words read the 1–5 scale', () {
    expect(bodyWord(2), 'light');
    expect(acidityWord(4), 'fresh');
    expect(tanninWord(5), 'firm');
  });

  testWidgets('the region sheet shows grapes, the red profile, the list '
      'names and the member\'s wines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WineRegionDetail(
            atlas: _atlas(),
            region: _burgundy,
            myWineCount: 2,
          ),
        ),
      ),
    );
    expect(find.text('Burgundy'), findsOneWidget);
    expect(find.text('Pinot Noir'), findsOneWidget);
    expect(find.text('Chardonnay'), findsOneWidget);
    expect(find.text('light'), findsOneWidget);
    expect(find.text('fresh'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Meursault'), 200);
    expect(find.text('Meursault'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2 wines in your Cellar come from here'),
      200,
    );
    expect(find.text('2 wines in your Cellar come from here'), findsOneWidget);
  });
}
