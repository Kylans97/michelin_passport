// The grapes of a region (20261101690000, product owner 2026-11-22): the
// region sheet lists names only, and the grape screen opened from a
// region leads with what the grape is there, in the region's own words.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:michelin_passport/features/map/wine/wine_region_sheet.dart';
import 'package:michelin_passport/models/wine_atlas.dart';

const _uco = WineRegion(
  id: 'r1',
  code: 'wr_0101',
  name: 'Valle de Uco',
  countryCode: 'AR',
  countryName: 'Argentina',
  latitude: -33.6,
  longitude: -69.2,
  summary: 'The high valley south of Mendoza city.',
);

const _cahors = WineRegion(
  id: 'r2',
  code: 'wr_0102',
  name: 'Cahors',
  countryCode: 'FR',
  countryName: 'France',
  latitude: 44.45,
  longitude: 1.44,
  summary: 'Dark reds on the Lot.',
);

const _malbec = Grape(
  id: 'g1',
  code: 'gr_0010',
  name: 'Malbec',
  aliases: ['Côt'],
  colour: GrapeColour.red,
  summary: 'Deep purple, plush, with soft tannins.',
  tastes: ['Plum', 'Blackberry', 'Violet'],
  similarGrapeId: 'g3',
);

const _chardonnay = Grape(
  id: 'g2',
  code: 'gr_0002',
  name: 'Chardonnay',
  colour: GrapeColour.white,
  summary: 'The chameleon.',
  tastes: ['Lemon'],
);

const _merlot = Grape(
  id: 'g3',
  code: 'gr_0003',
  name: 'Merlot',
  colour: GrapeColour.red,
  summary: 'Soft and round.',
  tastes: ['Plum'],
);

WineAtlas _atlas() => WineAtlas(
  regions: const [_uco, _cahors],
  grapes: const [_malbec, _chardonnay, _merlot],
  regionGrapes: const [
    RegionGrape(
      regionId: 'r1',
      grapeId: 'g1',
      localNote: 'fresher and more fragrant at altitude',
      tasteNote: 'Fresher and more fragrant at altitude.',
      order: 1,
    ),
    RegionGrape(regionId: 'r1', grapeId: 'g2', order: 2),
    RegionGrape(
      regionId: 'r2',
      grapeId: 'g1',
      localNote: 'Called Côt in the cahier; at least 70%.',
      localName: 'Côt',
      roleNote: "At least 70 percent of each estate's Cahors plantings.",
    ),
  ],
  appellations: const [],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2600);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  group('RegionGrape lead and detail', () {
    test('the taste there leads; name and role follow', () {
      const link = RegionGrape(
        regionId: 'r',
        grapeId: 'g',
        localName: 'Tinto Fino',
        roleNote: 'The main grape.',
        tasteNote: 'Fuller and darker.',
      );
      expect(link.lead, 'Fuller and darker.');
      expect(link.detail, 'Called Tinto Fino here. The main grape.');
    });

    test('without a taste, the name leads and the role follows', () {
      expect(_atlas().regionGrapes[2].lead, 'Called Côt here.');
      expect(
        _atlas().regionGrapes[2].detail,
        "At least 70 percent of each estate's Cahors plantings.",
      );
    });

    test('a role alone leads, with nothing after it', () {
      const link = RegionGrape(
        regionId: 'r',
        grapeId: 'g',
        roleNote: 'The main grape.',
      );
      expect(link.lead, 'The main grape.');
      expect(link.detail, isNull);
    });

    test('before the three fields are filled, the old note leads', () {
      const link = RegionGrape(
        regionId: 'r',
        grapeId: 'g',
        localNote: 'earthy, elegant',
      );
      expect(link.lead, 'earthy, elegant');
      expect(link.detail, isNull);
    });

    test('empty text reads as nothing', () {
      final link = RegionGrape.fromMap({
        'region_id': 'r',
        'grape_id': 'g',
        'local_note': ' ',
        'taste_note': '',
      });
      expect(link.lead, isNull);
    });
  });

  testWidgets('the region sheet lists grape names only', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: WineRegionDetail(atlas: _atlas(), region: _uco),
      ),
    );
    expect(find.text('Malbec'), findsOneWidget);
    expect(find.text('Chardonnay'), findsOneWidget);
    expect(find.textContaining('fragrant at altitude'), findsNothing);
    expect(find.textContaining('Plum'), findsNothing);

    await tester.tap(find.text('Malbec'));
    await tester.pumpAndSettle();
    expect(find.text('IN VALLE DE UCO'), findsOneWidget);
    expect(find.text('Fresher and more fragrant at altitude.'), findsOneWidget);
  });

  testWidgets('from a region with a name and a rule, both show', (
    tester,
  ) async {
    await _pump(
      tester,
      GrapeScreen(atlas: _atlas(), grape: _malbec, fromRegion: _cahors),
    );
    expect(find.text('IN CAHORS'), findsOneWidget);
    expect(find.text('Called Côt here.'), findsOneWidget);
    expect(
      find.text("At least 70 percent of each estate's Cahors plantings."),
      findsOneWidget,
    );
    expect(find.text('Where you came from'), findsOneWidget);
  });

  testWidgets('from a region that says nothing, one quiet line', (
    tester,
  ) async {
    await _pump(
      tester,
      GrapeScreen(atlas: _atlas(), grape: _chardonnay, fromRegion: _uco),
    );
    expect(find.text('Grown in Valle de Uco.'), findsOneWidget);
    expect(find.text('IN VALLE DE UCO'), findsNothing);
  });

  testWidgets('a grape the region does not list gets no region block', (
    tester,
  ) async {
    await _pump(
      tester,
      GrapeScreen(atlas: _atlas(), grape: _merlot, fromRegion: _uco),
    );
    expect(find.textContaining('Valle de Uco'), findsNothing);
  });

  testWidgets('opened without a region, the grape screen is as before', (
    tester,
  ) async {
    await _pump(tester, GrapeScreen(atlas: _atlas(), grape: _malbec));
    expect(find.textContaining('IN '), findsNothing);
    expect(find.text('Where you came from'), findsNothing);
    expect(find.text('Valle de Uco'), findsOneWidget);
    expect(find.text('Cahors'), findsOneWidget);
  });
}
